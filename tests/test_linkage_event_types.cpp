// tests/test_linkage_event_types.cpp
//
// [P0-EVTTYPE 内置端对齐 2026-09-27] 联动规则事件类型 SSOT 回归单测
//
// 背景: 内置端事件类型原为 8 项中文硬编码直存 event_types, 后端
//   normalizeEventTypes 映射表全英文 → 中文值 kept-as-is → 规则 canonical
//   匹配永不命中 (①内置端建的规则永不触发 ②web 建规则内置端回显全空)。
//   修复: LinkageController::refreshEventTypes 从 GET /api/v1/event-types/metadata
//   (web useLinkageOptions 首选端点) 拉取, key=canonical; QML 复选区/保存/
//   回显/条件树/模板全链 canonical 化, 中文存量值经 eventTypeKeyOf 反查。
//
// 覆盖 (3 用例):
//   ① 拉取解析: 平铺 [key/name/level] + ui_group 分组 (中文 label/固定组序/
//      组内 severity 降序) + EXCLUDED_CATEGORIES (tracking/attribute/
//      image_enhance/enhance) 过滤; 事件类型 SSOT 端点路径契约锚定
//   ② 映射: eventTypeName (canonical→中文/未知回退裸 key) +
//      eventTypeKeyOf (canonical 直通/中文名反查/别名反查/未知空串 —
//      P0 修复的关键回归点)
//   ③ 防御: 空 metadata 不覆盖旧快照 (复选区不空白) + errorOccurred 上报
//
// 验收: ctest -R test_linkage_event_types -V → PASSED

#include "TestHttpStub.h"

#include "controllers/LinkageController.h"
#include "utils/ApiClient.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QSignalSpy>
#include <QStringList>
#include <QtTest>

#include <memory>

using teststub::envelopeData;

namespace {

/// metadata item (与后端 /event-types/metadata 字段同构)
QJsonObject metaItem(const QString& key, const QString& name, const QString& uiGroup,
                     int level, const QJsonArray& aliases = QJsonArray()) {
    QJsonObject m;
    m["alarm_type"] = key;
    m["display_name"] = name;
    m["ui_group"] = uiGroup;
    m["category"] = "ALARM";
    m["category_cn"] = "报警事件";
    m["severity"] = "HIGH";
    m["severity_level"] = level;
    m["severity_cn"] = "高";
    m["default_alarm_enabled"] = true;
    m["aliases"] = aliases;
    return m;
}

QJsonObject metaGroup(const QString& label, const QJsonArray& items) {
    QJsonObject g;
    g["label"] = label;
    g["items"] = items;
    return g;
}

/// 标准 metadata 响应 data 节: perimeter(rank1, 组内原序刻意逆 severity 降序)
///   / behavior(rank2) / tracking(EXCLUDED 排除)
QJsonObject metadataData() {
    QJsonObject groups;
    groups["ALARM"] = metaGroup("报警事件", QJsonArray{
        metaItem("tripwire", "绊线", "perimeter", 3),
        metaItem("intrusion", "周界入侵", "perimeter", 4,
                 QJsonArray{QStringLiteral("perimeter_intrusion")}),
        metaItem("loitering", "人员徘徊", "behavior", 3),
    });
    groups["PERCEPTION"] = metaGroup("感知事件", QJsonArray{
        metaItem("person_tracking", "人员追踪", "tracking", 1),  // EXCLUDED 类
    });
    QJsonObject data;
    data["groups"] = groups;
    data["total"] = 4;
    data["ssot"] = "EventTypeAliases.h";
    return data;
}

}  // namespace

class TestLinkageEventTypes : public QObject {
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

private slots:
    void cleanup() { m_srv.close(); }

    // ① 拉取解析: 平铺/分组/组序/组内降序/排除类过滤 + 路径契约
    void metadataFetchParsesFlatGroupsAndExclusions() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/event-types/metadata"))
                return envelopeData(metadataData());
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        LinkageController ctrl(&api);

        QSignalSpy updSpy(&ctrl, &LinkageController::eventTypesUpdated);
        ctrl.refreshEventTypes();
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);

        // 契约: 事件类型 SSOT 端点被真正访问
        QCOMPARE(m_srv.requestCount("/api/v1/event-types/metadata"), 1);

        // 平铺: 4 项中 tracking 组 1 项被排除 → 3 项
        const QVariantList flat = ctrl.eventTypes();
        QCOMPARE(flat.size(), 3);
        QStringList keys;
        for (const auto& v : flat) keys << v.toMap().value("key").toString();
        QVERIFY(keys.contains("intrusion"));
        QVERIFY(keys.contains("tripwire"));
        QVERIFY(keys.contains("loitering"));
        QVERIFY(!keys.contains("person_tracking"));  // EXCLUDED_CATEGORIES 过滤
        // item 字段: key=canonical / name=中文 / category=ui_group / level
        for (const auto& v : flat) {
            const QVariantMap e = v.toMap();
            if (e.value("key").toString() != "intrusion") continue;
            QCOMPARE(e.value("name").toString(), QString("周界入侵"));
            QCOMPARE(e.value("category").toString(), QString("perimeter"));
            QCOMPARE(e.value("level").toInt(), 4);
        }

        // 分组: 2 组 (perimeter/behavior), label 中文, 组序按 GROUP_ORDER rank
        const QVariantList gs = ctrl.eventTypeGroups();
        QCOMPARE(gs.size(), 2);
        QCOMPARE(gs[0].toMap().value("label").toString(), QString("周界安全"));
        QCOMPARE(gs[1].toMap().value("label").toString(), QString("行为分析"));
        // 组内 severity 降序: 原序 tripwire(3) 在前 → 排序后 intrusion(4) 先
        const QVariantList g0 = gs[0].toMap().value("items").toList();
        QCOMPARE(g0.size(), 2);
        QCOMPARE(g0[0].toMap().value("key").toString(), QString("intrusion"));
        QCOMPARE(g0[1].toMap().value("key").toString(), QString("tripwire"));
    }

    // ② 映射: name/keyOf 四态 (P0 关键回归 — 中文名反查)
    void nameAndKeyOfMapping() {
        const QString base = startServer([](const QString&, const QString&,
                                            const QByteArray&) -> QByteArray {
            return envelopeData(metadataData());
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        LinkageController ctrl(&api);
        QSignalSpy updSpy(&ctrl, &LinkageController::eventTypesUpdated);
        ctrl.refreshEventTypes();
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);

        // eventTypeName: canonical → 中文; 未知 → 回退裸 key
        QCOMPARE(ctrl.eventTypeName("intrusion"), QString("周界入侵"));
        QCOMPARE(ctrl.eventTypeName("unknown_xxx"), QString("unknown_xxx"));

        // eventTypeKeyOf: canonical 直通 / 中文名反查 / 别名反查 / 未知空串
        QCOMPARE(ctrl.eventTypeKeyOf("intrusion"), QString("intrusion"));
        QCOMPARE(ctrl.eventTypeKeyOf("周界入侵"), QString("intrusion"));
        QCOMPARE(ctrl.eventTypeKeyOf("perimeter_intrusion"), QString("intrusion"));
        QCOMPARE(ctrl.eventTypeKeyOf("不存在的类型"), QString(""));
        QCOMPARE(ctrl.eventTypeKeyOf(""), QString(""));
    }

    // ③ 防御: 空 metadata 不覆盖旧快照 (复选区不空白) + errorOccurred 上报
    void emptyMetadataKeepsLastSnapshot() {
        auto callCount = std::make_shared<int>(0);
        const QString base = startServer([callCount](const QString&, const QString& p,
                                                     const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/event-types/metadata")) {
                if ((*callCount)++ == 0) return envelopeData(metadataData());
                QJsonObject emptyData;
                emptyData["groups"] = QJsonObject();  // 异常空响应
                return envelopeData(emptyData);
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        LinkageController ctrl(&api);
        QSignalSpy updSpy(&ctrl, &LinkageController::eventTypesUpdated);
        QSignalSpy errSpy(&ctrl, &LinkageController::errorOccurred);

        // 首次成功: 快照 3 项
        ctrl.refreshEventTypes();
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);
        QCOMPARE(ctrl.eventTypes().size(), 3);

        // 二次空响应: 不二次发更新信号, 旧快照保留, 错误上报
        ctrl.refreshEventTypes();
        QTRY_VERIFY_WITH_TIMEOUT(errSpy.count() >= 1, 5000);
        QCOMPARE(updSpy.count(), 1);
        QCOMPARE(ctrl.eventTypes().size(), 3);
        QCOMPARE(ctrl.eventTypeGroups().size(), 2);
    }
};

QTEST_MAIN(TestLinkageEventTypes)
#include "test_linkage_event_types.moc"
