#pragma once
/**
 * @file StatisticsController.h
 * @brief 首页/态势数据统计 Controller（v5.1/v6.2 + v7.0 AI 推理指标）
 *
 * 提供首页 Dashboard、统计分析页面所需的 KPI/图表数据：
 *   - 安全评分（security_score）
 *   - 设备在线率（online_devices/total_devices）
 *   - 告警分级统计（by_level）
 *   - 告警趋势（hourly_trend / daily_trend）
 *   - 告警类型分布（top_alarm_types）
 *   - 风险区域（risk_zones）
 *   - 最近事件流（recent_events）
 *   - AI 推理指标 v7.0 (P1 #10):
 *       * TPS (60s 滑动窗口) / P50 / P95 / P99 推理延迟
 *       * 模型健康度列表 (accuracy / drift_score / status)
 *       * 推理历史 (供 Canvas 折线图)
 *
 * 对齐后端端点（box-sdk/src/core/RestApiHandlers.cpp）：
 *   - GET  /api/v1/stats/dashboard
 *   - GET  /api/v1/stats/overview
 *   - GET  /api/v1/stats/false_alarm_baseline?days=30
 *   - GET  /api/v1/situation/overview
 *   - GET  /api/v1/situation/hourly-stats
 *   - GET  /api/v1/situation/alarm-heatmap
 *   - GET  /api/v1/devices/stats
 *   - GET  /api/v1/alarms/stats
 *   - GET  /api/v1/ai/models          (v7.0: 模型健康度元数据)
 *   - WS   ai_inference (b4ced019)   (v7.0: 实时推理流)
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonObject>
#include <QList>
#include <QPair>

class ApiClient;
class WsMessageRouter;

class StatisticsController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap dashboard READ dashboard NOTIFY dashboardUpdated)
    Q_PROPERTY(QVariantMap overview READ overview NOTIFY overviewUpdated)
    Q_PROPERTY(QVariantList hourlyTrend READ hourlyTrend NOTIFY dashboardUpdated)
    Q_PROPERTY(QVariantList topAlarmTypes READ topAlarmTypes NOTIFY dashboardUpdated)
    Q_PROPERTY(QVariantList riskZones READ riskZones NOTIFY dashboardUpdated)
    Q_PROPERTY(QVariantList recentEvents READ recentEvents NOTIFY recentEventsUpdated)
    Q_PROPERTY(QVariantMap alarmLevelDist READ alarmLevelDist NOTIFY alarmLevelDistUpdated)
    // [P2-E2 2026-09-21] 处置时长 (MTTR): GET /api/v1/stats/mttr
    Q_PROPERTY(QVariantMap mttr READ mttr NOTIFY mttrUpdated)
    Q_PROPERTY(QVariantMap deviceStats READ deviceStats NOTIFY deviceStatsUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int securityScore READ securityScore NOTIFY dashboardUpdated)
    Q_PROPERTY(double deviceOnlineRate READ deviceOnlineRate NOTIFY dashboardUpdated)
    Q_PROPERTY(int todayAlarms READ todayAlarms NOTIFY dashboardUpdated)
    // ── v7.0 P1 #10 AI 推理指标 ──
    Q_PROPERTY(double aiTps READ aiTps NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(double aiLatencyP50 READ aiLatencyP50 NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(double aiLatencyP95 READ aiLatencyP95 NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(double aiLatencyP99 READ aiLatencyP99 NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(double aiLatencyAvg READ aiLatencyAvg NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(int aiTotalInferences READ aiTotalInferences NOTIFY aiInferenceMetricsUpdated)
    Q_PROPERTY(QVariantList modelHealthList READ modelHealthList NOTIFY modelHealthUpdated)
    Q_PROPERTY(int healthyModelCount READ healthyModelCount NOTIFY modelHealthUpdated)
    Q_PROPERTY(QVariantList aiTpsHistory READ aiTpsHistory NOTIFY aiInferenceMetricsUpdated)

public:
    explicit StatisticsController(ApiClient* api, QObject* parent = nullptr);

    QVariantMap dashboard() const { return m_dashboard; }
    QVariantMap overview() const { return m_overview; }
    QVariantList hourlyTrend() const { return m_hourlyTrend; }
    QVariantList topAlarmTypes() const { return m_topAlarmTypes; }
    QVariantList riskZones() const { return m_riskZones; }
    QVariantList recentEvents() const { return m_recentEvents; }
    QVariantMap alarmLevelDist() const { return m_alarmLevelDist; }
    QVariantMap mttr() const { return m_mttr; }
    QVariantMap deviceStats() const { return m_deviceStats; }
    bool loading() const { return m_loading; }
    int securityScore() const { return m_dashboard.value("security_score").toInt(); }
    double deviceOnlineRate() const;
    int todayAlarms() const { return m_dashboard.value("today_alarms").toInt(); }
    // ── v7.0 P1 #10 AI 推理指标 getters ──
    double aiTps() const { return m_aiTps; }
    double aiLatencyP50() const { return m_aiLatencyP50; }
    double aiLatencyP95() const { return m_aiLatencyP95; }
    double aiLatencyP99() const { return m_aiLatencyP99; }
    double aiLatencyAvg() const { return m_aiLatencyAvg; }
    int aiTotalInferences() const { return m_aiTotalInferences; }
    QVariantList modelHealthList() const { return m_modelHealthList; }
    int healthyModelCount() const;
    QVariantList aiTpsHistory() const { return m_aiTpsHistory; }

    Q_INVOKABLE void refreshDashboard();
    Q_INVOKABLE void refreshOverview();
    Q_INVOKABLE void refreshHourlyTrend();
    Q_INVOKABLE void refreshRecentEvents(int limit = 20);
    Q_INVOKABLE void refreshFalseAlarmBaseline(int days = 30);
    Q_INVOKABLE void refreshAlarmLevelDist();
    Q_INVOKABLE void refreshMttr(int days = 30);
    Q_INVOKABLE void refreshDeviceStats();
    Q_INVOKABLE void refreshAll();
    // ── v7.0 P1 #10 AI 推理 / 模型健康 ──
    Q_INVOKABLE void refreshModelHealth();
    Q_INVOKABLE void resetAiMetrics();

signals:
    void dashboardUpdated();
    void overviewUpdated();
    void recentEventsUpdated();
    void alarmLevelDistUpdated();
    void mttrUpdated();
    void deviceStatsUpdated();
    void loadingChanged();
    void falseAlarmBaselineUpdated(const QVariantMap& baseline);
    void errorOccurred(int code, const QString& message);
    void liveMetricsUpdated(const QVariantMap& metrics);
    // ── v7.0 P1 #10 AI 推理指标信号 ──
    void aiInferenceMetricsUpdated();
    void modelHealthUpdated();

private slots:
    // WS 路由订阅 (规范 b4ced019: system_metrics + ai_inference)
    void onSystemMetricsReceived(const QJsonObject& payload);
    void onAiInferenceReceived(const QJsonObject& payload);

private:
    void setLoading(bool v);
    // ── v7.0 P1 #10 AI 推理指标计算辅助 ──
    void recomputeAiMetrics();
    void recordInferenceSample(qint64 tsMs, double latencyMs);
    static double percentile(QList<double>& sorted, double pct);

    ApiClient* m_api;
    WsMessageRouter* m_wsRouter = nullptr;
    QVariantMap m_dashboard;
    QVariantMap m_overview;
    QVariantList m_hourlyTrend;
    QVariantList m_topAlarmTypes;
    QVariantList m_riskZones;
    QVariantList m_recentEvents;
    QVariantMap m_alarmLevelDist;
    QVariantMap m_mttr;
    QVariantMap m_deviceStats;
    bool m_loading = false;
    // ── v7.0 P1 #10 AI 推理指标状态 ──
    // 滑动窗口样本: (timestampMs, latencyMs)
    QList<QPair<qint64, double>> m_aiSamples;
    static constexpr int kAiSampleCap = 1000;   // 最多保留 1000 条
    static constexpr qint64 kAiWindowMs = 60000; // 60s 滑动窗口
    int m_aiTotalInferences = 0;
    double m_aiTps = 0.0;
    double m_aiLatencyP50 = 0.0;
    double m_aiLatencyP95 = 0.0;
    double m_aiLatencyP99 = 0.0;
    double m_aiLatencyAvg = 0.0;
    QVariantList m_aiTpsHistory;   // 折线图历史: [{t, v}]
    QVariantList m_modelHealthList; // 模型健康度列表
};