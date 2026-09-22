// tests/test_ota_bootid.cpp
//
// OTA bootId 完成判定单测 — [M2-4 2026-09-22] 内置端升级完成校验
//   (计划条款: "web-admin 升级页与 built-in-app 设置页以 bootId 变化判定升级完成
//    (不得只看 HTTP 200)"; 验收: bootId 变化可观测 + 假成功场景被拦截提示)
//
// 背景 (2026-09-22 实测坐实): 后端 /api/v1/ota/status 与 /api/v1/ota/check 均走
//   标准信封 {code, message, data:{...}, timestamp} (设备真机抓取); ApiClient::get
//   不解包, 读取方须自行 ApiClient::unwrapData (仓库惯例: Streaming/Rbac/Audit 等
//   controller)。OTAController 初版直读顶层 obj["boot_id"] → 恒空 → bootChanged
//   恒 false → 真实升级也会被误判"假成功"。本测试用信封仿真 HTTP stub 固化该契约。
//
// 覆盖矩阵 (3 用例):
//   ① checkUpdate 信封解包      → current_version/latest_version/update_available 正确
//   ② 重启期 HTTP 中断 + bootId 变化 → upgradeCompleted(true), 无假成功告警
//     (对应代码注释: 设备重启期间 HTTP 中断属预期, 不得因此误报失败)
//   ③ bootId 未变 + status=completed → upgradeCompleted(false) + "bootId 未变化" 提示
//     (假成功拦截: 不得只看 HTTP 200 / 进度完成)
//
// 验收标准:
//   ctest -R test_ota_bootid -V → PASSED
//   ./test_ota_bootid           → exit 0

#include "controllers/OTAController.h"
#include "utils/ApiClient.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QtTest>

namespace {

/// 标准信封 {code:0, message:"success", data:{...}, timestamp} (与 makeOkResponse 同构)
QByteArray envelope(const QJsonObject& data) {
    QJsonObject o;
    o["code"] = 0;
    o["data"] = data;
    o["message"] = "success";
    o["timestamp"] = double(QDateTime::currentMSecsSinceEpoch());
    return QJsonDocument(o).toJson(QJsonDocument::Compact);
}

/// /api/v1/ota/status 的 data 载荷 (与 RestApiHandlers.cpp L11209 handler 同构)
QJsonObject statusData(const QString& bootId, const QString& status,
                       double progressPct = 0.0) {
    QJsonObject d;
    d["boot_id"] = bootId;
    d["current_version"] = "6.1.0";
    d["latest_version"] = "6.1.0";
    d["update_available"] = false;
    d["status"] = status;
    d["progress_pct"] = progressPct;
    return d;
}

/// 最小 HTTP/1.1 stub 服务: responder 返回空 QByteArray 时直接断链 (= 模拟重启期不可达)
class StubHttpServer : public QTcpServer {
public:
    std::function<QByteArray(const QString& method, const QString& path)> responder;

protected:
    void incomingConnection(qintptr socketDescriptor) override {
        auto* sock = new QTcpSocket(this);
        sock->setSocketDescriptor(socketDescriptor);
        auto* buf = new QByteArray;
        connect(sock, &QTcpSocket::readyRead, sock, [this, sock, buf]() {
            buf->append(sock->readAll());
            const int headEnd = buf->indexOf("\r\n\r\n");
            if (headEnd < 0) return;  // 头部未收全
            const QStringList first = QString::fromUtf8(buf->left(headEnd))
                                          .split("\r\n")
                                          .value(0)
                                          .split(' ');
            const QByteArray body = responder ? responder(first.value(0), first.value(1))
                                              : QByteArray();
            if (body.isEmpty()) {  // 空响应 → 直接断开 (QNetworkReply 得 RemoteHostClosedError)
                sock->disconnectFromHost();
                return;
            }
            QByteArray resp = "HTTP/1.1 200 OK\r\n"
                              "Content-Type: application/json\r\n"
                              "Content-Length: " + QByteArray::number(body.size()) + "\r\n"
                              "Connection: close\r\n\r\n" + body;
            sock->write(resp);
            sock->flush();
            sock->disconnectFromHost();
        });
        connect(sock, &QTcpSocket::disconnected, sock, &QObject::deleteLater);
    }
};

}  // namespace

class TestOtaBootid : public QObject {
    Q_OBJECT

private:
    StubHttpServer m_server;

    /// 起 stub 并返回 baseUrl (127.0.0.1:ephemeral)
    QString startServer(std::function<QByteArray(const QString&, const QString&)> responder) {
        m_server.responder = std::move(responder);
        const bool ok = m_server.listen(QHostAddress::LocalHost, 0);
        if (!ok) return {};
        return QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort());
    }

private slots:
    void cleanup() { m_server.close(); }

    // ① checkUpdate 信封解包: data.current_version / latest_version / update_available
    void checkUpdateUnwrapsEnvelope() {
        QJsonObject d;
        d["current_version"] = "6.1.0";
        d["latest_version"] = "6.2.0";
        d["update_available"] = true;
        const QString base = startServer([d](const QString&, const QString& path) {
            if (path.startsWith("/api/v1/ota/check")) return envelope(d);
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());

        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        OTAController ctrl(&api);
        ctrl.checkUpdate();

        QTRY_COMPARE_WITH_TIMEOUT(ctrl.currentVersion(), QString("6.1.0"), 5000);
        QCOMPARE(ctrl.latestVersion(), QString("6.2.0"));
        QCOMPARE(ctrl.updateAvailable(), true);
    }

    // ② 重启期 HTTP 中断 tolerated + bootId 变化 → 判成功 (不得误报失败)
    void rebootInterruptionThenBootIdChangeSucceeds() {
        int statusGets = 0;
        const QString base = startServer([&statusGets](const QString&, const QString& path) {
            if (path.startsWith("/api/v1/ota/upgrade")) return envelope({});
            if (path.startsWith("/api/v1/ota/status")) {
                statusGets++;
                if (statusGets == 1) return envelope(statusData("boot-A", "idle"));    // 升级前基线
                if (statusGets == 2) return QByteArray();                             // 重启中: 断链
                return envelope(statusData("boot-B", "idle", 100));                   // 重启后归来
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());
        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        OTAController ctrl(&api);
        QSignalSpy doneSpy(&ctrl, &OTAController::upgradeCompleted);
        QSignalSpy errSpy(&ctrl, &OTAController::errorOccurred);

        ctrl.startUpgrade();
        QTRY_VERIFY_WITH_TIMEOUT(doneSpy.count() >= 1, 20000);

        QCOMPARE(doneSpy.takeFirst().at(0).toBool(), true);   // bootId 已变化 → 成功
        QCOMPARE(errSpy.count(), 0);                          // 重启期断链不得报错
        QCOMPARE(ctrl.upgrading(), false);
        QCOMPARE(ctrl.upgradeProgress(), 100.0);
        QVERIFY(statusGets >= 3);
    }

    // ③ 假成功拦截: status 报 completed 但 bootId 未变 → upgradeCompleted(false) + 提示
    void unchangedBootIdBlocksFakeSuccess() {
        int statusGets = 0;
        const QString base = startServer([&statusGets](const QString&, const QString& path) {
            if (path.startsWith("/api/v1/ota/upgrade")) return envelope({});
            if (path.startsWith("/api/v1/ota/status")) {
                statusGets++;
                if (statusGets == 1) return envelope(statusData("boot-A", "idle"));
                // 升级命令"完成", 但设备未重启 (bootId 未变) → 假成功
                return envelope(statusData("boot-A", "completed", 100));
            }
            return QByteArray();
        });
        QVERIFY(!base.isEmpty());

        ApiClient api;
        api.setBaseUrl(base);
        api.setTimeoutMs(3000);
        OTAController ctrl(&api);
        QSignalSpy doneSpy(&ctrl, &OTAController::upgradeCompleted);
        QSignalSpy errSpy(&ctrl, &OTAController::errorOccurred);

        ctrl.startUpgrade();
        QTRY_VERIFY_WITH_TIMEOUT(doneSpy.count() >= 1, 20000);

        QCOMPARE(doneSpy.takeFirst().at(0).toBool(), false);  // 未重启 → 不判成功
        QTRY_VERIFY_WITH_TIMEOUT(errSpy.count() >= 1, 5000);
        const QString msg = errSpy.takeFirst().at(1).toString();
        QVERIFY2(msg.contains(QStringLiteral("bootId 未变化")),
                 qPrintable(QStringLiteral("拦截提示缺失: %1").arg(msg)));
    }
};

QTEST_MAIN(TestOtaBootid)
#include "test_ota_bootid.moc"
