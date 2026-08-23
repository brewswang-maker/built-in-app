#pragma once
/**
 * @file SituationController.h
 * @brief 首页总览 — 态势大屏数据 Controller
 *
 * 提供 DashboardView 总览页与 Web 端 SituationScreen.vue 1:1 对齐的态势数据:
 *   - 态势总览 (overview)               : GET /api/v1/situation/overview
 *   - 实时告警 (realtimeAlarms)         : GET /api/v1/situation/realtime-alarms?limit=20
 *   - 时段统计 (hourlyStats)            : GET /api/v1/situation/hourly-stats
 *   - Agent 状态 (agents)               : GET /api/v1/situation/agents
 *   - 告警趋势 (alarmTrend, 24h/7d/30d) : GET /api/v1/stats/alarm-trend?mode=...
 *   - 地图设备 (mapDevices)             : GET /api/v1/situation/map/devices
 *   - 视频通道 (channels)               : GET /api/v1/channels?pageSize=100
 *   - 场景配置 (sceneBuildings/sceneMeta): GET /api/v1/scene/config
 *     (体育场3D — 与 Web 端 sceneApi.getConfig() 读同一份 scene_config.json,
 *      失败时 QML 侧回退 StadiumSceneData.js 本地常量)
 *
 * 数据契约与 Web 端 SituationScreen.vue 严格一致:
 *   - overview.deviceStats:  { total, online, offline, maintenance, onlineRate }
 *   - overview.alarmStats:   { total, critical, high, medium, low, todayTotal }
 *   - overview.securityScore:{ overall, trend }
 *   - overview.handleRate:   0~100 (百分数, 后端真实处置率)
 *   - overview.falsePositiveRate: 0~100 (可选)
 *   - overview.activeAgents / totalAgents: int
 *   - hourlyStats[i]:        { hour, alarmCount, onlineDevices }
 *   - alarmTrend[i]:         { hour (HH:MM 或 MM-DD 星期), count }
 *   - agents[i]:             { type, name, status, load, calls, avgLatency, lastActiveAt }
 *   - realtimeAlarms[i]:     { id, time (HH:MM:SS), deviceName, description, level, type,
 *                              device, timestamp, snapshotUrl, snapshot_url, metadata }
 *   - channels[i]:           { channel_id, device_id, channelNo, name, protocol, enabled,
 *                              status, rtspUrl, codec, fps, resolution, ... }
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class SituationController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap overview READ overview NOTIFY overviewUpdated)
    Q_PROPERTY(QVariantList hourlyStats READ hourlyStats NOTIFY hourlyStatsUpdated)
    Q_PROPERTY(QVariantList alarmTrend READ alarmTrend NOTIFY alarmTrendUpdated)
    Q_PROPERTY(QVariantList agents READ agents NOTIFY agentsUpdated)
    Q_PROPERTY(QVariantList realtimeAlarms READ realtimeAlarms NOTIFY realtimeAlarmsUpdated)
    Q_PROPERTY(QVariantList mapDevices READ mapDevices NOTIFY mapDevicesUpdated)
    Q_PROPERTY(QVariantList channels READ channels NOTIFY channelsUpdated)
    // ── 体育场3D 场景配置 (scene_config.json 同源) ──
    Q_PROPERTY(QVariantList sceneBuildings READ sceneBuildings NOTIFY sceneConfigUpdated)
    Q_PROPERTY(QVariantMap sceneMeta READ sceneMeta NOTIFY sceneConfigUpdated)
    Q_PROPERTY(QVariantList sceneDemoDevices READ sceneDemoDevices NOTIFY sceneConfigUpdated)
    Q_PROPERTY(bool sceneConfigLoaded READ sceneConfigLoaded NOTIFY sceneConfigUpdated)
    // 趋势模式 (24h | 7d | 30d) — 与 Web 端 alarmTrendMode 对齐
    Q_PROPERTY(QString alarmTrendMode READ alarmTrendMode WRITE setAlarmTrendMode NOTIFY alarmTrendModeChanged)
    // ── 各端点加载/失败状态(用于显式空态/错误态) ──
    Q_PROPERTY(bool overviewFailed READ overviewFailed NOTIFY overviewFailedChanged)
    Q_PROPERTY(bool realtimeAlarmsFailed READ realtimeAlarmsFailed NOTIFY realtimeAlarmsFailedChanged)
    Q_PROPERTY(bool hourlyFailed READ hourlyFailed NOTIFY hourlyFailedChanged)
    Q_PROPERTY(bool agentsFailed READ agentsFailed NOTIFY agentsFailedChanged)
    Q_PROPERTY(bool mapFailed READ mapFailed NOTIFY mapFailedChanged)
    Q_PROPERTY(bool alarmTrendFailed READ alarmTrendFailed NOTIFY alarmTrendFailedChanged)
    Q_PROPERTY(bool channelsFailed READ channelsFailed NOTIFY channelsFailedChanged)

public:
    explicit SituationController(ApiClient* api, QObject* parent = nullptr);

    QVariantMap overview() const { return m_overview; }
    QVariantList hourlyStats() const { return m_hourlyStats; }
    QVariantList alarmTrend() const { return m_alarmTrend; }
    QVariantList agents() const { return m_agents; }
    QVariantList realtimeAlarms() const { return m_realtimeAlarms; }
    QVariantList mapDevices() const { return m_mapDevices; }
    QVariantList channels() const { return m_channels; }
    QVariantList sceneBuildings() const { return m_sceneBuildings; }
    QVariantMap sceneMeta() const { return m_sceneMeta; }
    QVariantList sceneDemoDevices() const { return m_sceneDemoDevices; }
    bool sceneConfigLoaded() const { return m_sceneConfigLoaded; }
    QString alarmTrendMode() const { return m_alarmTrendMode; }
    bool overviewFailed() const { return m_overviewFailed; }
    bool realtimeAlarmsFailed() const { return m_realtimeAlarmsFailed; }
    bool hourlyFailed() const { return m_hourlyFailed; }
    bool agentsFailed() const { return m_agentsFailed; }
    bool mapFailed() const { return m_mapFailed; }
    bool alarmTrendFailed() const { return m_alarmTrendFailed; }
    bool channelsFailed() const { return m_channelsFailed; }

    void setAlarmTrendMode(const QString& m);

    // ── QML 可调用的刷新方法 ──
    Q_INVOKABLE void refreshOverview();
    Q_INVOKABLE void refreshRealtimeAlarms(int limit = 20);
    Q_INVOKABLE void refreshHourlyStats();
    Q_INVOKABLE void refreshAgents();
    Q_INVOKABLE void refreshAlarmTrend();
    Q_INVOKABLE void refreshMapDevices();
    Q_INVOKABLE void refreshChannels(int pageSize = 100);
    // 拉取体育场场景配置 (GET /api/v1/scene/config), 覆盖 StadiumSceneData.js 兜底
    Q_INVOKABLE void refreshSceneConfig();
    // 一次性并行刷新所有面板 (对齐 Web 端 fetchSituationData)
    Q_INVOKABLE void refreshAll();

signals:
    void overviewUpdated();
    void hourlyStatsUpdated();
    void alarmTrendUpdated();
    void alarmTrendModeChanged();
    void agentsUpdated();
    void realtimeAlarmsUpdated();
    void mapDevicesUpdated();
    void channelsUpdated();
    void sceneConfigUpdated();
    void overviewFailedChanged();
    void realtimeAlarmsFailedChanged();
    void hourlyFailedChanged();
    void agentsFailedChanged();
    void mapFailedChanged();
    void alarmTrendFailedChanged();
    void channelsFailedChanged();
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;

    QVariantMap m_overview;
    QVariantList m_hourlyStats;
    QVariantList m_alarmTrend;
    QVariantList m_agents;
    QVariantList m_realtimeAlarms;
    QVariantList m_mapDevices;
    QVariantList m_channels;
    QVariantList m_sceneBuildings;
    QVariantMap m_sceneMeta;
    QVariantList m_sceneDemoDevices;
    bool m_sceneConfigLoaded = false;
    QString m_alarmTrendMode = QStringLiteral("24h");

    bool m_overviewFailed = false;
    bool m_realtimeAlarmsFailed = false;
    bool m_hourlyFailed = false;
    bool m_agentsFailed = false;
    bool m_mapFailed = false;
    bool m_alarmTrendFailed = false;
    bool m_channelsFailed = false;
};