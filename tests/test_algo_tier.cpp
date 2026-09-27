// tests/test_algo_tier.cpp
//
// [M3-2 内置端对齐 2026-09-27] 算法档位 (tier) 回归单测
//
// 背景: web/后端 tier 全链路已就绪 (PUT /api/v1/algo/:algo/tier 泛化路由,
//   预设 SSOT=算法 YAML tier_presets 节; GET :id/param-meta 下发
//   tier={current,presets}), 内置端 AlgorithmController 零档位能力 →
//   本批补齐: refreshAlgoTiers (param-meta 拉取/无档位过滤/presets 展示序
//   重排/会话缓存) + setAlgoTier (PUT 整组覆盖/本地回写 current)。
//
// 覆盖 (3 用例):
//   ① 拉取解析: 有档位事件出卡 (字段/algoKey 尾段/presets 展示序
//      high→balanced→low 重排) + 无档位事件 (无 tier 节点) 不出卡 +
//      三端点路径契约
//   ② 生成风格键集判定 (strict/standard/creative → isStyle=true, 展示序
//      重排) + 二次刷新走会话缓存不重复请求
//   ③ 切换: PUT 路径/方法/body {tier} 契约 + tierApplied 信号 +
//      current 本地回写; 非法 algoKey/空 tier 应用侧拒绝 (不发请求)
//
// 验收: ctest -R test_algo_tier -V → PASSED

#include "TestHttpStub.h"

#include "controllers/AlgorithmController.h"
#include "utils/ApiClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QtTest>

using teststub::envelopeData;

namespace {

/// param-meta 响应 data (与后端 /algorithms/:id/param-meta 同构;
/// presetsNorm: 键→预设对象, 原样透传)
QJsonObject paramMetaData(const QString& algoId, const QString& algoName,
                          const QJsonObject& presets, const QString& current) {
    QJsonObject tier;
    tier["current"] = current;
    tier["presets"] = presets;
    QJsonObject data;
    data["algo_id"] = algoId;
    if (!algoName.isEmpty()) data["algo_name"] = algoName;
    data["params"] = QJsonArray{QJsonObject{{"key", "min_fall_frames"}}};
    data["tier"] = tier;
    return data;
}

/// 灵敏度三档 presets (逆序插入 low/balanced/high — 验证展示序重排非碰巧)
QJsonObject sensitivityPresets() {
    QJsonObject p;
    p["low"] = QJsonObject{{"min_fall_frames", 8}};
    p["balanced"] = QJsonObject{{"min_fall_frames", 5}};
    p["high"] = QJsonObject{{"min_fall_frames", 3}};
    return p;
}

/// 生成风格三档 presets (逆序插入 creative/standard/strict)
QJsonObject stylePresets() {
    QJsonObject p;
    p["creative"] = QJsonObject{{"box_threshold", 0.15}};
    p["standard"] = QJsonObject{{"box_threshold", 0.25}};
    p["strict"] = QJsonObject{{"box_threshold", 0.35}};
    return p;
}

QStringList keysOf(const QVariantList& presets) {
    QStringList out;
    for (const auto& v : presets) out << v.toString();
    return out;
}

}  // namespace

class TestAlgoTier : public QObject {
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

    // ① 拉取解析: 有档位出卡 + 无档位过滤 + presets 展示序重排 + 路径契约
    void refreshAlgoTiersParsesAndOrders() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/algorithms/fall_detected/param-meta"))
                return envelopeData(paramMetaData("shield.algo.behavior.fall", "跌倒检测",
                                                  sensitivityPresets(), "balanced"));
            if (p.startsWith("/api/v1/algorithms/tripwire/param-meta"))
                return envelopeData(paramMetaData("shield.algo.perimeter.tripwire", "",
                                                  sensitivityPresets(), "high"));
            if (p.startsWith("/api/v1/algorithms/channel_offline/param-meta")) {
                // 无 tier 节点 (无档位设计算法) → 不出卡
                QJsonObject data;
                data["algo_id"] = "shield.algo.device.channeloffline";
                data["params"] = QJsonArray{};
                return envelopeData(data);
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlgorithmController ctrl(&api);

        QSignalSpy updSpy(&ctrl, &AlgorithmController::algoTiersUpdated);
        ctrl.refreshAlgoTiers(QVariantList{"fall_detected", "tripwire", "channel_offline"});
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);

        // 契约: 三个事件各请求一次 param-meta (无档位事件也探测)
        QCOMPARE(m_srv.requestCount("/api/v1/algorithms/fall_detected/param-meta"), 1);
        QCOMPARE(m_srv.requestCount("/api/v1/algorithms/tripwire/param-meta"), 1);
        QCOMPARE(m_srv.requestCount("/api/v1/algorithms/channel_offline/param-meta"), 1);

        // 仅 2 项出卡 (channel_offline 无档位被过滤), 保输入序
        const QVariantList tiers = ctrl.algoTiers();
        QCOMPARE(tiers.size(), 2);
        const QVariantMap t0 = tiers[0].toMap();
        QCOMPARE(t0.value("eventType").toString(), QString("fall_detected"));
        QCOMPARE(t0.value("algoId").toString(), QString("shield.algo.behavior.fall"));
        QCOMPARE(t0.value("algoKey").toString(), QString("fall"));  // 尾段=PUT 节名
        QCOMPARE(t0.value("name").toString(), QString("跌倒检测"));
        QCOMPARE(t0.value("isStyle").toBool(), false);
        QCOMPARE(t0.value("current").toString(), QString("balanced"));
        // 展示序重排: 逆序插入 low/balanced/high → 输出 high/balanced/low
        QCOMPARE(keysOf(t0.value("presets").toList()),
                 QStringList({"high", "balanced", "low"}));

        const QVariantMap t1 = tiers[1].toMap();
        QCOMPARE(t1.value("eventType").toString(), QString("tripwire"));
        QCOMPARE(t1.value("algoKey").toString(), QString("tripwire"));
        QCOMPARE(t1.value("name").toString(), QString(""));  // 无 algo_name → QML 兜底
        QCOMPARE(t1.value("current").toString(), QString("high"));
    }

    // ② 生成风格键集判定 + 会话缓存 (二次刷新零请求)
    void styleDetectionAndSessionCache() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/algorithms/object_detected/param-meta"))
                return envelopeData(paramMetaData("shield.algo.vocabulary.groundingdino",
                                                  "开放词汇检测", stylePresets(), "standard"));
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlgorithmController ctrl(&api);

        QSignalSpy updSpy(&ctrl, &AlgorithmController::algoTiersUpdated);
        ctrl.refreshAlgoTiers(QVariantList{"object_detected"});
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);

        const QVariantMap t = ctrl.algoTiers().value(0).toMap();
        QCOMPARE(t.value("isStyle").toBool(), true);  // 键集 ⊆ strict/standard/creative
        QCOMPARE(t.value("algoKey").toString(), QString("groundingdino"));
        QCOMPARE(keysOf(t.value("presets").toList()),
                 QStringList({"strict", "standard", "creative"}));  // 重排
        QCOMPARE(t.value("current").toString(), QString("standard"));

        // 二次刷新: 会话缓存命中 → 不发新请求, 但信号照发 (列表可重建)
        ctrl.refreshAlgoTiers(QVariantList{"object_detected"});
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 2, 5000);
        QCOMPARE(m_srv.requestCount("/api/v1/algorithms/object_detected/param-meta"), 1);
        QCOMPARE(ctrl.algoTiers().size(), 1);
    }

    // ③ 切换: PUT 契约 + tierApplied + current 回写; 非法输入应用侧拒绝
    void setAlgoTierPutsAndApplies() {
        const QString base = startServer([](const QString& m, const QString& p,
                                            const QByteArray& body) -> QByteArray {
            if (p.startsWith("/api/v1/algorithms/fall_detected/param-meta"))
                return envelopeData(paramMetaData("shield.algo.behavior.fall", "跌倒检测",
                                                  sensitivityPresets(), "balanced"));
            if (m == "PUT" && p == "/api/v1/algo/fall/tier" && body.contains("\"low\"")) {
                QJsonObject data;
                data["algo"] = "fall";
                data["algo_id"] = "shield.algo.behavior.fall";
                data["tier"] = "low";
                data["restart_required"] = true;
                return envelopeData(data);
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlgorithmController ctrl(&api);

        QSignalSpy updSpy(&ctrl, &AlgorithmController::algoTiersUpdated);
        QSignalSpy appliedSpy(&ctrl, &AlgorithmController::tierApplied);
        QSignalSpy errSpy(&ctrl, &AlgorithmController::errorOccurred);
        ctrl.refreshAlgoTiers(QVariantList{"fall_detected"});
        QTRY_VERIFY_WITH_TIMEOUT(updSpy.count() >= 1, 5000);

        ctrl.setAlgoTier("fall_detected", "fall", "low");
        QTRY_VERIFY_WITH_TIMEOUT(appliedSpy.count() >= 1, 5000);
        // 信号载荷 (UI 提示用)
        const QList<QVariant> sig = appliedSpy.takeFirst();
        QCOMPARE(sig.at(0).toString(), QString("fall_detected"));
        QCOMPARE(sig.at(1).toString(), QString("low"));
        // 请求契约: PUT /api/v1/algo/fall/tier, body {tier:"low"}
        int putCount = 0;
        for (const auto& r : m_srv.requests) {
            if (r.method != "PUT") continue;
            ++putCount;
            QCOMPARE(r.path, QString("/api/v1/algo/fall/tier"));
            const QJsonObject b = QJsonDocument::fromJson(r.body).object();
            QCOMPARE(b.value("tier").toString(), QString("low"));
        }
        QCOMPARE(putCount, 1);
        // current 本地回写
        QCOMPARE(ctrl.algoTiers().value(0).toMap().value("current").toString(), QString("low"));

        // 非法 algoKey (大写/特殊字符) → 应用侧拒绝, 不发请求
        const int reqBefore = m_srv.requests.size();
        ctrl.setAlgoTier("fall_detected", "BAD!", "low");
        ctrl.setAlgoTier("fall_detected", "fall", "");
        QTRY_VERIFY_WITH_TIMEOUT(errSpy.count() >= 2, 5000);
        QCOMPARE(m_srv.requests.size(), reqBefore);
    }
};

QTEST_MAIN(TestAlgoTier)
#include "test_algo_tier.moc"
