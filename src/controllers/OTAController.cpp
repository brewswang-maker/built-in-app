#include "OTAController.h"
#include "utils/ApiClient.h"
#include <QTimer>

OTAController::OTAController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void OTAController::checkUpdate() {
    m_api->get("/api/v1/ota/check",
        [this](QJsonObject obj) {
            // [FIX m24-envelope 2026-09-22] 后端走标准信封 {code,data,message}, ApiClient 不解包,
            //   读取前必须 unwrapData (仓库惯例 Streaming/Rbac/Audit 等 controller);
            //   初版直读顶层导致版本字段恒空 (对照单测 test_ota_bootid 已固化契约)
            QJsonObject d = ApiClient::unwrapData(obj);
            m_currentVersion = d["current_version"].toString();
            m_latestVersion = d["latest_version"].toString();
            m_updateAvailable = d["update_available"].toBool();
            emit versionUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void OTAController::startUpgrade() {
    if (m_upgrading) return;
    m_upgrading = true;
    m_progress = 0;
    m_pollCount = 0;
    emit progressChanged();

    // [M2-4 2026-09-21] 升级前记录 bootId 基线 (完成判定的权威锚点:
    //   固件升级必然重启, 重启后 Linux boot_id 必变; 仅看进度/HTTP 200 = 假成功窗口)
    m_api->get("/api/v1/ota/status",
        [this](QJsonObject obj) {
            // [FIX m24-envelope 2026-09-22] boot_id 位于信封 data 内层, 需先解包
            m_preUpgradeBootId = ApiClient::unwrapData(obj)["boot_id"].toString();
            doUpgrade();
        },
        [this](int code, QString msg) {
            m_upgrading = false;
            emit progressChanged();
            emit upgradeCompleted(false);
            emit errorOccurred(code, msg);
        });
}

void OTAController::doUpgrade() {
    QJsonObject body;
    // 后端 /api/v1/ota/upgrade 要求 target_version 必填 (缺省 400)
    body["target_version"] = m_latestVersion.isEmpty() ? m_currentVersion : m_latestVersion;
    m_api->post("/api/v1/ota/upgrade", body,
        [this](QJsonObject obj) {
            m_progress = 5;  // Initial progress after triggering
            emit progressChanged();
            QTimer::singleShot(2000, this, &OTAController::pollProgress);
        },
        [this](int code, QString msg) {
            m_upgrading = false;
            emit progressChanged();
            emit upgradeCompleted(false);
            emit errorOccurred(code, msg);
        });
}

void OTAController::pollProgress() {
    if (!m_upgrading) return;

    // [M2-4 2026-09-21] 轮询 /ota/status (含 boot_id): 完成判定 = bootId 变化,
    //   不再单看进度值 — bootId 变化本身即最强信号 (设备已重启 = 升级生效)
    m_api->get("/api/v1/ota/status",
        [this](QJsonObject obj) {
            // [FIX m24-envelope 2026-09-22] 同上: 进度/状态/boot_id 均在信封 data 内层;
            //   未解包时 bootChanged 恒 false → 真实升级也误判假成功 (对照单测已覆盖)
            QJsonObject d = ApiClient::unwrapData(obj);
            double pct = d["progress_pct"].toDouble();
            QString status = d["status"].toString();
            QString bootId = d["boot_id"].toString();
            m_progress = pct;
            if (m_progress < 5) m_progress = 5;
            emit progressChanged();

            m_pollCount++;
            const bool bootChanged = !bootId.isEmpty() && !m_preUpgradeBootId.isEmpty() &&
                                     bootId != m_preUpgradeBootId;
            const bool reportedDone = (status == "completed" || status == "success" ||
                                       status == "failed");
            if (bootChanged || reportedDone || m_pollCount > 300) {
                m_upgrading = false;
                if (status == "failed") {
                    emit progressChanged();
                    emit upgradeCompleted(false);
                    emit errorOccurred(0, QStringLiteral("升级失败 (设备端报告 failed)"));
                    return;
                }
                m_progress = 100;
                m_currentVersion = d["current_version"].toString();
                if (m_currentVersion.isEmpty()) m_currentVersion = m_latestVersion;
                m_updateAvailable = false;
                emit versionUpdated();
                emit progressChanged();
                // [M2-4] 完成判定: bootId 变化才算真完成; 未变 = 假成功拦截
                emit upgradeCompleted(bootChanged);
                if (!bootChanged) {
                    emit errorOccurred(0, QStringLiteral(
                        "升级命令已完成但设备未重启 (bootId 未变化), 升级可能未生效"));
                }
            } else {
                QTimer::singleShot(2000, this, &OTAController::pollProgress);
            }
        },
        [this](int code, QString msg) {
            // [M2-4] 设备重启期间 HTTP 中断属预期: 未达轮询上限时继续等待,
            //   重启回来后 bootId 变化即判成功 (不得因此误报失败)
            m_pollCount++;
            if (m_pollCount <= 300) {
                QTimer::singleShot(2000, this, &OTAController::pollProgress);
                return;
            }
            m_upgrading = false;
            emit progressChanged();
            emit upgradeCompleted(false);
            emit errorOccurred(code, msg);
        });
}

void OTAController::refreshHistory() {
    m_api->getList("/api/v1/ota/history",
        [this](QJsonArray arr) {
            m_history.clear();
            for (const auto& item : arr)
                m_history.append(item.toVariant().toMap());
            emit historyUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void OTAController::rollback(const QString& partition) {
    QJsonObject body;
    body["partition"] = partition;
    m_api->post("/api/v1/ota/rollback", body,
        [this](QJsonObject) {
            checkUpdate();
            refreshHistory();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
