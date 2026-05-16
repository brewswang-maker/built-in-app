#include "StatusController.h"
#include "utils/ApiClient.h"

StatusController::StatusController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api), m_timer(new QTimer(this)) {
    connect(m_timer, &QTimer::timeout, this, &StatusController::refresh);
}

void StatusController::refresh() {
    // Fetch health + dashboard stats
    m_api->get("/api/v1/health",
        [this](QJsonObject resp) {
            m_cpuUsage = resp["cpu_usage"].toDouble();
            m_memoryUsage = resp["memory_usage"].toDouble();
            m_temperature = resp["temperature"].toDouble();
            m_uptime = resp["uptime"].toString();
            m_systemTime = resp["system_time"].toString();
            emit statusUpdated();
        },
        [this](int, QString) {
            if (m_networkStatus != "Disconnected") {
                m_networkStatus = "Disconnected";
                emit systemAlert("Box SDK 连接断开");
                emit statusUpdated();
            }
        });

    m_api->get("/api/v1/stats/dashboard",
        [this](QJsonObject resp) {
            m_gpuUsage = resp["gpu_usage"].toDouble();
            emit statusUpdated();
        },
        [](int, QString) {});

    m_api->get("/api/v1/models/tpu-usage",
        [this](QJsonObject resp) {
            m_tpuUtilization = resp["utilization"].toDouble();
            m_tpuMemoryUsed = resp["memory_used"].toInt();
            m_activeModels = resp["active_models"].toInt();
            emit statusUpdated();
        },
        [](int, QString) {});
}

void StatusController::startPolling(int intervalMs) {
    m_timer->start(intervalMs);
    refresh();
}

void StatusController::stopPolling() {
    m_timer->stop();
}
