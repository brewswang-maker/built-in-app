// tests/test_api_contract_fixes.cpp
//
// [api-contract 2026-09-22] built-in-app ↔ box-sdk REST 契约回归单测
//
// 背景: 对照 web-admin(baseURL=/api/v1 + 各 api 模块 canonical 用法)与 box-sdk
//   RestApiHandlers.cpp 路由表, 横扫 built-in-app controllers 发现三类系统缺陷:
//     A) 路由/方法错误: face 前缀缺失 / audit export GET→POST / alarms confirm|false
//        无 :id 路由 / handle POST→PUT / zlm streams DELETE→streams/:id/stop
//     B) 信封未解包: 响应 data 被直读顶层 → 字段恒空
//     C) 请求体字段不符: POST /devices 缺 device_id(必填) → 400
//   全部修复见各 controller 内 [FIX api-contract 2026-09-22] 注释。
//
// 本测试用请求记录 stub 把修复后的契约固化: 断言"实际发出的 method/path/body"
//   与"响应解析落点"(信封解包/字段映射) —— 修复前这些断言应全部 FAIL(可作对照)。
//
// 覆盖 (12 用例):
//   ① FaceController 全路径带 /api/v1 前缀 + 信封解包
//   ② AuditController export = POST + body{format} + 读 data.url
//   ③ AlarmController confirm/false = 批量端点 + body{alarm_id}; handle = PUT
//   ④ MediaController stopStream = POST /streams/:id/stop
//   ⑤ MediaController snapshotToFile = 信封解包取 url 并触发下载
//   ⑥ StatusController = /health 探测 + situation/system-health 指标 + tpu 信封
//   ⑦ ConfigController network = 信封 + ipAddress→ip 字段映射
//   ⑧ ConfigController saveConfig 分流: 设备键→PUT settings/basic, 本地键→QSettings
//   ⑨ AlgorithmController TPU = 信封解包
//   ⑩ LinkageController ruleStats = data 数组取首元素
//   ⑪ DeviceController addDevice = device_id=ip:554 + device_name 透传
//   ⑫ Federation/Pipeline/AI 三处信封解包 (nodeDetail/pipelineDetail/multimodal)
//
// 验收: ctest -R test_api_contract_fixes -V → PASSED

#include "TestHttpStub.h"

#include "controllers/AIController.h"
#include "controllers/AlarmController.h"
#include "controllers/AlgorithmController.h"
#include "controllers/AuditController.h"
#include "controllers/ConfigController.h"
#include "controllers/DeviceController.h"
#include "controllers/FederationController.h"
#include "controllers/FaceController.h"
#include "controllers/LinkageController.h"
#include "controllers/MediaController.h"
#include "controllers/PipelineController.h"
#include "controllers/StatusController.h"
#include "utils/ApiClient.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QtTest>

using teststub::envelope;
using teststub::envelopeData;

class TestApiContractFixes : public QObject {
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

    /// 等待请求记录中出现满足条件的请求 (stub 异步收包)
    bool waitForRequest(std::function<bool(const teststub::StubRequest&)> pred,
                        int timeoutMs = 5000) {
        return QTest::qWaitFor([this, &pred]() {
            for (const auto& r : m_srv.requests)
                if (pred(r)) return true;
            return false;
        }, timeoutMs);
    }

private slots:
    void cleanup() { m_srv.close(); }

    // ① FaceController: 路径必须带 /api/v1 前缀(修复前 /face/database/* → 404)
    void facePathsCarryApiV1Prefix() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/face/database/stats")
                return envelope(QJsonObject{{"total", 5}, {"blacklist", 2},
                                            {"whitelist", 2}, {"visitor", 1}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        FaceController fc(&api);
        QSignalSpy spy(&fc, &FaceController::statsUpdated);

        fc.refreshStats();
        QTRY_VERIFY_WITH_TIMEOUT(spy.count() >= 1, 5000);
        QCOMPARE(fc.totalCount(), 5);
        QCOMPARE(fc.blacklistCount(), 2);
        // 契约断言: 落点路径 + 旧缺前缀路径零命中
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.path == "/api/v1/face/database/stats";
        }));
        QCOMPARE(m_srv.requestCount("/face/database"), 0);
    }

    // ② AuditController: export = POST body{format} → 读信封 data.url(修复前 GET ?format + 读 path 字段)
    void auditExportUsesPostBodyFormatAndReadsUrl() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/audit/export")
                return envelope(QJsonObject{{"url", "http://stub/export.csv"},
                                            {"format", "csv"}, {"count", 3}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AuditController ac(&api);
        QSignalSpy done(&ac, &AuditController::exportCompleted);

        ac.exportLogs("csv");
        QTRY_VERIFY_WITH_TIMEOUT(done.count() >= 1, 5000);
        QCOMPARE(done.takeFirst().at(0).toString(), QString("http://stub/export.csv"));
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "POST" && r.path == "/api/v1/audit/export" &&
                   r.body.contains("\"format\"");
        }));
    }

    // ③ AlarmController: 三条处理路由 (confirm/false 批量端点 + handle PUT)
    void alarmHandleRoutesMatchBackend() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p.startsWith("/api/v1/alarms/confirm")) return envelope(QJsonObject{});
            if (p.startsWith("/api/v1/alarms/false")) return envelope(QJsonObject{});
            if (p.startsWith("/api/v1/alarms/") && p.endsWith("/handle"))
                return envelope(QJsonObject{});
            if (p.startsWith("/api/v1/alarms"))  // refreshAlarms(50) 列表
                return envelopeData(QJsonArray{});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlarmController ctrl(&api);

        ctrl.confirmAlarm("A1");
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "POST" && r.path == "/api/v1/alarms/confirm" &&
                   r.body.contains("A1");
        }));
        ctrl.markFalseAlarm("A1");
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "POST" && r.path == "/api/v1/alarms/false" &&
                   r.body.contains("A1");
        }));
        ctrl.handleAlarm("A1", "ignored");
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "PUT" && r.path == "/api/v1/alarms/A1/handle";
        }));
        // 修复前的错误路由零命中
        QCOMPARE(m_srv.requestCount("/api/v1/alarms/A1/confirm"), 0);
        QCOMPARE(m_srv.requestCount("/api/v1/alarms/A1/false"), 0);
    }

    // ④ MediaController: stopStream = POST /streams/:id/stop(修复前 DELETE /zlm/streams/:id)
    void mediaStopStreamPostsCanonicalStop() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/streams/gb_1/stop") return envelope(QJsonObject{});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        MediaController mc(&api);
        QSignalSpy stopped(&mc, &MediaController::streamStopped);

        mc.stopStream("gb_1");
        QTRY_VERIFY_WITH_TIMEOUT(stopped.count() >= 1, 5000);
        QCOMPARE(stopped.takeFirst().at(0).toString(), QString("gb_1"));
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "POST" && r.path == "/api/v1/streams/gb_1/stop";
        }));
        QCOMPARE(m_srv.requestCount("/api/v1/zlm/streams/gb_1"), 0);
    }

    // ⑤ MediaController: snapshotToFile 读信封 data.url 并触发下载(修复前读裸顶层 → url 空)
    void mediaSnapshotUnwrapsUrlAndDownloads() {
        // 先起 stub, 再拼 url (端口运行期确定)
        const QString base = startServer([this](const QString&, const QString& p,
                                                const QByteArray&) -> QByteArray {
            if (p == "/api/v1/channels/ch1/snapshot") {
                return envelope(QJsonObject{
                    {"url", QString("http://127.0.0.1:%1/raw.jpg").arg(m_srv.serverPort())}});
            }
            if (p == "/raw.jpg")
                return QByteArray("\xFF\xD8\xFF\xD9", 4);  // 最小 JPEG 头尾 (raw 分支)
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        MediaController mc(&api);
        QSignalSpy saved(&mc, &MediaController::snapshotSaved);
        QSignalSpy failed(&mc, &MediaController::snapshotFailed);

        mc.snapshotToFile("ch1");
        QTRY_VERIFY_WITH_TIMEOUT(saved.count() >= 1, 8000);
        QCOMPARE(failed.count(), 0);  // 修复前 url 空 → "empty snapshot response"
        const QString path = saved.takeFirst().at(1).toString();
        QVERIFY(QFile::remove(path));  // 清理落盘文件
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.path == "/raw.jpg";
        }));
    }

    // ⑥ StatusController: /health 裸对象仅探测 + situation/system-health 指标 + tpu 信封
    void statusRefreshMapsSystemHealthAndTpu() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/health")  // 裸对象(非信封)
                return QByteArray("{\"status\":\"healthy\",\"uptime_seconds\":100,"
                                  "\"version\":\"6.2.0\"}");
            if (p == "/api/v1/situation/system-health")
                return envelope(QJsonObject{{"cpu", 36.5}, {"memory", 72.2},
                                            {"temperature", 46.7}, {"gpu", 1.0},
                                            {"uptime", 72678}});
            if (p == "/api/v1/models/tpu-usage")
                return envelope(QJsonObject{{"utilization", 12.5},
                                            {"memory_used", 256},
                                            {"active_models", 3}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        StatusController sc(&api);

        sc.refresh();
        QTRY_COMPARE_WITH_TIMEOUT(sc.cpuUsage(), 36.5f, 5000);
        QCOMPARE(sc.memoryUsage(), 72.2f);
        QCOMPARE(sc.temperature(), 46.7f);
        QCOMPARE(sc.gpuUsage(), 1.0f);
        QCOMPARE(sc.tpuUtilization(), 12.5f);
        QCOMPARE(sc.activeModels(), 3);
        QCOMPARE(sc.tpuMemoryUsed(), 256);
        QCOMPARE(sc.networkStatus(), QString("Connected"));
        QVERIFY(!sc.uptime().isEmpty());      // 72678s → "20小时 11分"
        QVERIFY(!sc.systemTime().isEmpty());  // 本地时钟(yyyy-MM-dd HH:mm:ss)
    }

    // ⑦ ConfigController: 网络配置 = 信封 + ipAddress/netmask/dns1 → ip/subnet/dns 映射
    void configNetworkUnwrapsAndMapsKeys() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/config/network")
                return envelope(QJsonObject{{"ipAddress", "192.168.1.10"},
                                            {"netmask", "255.255.255.0"},
                                            {"gateway", "192.168.1.1"},
                                            {"dns1", "8.8.8.8"},
                                            {"dns2", "8.8.4.4"},
                                            {"hostname", "box"},
                                            {"method", "static"}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        ConfigController cc(&api);
        QSignalSpy spy(&cc, &ConfigController::networkConfigUpdated);

        cc.getNetworkConfig();
        QTRY_VERIFY_WITH_TIMEOUT(spy.count() >= 1, 5000);
        const QVariantMap net = cc.networkConfig();
        QCOMPARE(net.value("ip").toString(), QString("192.168.1.10"));
        QCOMPARE(net.value("subnet").toString(), QString("255.255.255.0"));
        QCOMPARE(net.value("dns").toString(), QString("8.8.8.8"));
        QCOMPARE(net.value("gateway").toString(), QString("192.168.1.1"));
    }

    // ⑧ ConfigController.saveConfig 分流: 设备键 → PUT settings/basic; 本地键 → QSettings 零请求
    void configSaveConfigSplitsBackendAndLocal() {
        const QString base = startServer([](const QString& m, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/settings/basic" && m == "PUT")
                return envelope(QJsonObject{});
            if (p == "/api/v1/settings/basic")
                return envelope(QJsonObject{{"deviceName", "Gate-A"}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        ConfigController cc(&api);
        QSignalSpy saved(&cc, &ConfigController::configSaved);

        // 设备级键 → 后端 partial PUT (body 键名即字段名)
        cc.saveConfig("deviceName", "Gate-A");
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "PUT" && r.path == "/api/v1/settings/basic" &&
                   r.body.contains("deviceName");
        }));
        QTRY_VERIFY_WITH_TIMEOUT(saved.count() >= 1, 5000);  // 响应回包后才 emit
        // 等待 loadConfig 回读完成(避免其异步 GET 落入下一段请求计数)
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "GET" && r.path == "/api/v1/settings/basic";
        }));

        // 本地键 → 不产生任何 HTTP 请求
        m_srv.clearRequests();
        cc.saveConfig("screenBrightness", 42);
        QTRY_VERIFY_WITH_TIMEOUT(saved.count() >= 2, 3000);
        QCOMPARE(m_srv.requests.size(), 0);
        QCOMPARE(cc.config().value("screenBrightness").toInt(), 42);
    }

    // ⑨ AlgorithmController: TPU 占用 = 信封解包(修复前读裸顶层 → 恒 0)
    void algorithmTpuUsageUnwrapsEnvelope() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/models/tpu-usage")
                return envelope(QJsonObject{{"utilization", 12.5},
                                            {"memory_used", 256},
                                            {"active_models", 3}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        AlgorithmController ac(&api);
        QSignalSpy spy(&ac, &AlgorithmController::tpuUsageUpdated);

        ac.refreshTpuUsage();
        QTRY_COMPARE_WITH_TIMEOUT(ac.tpuUsage(), 12.5f, 5000);
        QCOMPARE(ac.activeModels(), 3);
        QCOMPARE(ac.tpuMemoryUsed(), 256);
    }

    // ⑩ LinkageController: ruleStats 信封 data 为数组 → 取首元素(修复前 toVariantMap 读顶层 → 全空)
    void linkageRuleStatsReadsArrayData() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/linkage/stats")
                return envelopeData(QJsonArray{
                    QJsonObject{{"activeRules", 4}, {"successRate", 0.98},
                                {"totalTriggers", 120}}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        LinkageController lc(&api);
        QSignalSpy spy(&lc, &LinkageController::statsReceived);

        lc.getRuleStats();
        QTRY_VERIFY_WITH_TIMEOUT(spy.count() >= 1, 5000);
        const QVariantMap stats = spy.takeFirst().at(0).toMap();
        QCOMPARE(stats.value("activeRules").toInt(), 4);
        QCOMPARE(stats.value("totalTriggers").toInt(), 120);
    }

    // ⑪ DeviceController: addDevice = device_id(ip:554) + device_name/type/config 透传
    void deviceAddDeviceComposesCanonicalId() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/devices") return envelope(QJsonObject{});
            if (p.startsWith("/api/v1/devices?"))  // refreshDevices
                return envelope(QJsonObject{{"devices", QJsonArray{}}, {"total", 0}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        DeviceController dc(&api);
        QSignalSpy added(&dc, &DeviceController::deviceAdded);

        dc.addDevice("GB28181", "192.168.1.50", "大门入口", "IPCamera", "南门");
        QVERIFY(waitForRequest([](const teststub::StubRequest& r) {
            return r.method == "POST" && r.path == "/api/v1/devices" &&
                   r.body.contains("192.168.1.50:554") &&
                   r.body.contains("device_name") && r.body.contains("IPCamera");
        }));
        QTRY_VERIFY_WITH_TIMEOUT(added.count() >= 1, 5000);
        QCOMPARE(added.takeFirst().at(0).toString(), QString("192.168.1.50:554"));
    }

    // ⑫ Federation/Pipeline/AI: 三处信封解包修复点
    void miscUnwrapFixes() {
        const QString base = startServer([](const QString&, const QString& p,
                                            const QByteArray&) -> QByteArray {
            if (p == "/api/v1/federation/nodes/n1")
                return envelope(QJsonObject{{"node_id", "n1"}, {"status", "online"}});
            if (p == "/api/v1/pipelines/p1")
                return envelope(QJsonObject{{"pipeline_id", "p1"}, {"running", true}});
            if (p == "/api/v1/ai/chat/multimodal")
                return envelope(QJsonObject{{"sessionId", "s1"},
                                            {"message", QJsonObject{{"content", "hello-from-ai"}}}});
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);

        FederationController fed(&api);
        QSignalSpy nodeSpy(&fed, &FederationController::nodeDetailReceived);
        fed.getNodeDetail("n1");
        QTRY_VERIFY_WITH_TIMEOUT(nodeSpy.count() >= 1, 5000);
        QCOMPARE(nodeSpy.takeFirst().at(0).toMap().value("status").toString(),
                 QString("online"));

        PipelineController pc(&api);
        QSignalSpy pipeSpy(&pc, &PipelineController::pipelineDetailReceived);
        pc.getPipelineDetail("p1");
        QTRY_VERIFY_WITH_TIMEOUT(pipeSpy.count() >= 1, 5000);
        QCOMPARE(pipeSpy.takeFirst().at(0).toMap().value("running").toBool(), true);

        AIController ai(&api);
        QSignalSpy tokSpy(&ai, &AIController::tokenReceived);
        ai.sendMultimodal("hi", "");
        QTRY_VERIFY_WITH_TIMEOUT(tokSpy.count() >= 1, 5000);
        QCOMPARE(ai.currentResponse(), QString("hello-from-ai"));
        QCOMPARE(ai.currentSessionId(), QString("s1"));
    }
};

QTEST_MAIN(TestApiContractFixes)
#include "test_api_contract_fixes.moc"
