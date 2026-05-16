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
    emit progressChanged();

    m_api->post("/api/v1/ota/upgrade", QJsonObject(),
        [this](QJsonObject obj) {
            // Start polling progress
            m_progress = 0.1;
            emit progressChanged();
            // Poll every 2 seconds
            QTimer::singleShot(2000, this, [this]() {
                m_api->get("/api/v1/ota/progress",
                    [this](QJsonObject obj) {
                        m_progress = obj["progress"].toDouble();
                        emit progressChanged();
                        if (m_progress >= 1.0) {
                            m_upgrading = false;
                            m_currentVersion = m_latestVersion;
                            m_updateAvailable = false;
                            emit versionUpdated();
                            emit progressChanged();
                            emit upgradeCompleted(true);
                        } else if (m_upgrading) {
                            QTimer::singleShot(2000, this, [this]() { startUpgrade(); });
                        }
                    },
                    [this](int code, QString msg) {
                        m_upgrading = false;
                        emit progressChanged();
                        emit upgradeCompleted(false);
                        emit errorOccurred(code, msg);
                    });
            });
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
