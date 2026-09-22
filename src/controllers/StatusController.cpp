#include "StatusController.h"
#include "utils/ApiClient.h"
#include <QDateTime>

// [FIX api-contract 2026-09-22] uptime 秒数 → 人类可读文本(原来的 uptime 字段不存在恒空)
static QString formatUptime(qint64 secs) {
    if (secs < 0) secs = 0;
    const qint64 d = secs / 86400;
    const qint64 h = (secs % 86400) / 3600;
    const qint64 m = (secs % 3600) / 60;
    if (d > 0) return QString("%1天 %2小时").arg(d).arg(h);
    if (h > 0) return QString("%1小时 %2分").arg(h).arg(m);
    return QString("%1分").arg(m);
}

StatusController::StatusController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api), m_timer(new QTimer(this)) {
    connect(m_timer, &QTimer::timeout, this, &StatusController::refresh);
}

// [FIX api-contract 2026-09-22] refresh() 重写:
//   1) /api/v1/health 是裸对象({status,storage_gc,timestamp,uptime_seconds,version}),
//      无 cpu_usage/memory_usage/temperature 等字段 → 仅作连通性探测(不解析字段);
//   2) 系统指标 canonical = /api/v1/situation/system-health
//      (信封: cpu/memory/temperature/gpu/uptime(秒数));
//   3) TPU canonical = /api/v1/models/tpu-usage(信封, 需 unwrapData);
//   4) /stats/dashboard 无 gpu_usage 字段, 不再依赖。
// 旧实现三项全读错层或错字段 → 全部恒 0/空。
void StatusController::refresh() {
    // 连通性探测(裸对象, 不解析字段)
    m_api->get("/api/v1/health",
        [this](QJsonObject) {
            if (m_networkStatus != "Connected") {
                m_networkStatus = "Connected";
                emit statusUpdated();
            }
            m_systemTime = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
            emit statusUpdated();
        },
        [this](int, QString) {
            if (m_networkStatus != "Disconnected") {
                m_networkStatus = "Disconnected";
                emit systemAlert("Box SDK 连接断开");
                emit statusUpdated();
            }
        });

    // 主机系统指标(信封)
    m_api->get("/api/v1/situation/system-health",
        [this](QJsonObject resp) {
            const QJsonObject d = ApiClient::unwrapData(resp);
            m_cpuUsage = float(d.value("cpu").toDouble());
            m_memoryUsage = float(d.value("memory").toDouble());
            m_temperature = float(d.value("temperature").toDouble());
            m_gpuUsage = float(d.value("gpu").toDouble());
            m_uptime = formatUptime(d.value("uptime").toVariant().toLongLong());
            emit statusUpdated();
        },
        [](int, QString) {});

    // TPU 占用(信封)
    m_api->get("/api/v1/models/tpu-usage",
        [this](QJsonObject resp) {
            const QJsonObject d = ApiClient::unwrapData(resp);
            m_tpuUtilization = float(d["utilization"].toDouble());
            m_tpuMemoryUsed = d["memory_used"].toInt();
            m_activeModels = d["active_models"].toInt();
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
