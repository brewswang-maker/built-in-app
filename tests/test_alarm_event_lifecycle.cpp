// tests/test_alarm_event_lifecycle.cpp
//
// [P0-4/P0-1 内置端对齐 2026-09-27] 告警事件生命周期回归单测
//
// 背景: web 端 09-14 起消费后端 P0-4 事件生命周期 (WS end 帧 event_ended,
//   stores/alarm.ts pushRealtimeAlarm 分支) 与 09-26 P0-1 自动解除链;
//   built-in-app 此前完全未处理 — end 帧 (alarm_id='event_end_<track>_<ts>'
//   新 id) 会被当普通告警入队/弹窗 (列表条目被替换 + 幽灵弹窗)。
//
// 覆盖 (4 用例):
//   ① REST 行归一: track_id/event_start_ms/last_seen_ms/event_end_ms →
//      camel + eventEnded 双源 (event_end_ms>0), AlarmListModel role 可读
//   ② WS end 帧: 按 ch+track+type 匹配已有未结束行更新结束态
//      (eventEndMs / status=resolved), 不新增条目、不弹 newAlarm
//   ③ end 帧未命中: 静默丢弃 (条目数不变、无 alarmsUpdated)
//   ④ 已结束行不被二次改写; 人工终态 (confirmed) 不被 resolved 覆盖
//
// 验收: ctest -R test_alarm_event_lifecycle -V → PASSED

#include "TestHttpStub.h"

#include "controllers/AlarmController.h"
#include "models/AlarmListModel.h"
#include "utils/ApiClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QtTest>

using teststub::envelopeData;

class TestAlarmEventLifecycle : public QObject {
    Q_OBJECT

private:
    StubHttpServer m_srv;

    QString startServer(std::function<QByteArray(const QString&, const QString&,
                                                 const QByteArray&)> responder) {
        m_srv.responder = std::move(responder);
        m_srv.clearRequests();
        if (!m_srv.listen(QHostAddress::LocalHost, 0)) return {};
        return QStringLiteral("http://127.0.0.1:%1").arg(m_srv.serverPort());
    }

    /// 未结束行 A1 (track 42 / cam7 / intrusion, status=unhandled)
    static QJsonObject openRow() {
        QJsonObject row;
        row["alarm_id"] = "A1";
        row["alarm_type"] = "intrusion";
        row["channel_id"] = 7;
        row["channel_id_str"] = "cam7";
        row["track_id"] = 42;
        row["status"] = "unhandled";
        row["event_start_ms"] = 1700000000000.0;
        row["last_seen_ms"] = 1700000095000.0;
        row["event_end_ms"] = 0;
        return row;
    }

    /// 注入 WS end 帧 (对齐后端 event_end_<track>_<ts> 形态)
    static bool injectEndFrame(AlarmController& ctrl, const QString& chStr,
                               int track, const QString& type,
                               double endMs, const QString& status) {
        QJsonObject f;
        f["alarm_id"] = QStringLiteral("event_end_%1_%2").arg(track).arg(qint64(endMs));
        f["alarm_type"] = type;
        f["channel_id_str"] = chStr;
        f["track_id"] = track;
        f["status"] = status;
        f["event_ended"] = true;
        f["event_start_ms"] = 1700000000000.0;
        f["last_seen_ms"] = 1700000095000.0;
        f["event_end_ms"] = endMs;
        return QMetaObject::invokeMethod(
            &ctrl, "onWsTextMessage",
            Q_ARG(QString, QString::fromUtf8(QJsonDocument(f).toJson(QJsonDocument::Compact))));
    }

private slots:
    void cleanup() { m_srv.close(); }

    // ① REST 行归一: 事件生命周期字段 camel 化 + eventEnded 双源
    void restRowsNormalizeEventLifecycleFields() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/alarms")) {
                QJsonObject closed;
                closed["alarm_id"] = "A2";
                closed["alarm_type"] = "loitering";
                closed["channel_id_str"] = "cam8";
                closed["status"] = "resolved";  // 后端收尾后 REST 态
                closed["event_end_ms"] = 1700000200000.0;  // 双源: >0 即已结束
                return envelopeData(QJsonArray{openRow(), closed});
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlarmController ctrl(&api);
        AlarmListModel model;
        ctrl.setAlarmModel(&model);

        ctrl.refreshAlarms(50);
        QTRY_VERIFY_WITH_TIMEOUT(model.rowCount() == 2, 5000);

        // 未结束行: track/start/last_seen 可读, eventEnded=false
        QCOMPARE(model.data(model.index(0), AlarmListModel::TrackIdRole).toLongLong(), 42LL);
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndedRole).toBool(), false);
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndMsRole).toLongLong(), 0LL);
        QCOMPARE(model.data(model.index(0), AlarmListModel::StatusRole).toString(),
                 QString("unhandled"));
        // 已结束行: track 缺省归 -1; eventEnded 双源 (event_end_ms>0) 为 true
        QCOMPARE(model.data(model.index(1), AlarmListModel::TrackIdRole).toLongLong(), -1LL);
        QCOMPARE(model.data(model.index(1), AlarmListModel::EventEndedRole).toBool(), true);
        QCOMPARE(model.data(model.index(1), AlarmListModel::EventEndMsRole).toLongLong(),
                 1700000200000LL);
        QCOMPARE(model.data(model.index(1), AlarmListModel::StatusRole).toString(),
                 QString("resolved"));
    }

    // ② WS end 帧: 匹配行更新结束态 + resolved 翻转, 不新增条目/不弹窗
    void wsEndFrameUpdatesMatchedRowWithoutPopup() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/alarms"))
                return envelopeData(QJsonArray{openRow()});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlarmController ctrl(&api);
        AlarmListModel model;
        ctrl.setAlarmModel(&model);

        ctrl.refreshAlarms(50);
        QTRY_VERIFY_WITH_TIMEOUT(model.rowCount() == 1, 5000);

        QSignalSpy updatedSpy(&ctrl, &AlarmController::alarmsUpdated);
        QSignalSpy popupSpy(&ctrl, &AlarmController::newAlarm);
        QVERIFY(injectEndFrame(ctrl, "cam7", 42, "intrusion", 1700000100000.0, "resolved"));
        QTRY_VERIFY_WITH_TIMEOUT(updatedSpy.count() >= 1, 3000);

        // 不新增条目 (end 帧不得按新告警入队)
        QCOMPARE(model.rowCount(), 1);
        // 已有行更新: 结束态 + 结束时间 + 自动解除态 (unhandled → resolved)
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndedRole).toBool(), true);
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndMsRole).toLongLong(),
                 1700000100000LL);
        QCOMPARE(model.data(model.index(0), AlarmListModel::StatusRole).toString(),
                 QString("resolved"));
        // 无幽灵弹窗
        QCOMPARE(popupSpy.count(), 0);
    }

    // ③ end 帧未命中 (ch/track/type 均不匹配): 静默丢弃
    void wsEndFrameNoMatchSilentlyDropped() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/alarms"))
                return envelopeData(QJsonArray{openRow()});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlarmController ctrl(&api);
        AlarmListModel model;
        ctrl.setAlarmModel(&model);

        ctrl.refreshAlarms(50);
        QTRY_VERIFY_WITH_TIMEOUT(model.rowCount() == 1, 5000);

        QSignalSpy updatedSpy(&ctrl, &AlarmController::alarmsUpdated);
        QSignalSpy popupSpy(&ctrl, &AlarmController::newAlarm);
        QVERIFY(injectEndFrame(ctrl, "cam-other", 99, "loitering", 1700000100000.0,
                               "resolved"));
        QTest::qWait(200);

        // 条目数不变、行不改写、无刷新信号、无弹窗 (与 web 未命中静默丢弃同语义)
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndedRole).toBool(), false);
        QCOMPARE(updatedSpy.count(), 0);
        QCOMPARE(popupSpy.count(), 0);
    }

    // ④ 已结束行不被二次改写; 人工终态 (confirmed) 不被 resolved 覆盖
    void wsEndFrameRespectsTerminalStatusAndIdempotency() {
        QJsonObject confirmedRow = openRow();
        confirmedRow["status"] = "confirmed";  // 人工确认过的终态
        const QString base = startServer([confirmedRow](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/alarms"))
                return envelopeData(QJsonArray{confirmedRow});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlarmController ctrl(&api);
        AlarmListModel model;
        ctrl.setAlarmModel(&model);

        ctrl.refreshAlarms(50);
        QTRY_VERIFY_WITH_TIMEOUT(model.rowCount() == 1, 5000);

        // 首次 end 帧: eventEnded 置位, 但 confirmed 终态不被 resolved 覆盖
        QVERIFY(injectEndFrame(ctrl, "cam7", 42, "intrusion", 1700000100000.0, "resolved"));
        QTRY_COMPARE(model.data(model.index(0), AlarmListModel::EventEndedRole).toBool(), true);
        QCOMPARE(model.data(model.index(0), AlarmListModel::StatusRole).toString(),
                 QString("confirmed"));

        // 二次 end 帧 (更大 end_ms): 已结束行不改写 (幂等)
        QVERIFY(injectEndFrame(ctrl, "cam7", 42, "intrusion", 1700000300000.0, "resolved"));
        QTest::qWait(200);
        QCOMPARE(model.data(model.index(0), AlarmListModel::EventEndMsRole).toLongLong(),
                 1700000100000LL);
    }
};

QTEST_MAIN(TestAlarmEventLifecycle)
#include "test_alarm_event_lifecycle.moc"
