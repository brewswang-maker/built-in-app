#include "OTAController.h"
#include "utils/ApiClient.h"
#include <QTimer>

OTAController::OTAController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void OTAController::checkUpdate() {
    m_api->get("/api/v1/ota/check",
        [this](QJsonObject obj) {
            m_currentVersion = obj["current_version"].toString();
            m_latestVersion = obj["latest_version"].toString();
            m_updateAvailable = obj["update_available"].toBool();
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

    m_api->post("/api/v1/ota/upgrade", QJsonObject(),
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

    m_api->get("/api/v1/ota/progress",
        [this](QJsonObject obj) {
            // Backend returns 0.0-1.0, scale to 0-100
            double raw = obj["progress"].toDouble();
            m_progress = raw * 100.0;
            if (m_progress < 5) m_progress = 5;
            emit progressChanged();

            m_pollCount++;
            if (raw >= 1.0 || m_pollCount > 300) {
                // Upgrade complete or safety timeout (10 min)
                m_upgrading = false;
                if (raw >= 1.0) {
                    m_currentVersion = m_latestVersion;
                    m_updateAvailable = false;
                    m_progress = 100;
                    emit versionUpdated();
                }
                emit progressChanged();
                emit upgradeCompleted(raw >= 1.0);
            } else {
                // Continue polling
                QTimer::singleShot(2000, this, &OTAController::pollProgress);
            }
        },
        [this](int code, QString msg) {
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
