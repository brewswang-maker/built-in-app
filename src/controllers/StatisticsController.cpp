#include "StatisticsController.h"
#include "utils/ApiClient.h"
#include "utils/WsMessageRouter.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <cmath>
#include <algorithm>

StatisticsController::StatisticsController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
    // 订阅统一 WS 路由(规范 b4ced019)
    m_wsRouter = WsMessageRouter::instance();
    if (m_wsRouter) {
        QObject::connect(m_wsRouter, &WsMessageRouter::systemMetricsReceived,
                         this, &StatisticsController::onSystemMetricsReceived);
        QObject::connect(m_wsRouter, &WsMessageRouter::aiInferenceReceived,
                         this, &StatisticsController::onAiInferenceReceived);
    }
}

void StatisticsController::onSystemMetricsReceived(const QJsonObject& payload) {
    // 规范 b4ced019 payload: {cpu_usage, mem_usage, tpu_usage, temperature, ...}
    QVariantMap metrics = payload.toVariantMap();
    // 合并到 dashboard 顶部(不覆盖 REST 拉取的全量字段)
    for (auto it = metrics.constBegin(); it != metrics.constEnd(); ++it) {
        m_dashboard[it.key()] = it.value();
    }
    // 关键 KPI 单字段同步
    if (payload.contains("security_score")) {
        m_dashboard["security_score"] = payload.value("security_score").toInt();
    }
    emit dashboardUpdated();
    emit liveMetricsUpdated(metrics);
}

void StatisticsController::onAiInferenceReceived(const QJsonObject& payload) {
    // 把实时 AI 推理结果作为"近期事件"插入 recentEvents(规范 82ec775a: 不准 Stub,必须有真实下游消费)
    QVariantMap evt;
    evt["type"]      = "ai_inference";
    qint64 tsMs = payload.contains("timestamp")
                      ? payload.value("timestamp").toVariant().toLongLong()
                      : QDateTime::currentMSecsSinceEpoch();
    evt["timestamp"] = tsMs;
    evt["algorithm"] = payload.value("algorithm").toString();
    evt["device_id"] = payload.value("device_id").toString();
    evt["confidence"] = payload.value("confidence").toDouble();
    evt["label"]     = payload.value("label").toString();
    evt["severity"]  = payload.value("severity").toString();
    // 推入头部(限制 50 条,避免无限增长)
    m_recentEvents.prepend(evt);
    while (m_recentEvents.size() > 50) m_recentEvents.removeLast();
    emit recentEventsUpdated();

    // ── v7.0 P1 #10: 记录样本 + 推算 TPS/延迟分位 ──
    // latency_ms 字段兼容: latency / latency_ms / inference_time_ms
    double latencyMs = payload.value("latency_ms").toDouble();
    if (latencyMs <= 0) latencyMs = payload.value("latency").toDouble();
    if (latencyMs <= 0) latencyMs = payload.value("inference_time_ms").toDouble();
    recordInferenceSample(tsMs, latencyMs);
}

// =====================================================================
// v7.0 P1 #10: AI 推理指标实现
// =====================================================================

void StatisticsController::recordInferenceSample(qint64 tsMs, double latencyMs) {
    m_aiSamples.append(qMakePair(tsMs, latencyMs));
    m_aiTotalInferences++;
    // 限制容量,避免无限增长
    while (m_aiSamples.size() > kAiSampleCap) m_aiSamples.removeFirst();
    // 每次到达都重算(简单,样本量 < 1000 完全够用)
    recomputeAiMetrics();
}

double StatisticsController::percentile(QList<double>& sorted, double pct) {
    if (sorted.isEmpty()) return 0.0;
    std::sort(sorted.begin(), sorted.end());
    int n = sorted.size();
    if (n == 1) return sorted[0];
    double rank = (pct / 100.0) * (n - 1);
    int lo = (int)std::floor(rank);
    int hi = (int)std::ceil(rank);
    if (lo < 0) lo = 0;
    if (hi >= n) hi = n - 1;
    if (lo == hi) return sorted[lo];
    double frac = rank - lo;
    return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
}

void StatisticsController::recomputeAiMetrics() {
    qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    qint64 cutoff = nowMs - kAiWindowMs;
    // 1. 丢弃超出 60s 窗口的样本
    while (!m_aiSamples.isEmpty() && m_aiSamples.first().first < cutoff) {
        m_aiSamples.removeFirst();
    }
    // 2. 算 TPS = 窗口内样本数 / 60s
    int winCount = m_aiSamples.size();
    m_aiTps = (double)winCount / ((double)kAiWindowMs / 1000.0);
    // 3. 算 P50/P95/P99/Avg
    if (winCount == 0) {
        m_aiLatencyP50 = 0; m_aiLatencyP95 = 0; m_aiLatencyP99 = 0; m_aiLatencyAvg = 0;
    } else {
        QList<double> vals; vals.reserve(winCount);
        double sum = 0;
        for (const auto& s : m_aiSamples) { vals.append(s.second); sum += s.second; }
        m_aiLatencyP50 = percentile(vals, 50.0);
        m_aiLatencyP95 = percentile(vals, 95.0);
        m_aiLatencyP99 = percentile(vals, 99.0);
        m_aiLatencyAvg = sum / winCount;
    }
    // 4. 推入折线图历史(每秒一个采样点,保留最近 60 个点)
    if (m_aiTpsHistory.isEmpty() ||
        m_aiTpsHistory.last().toMap().value("t").toLongLong() != nowMs / 1000) {
        QVariantMap pt;
        pt["t"] = (qint64)(nowMs / 1000);
        pt["v"] = m_aiTps;
        m_aiTpsHistory.append(pt);
        while (m_aiTpsHistory.size() > 60) m_aiTpsHistory.removeFirst();
    } else {
        // 同秒内,更新最后一个点的值
        QVariantMap pt = m_aiTpsHistory.last().toMap();
        pt["v"] = m_aiTps;
        m_aiTpsHistory[m_aiTpsHistory.size() - 1] = pt;
    }
    emit aiInferenceMetricsUpdated();
}

void StatisticsController::resetAiMetrics() {
    m_aiSamples.clear();
    m_aiTpsHistory.clear();
    m_aiTotalInferences = 0;
    m_aiTps = 0; m_aiLatencyP50 = 0; m_aiLatencyP95 = 0; m_aiLatencyP99 = 0; m_aiLatencyAvg = 0;
    emit aiInferenceMetricsUpdated();
}

int StatisticsController::healthyModelCount() const {
    int n = 0;
    for (const auto& v : m_modelHealthList) {
        QVariantMap m = v.toMap();
        QString s = m.value("status").toString();
        if (s == "healthy" || s == "active" || s == "loaded") n++;
    }
    return n;
}

void StatisticsController::refreshModelHealth() {
    // 后端响应: {code,message,data:{models:[{id,name,type,status,...}]}}
    // extractArray 会先解包 data 信封, 再按优先级查数组
    m_api->get("/api/v1/ai/models",
        [this](QJsonObject obj) {
            QJsonArray arr = ApiClient::extractArray(obj, {"models", "items", "data"});
            m_modelHealthList.clear();
            for (const auto& v : arr) {
                QJsonObject mo = v.toObject();
                QVariantMap m = mo.toVariantMap();
                // 字段名归一化
                if (m.contains("model_id") && !m.contains("id")) m["id"] = m["model_id"];
                if (m.contains("accuracy") && m["accuracy"].toDouble() <= 1.0 && m["accuracy"].toDouble() > 0) {
                    m["accuracy_pct"] = m["accuracy"].toDouble() * 100.0;
                } else if (m.contains("accuracy_pct")) {
                    m["accuracy_pct"] = m["accuracy_pct"];
                }
                if (m.contains("drift_score")) m["drift"] = m["drift_score"];
                // 状态推断: 没字段时按 "loaded" 处理
                if (!m.contains("status") || m.value("status").toString().isEmpty()) {
                    m["status"] = "loaded";
                }
                m_modelHealthList.append(m);
            }
            emit modelHealthUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            // 失败时不覆盖旧数据(降级展示)
        });
}

void StatisticsController::setLoading(bool v) {
    if (m_loading != v) {
        m_loading = v;
        emit loadingChanged();
    }
}

double StatisticsController::deviceOnlineRate() const {
    int total = m_dashboard.value("total_devices").toInt();
    int online = m_dashboard.value("online_devices").toInt();
    if (total <= 0) return 0.0;
    return (double)online * 100.0 / (double)total;
}

void StatisticsController::refreshDashboard() {
    setLoading(true);
    m_api->get("/api/v1/stats/dashboard",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{total_devices,online_devices,security_score,hourly_trend,...}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QVariantMap d = data.toVariantMap();
            m_dashboard = d;
            m_hourlyTrend = d.value("hourly_trend").toList();
            m_topAlarmTypes = d.value("top_alarm_types").toList();
            m_riskZones = d.value("risk_zones").toList();
            emit dashboardUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void StatisticsController::refreshOverview() {
    m_api->get("/api/v1/stats/overview",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{...overview 字段...}}
            m_overview = ApiClient::unwrapData(obj).toVariantMap();
            emit overviewUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshHourlyTrend() {
    m_api->get("/api/v1/situation/hourly-stats",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{data:[...]/hourly:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "hourly", "items"});
            m_hourlyTrend.clear();
            for (const auto& v : arr) m_hourlyTrend.append(v.toVariant().toMap());
            emit dashboardUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshRecentEvents(int limit) {
    m_api->get(QString("/api/v1/alarms/history?limit=%1").arg(limit),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/alarms:[...]}}
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "alarms", "events"});
            m_recentEvents.clear();
            for (const auto& v : arr) m_recentEvents.append(v.toVariant().toMap());
            emit recentEventsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshFalseAlarmBaseline(int days) {
    m_api->get(QString("/api/v1/stats/false_alarm_baseline?days=%1").arg(days),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{...baseline 字段...}}
            QVariantMap baseline = ApiClient::unwrapData(obj).toVariantMap();
            emit falseAlarmBaselineUpdated(baseline);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshAlarmLevelDist() {
    m_api->get("/api/v1/alarms/stats",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{critical:N,high:N,medium:N,low:N,...}}
            m_alarmLevelDist = ApiClient::unwrapData(obj).toVariantMap();
            emit alarmLevelDistUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshDeviceStats() {
    m_api->get("/api/v1/devices/stats",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{online:N,offline:N,total:N,...}}
            m_deviceStats = ApiClient::unwrapData(obj).toVariantMap();
            emit deviceStatsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StatisticsController::refreshAll() {
    refreshDashboard();
    refreshOverview();
    refreshHourlyTrend();
    refreshRecentEvents(20);
    refreshAlarmLevelDist();
    refreshDeviceStats();
    // ── v7.0 P1 #10: AI 推理指标刷新 ──
    refreshModelHealth();
}