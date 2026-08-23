#include "SituationController.h"
#include "utils/ApiClient.h"

#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDebug>

// =====================================================================
// 1:1 对齐 Web 端 SituationScreen.vue 与 SituationApi (situation.ts)
//   - 仅作为 HTTP 拉取的薄包装, 不做任何本地聚合/转换
//   - 失败标记驱动 QML 空态/错误态显式展示 (硬性要求)
// =====================================================================

SituationController::SituationController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

// ───────────────────────── 工具方法 ─────────────────────────

static void setFailed(bool& flag, SituationController* self,
                      void (SituationController::*sig)()) {
    if (!flag) { flag = true; emit (self->*sig)(); }
}
static void clearFailed(bool& flag, SituationController* self,
                        void (SituationController::*sig)()) {
    if (flag) { flag = false; emit (self->*sig)(); }
}

// ───────────────────────── overview ─────────────────────────

void SituationController::refreshOverview() {
    qDebug() << "[SituationController] GET /api/v1/situation/overview";
    clearFailed(m_overviewFailed, this, &SituationController::overviewFailedChanged);
    m_api->get("/api/v1/situation/overview",
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: {deviceStats, alarmStats, securityScore, handleRate, ...}}
            QJsonObject data = ApiClient::unwrapData(obj);
            m_overview = data.toVariantMap();

            // 兼容 handleRate 字段语义: 0~100
            if (m_overview.contains("handle_rate")) {
                m_overview["handleRate"] = m_overview["handle_rate"];
            }
            if (m_overview.contains("false_positive_rate")) {
                m_overview["falsePositiveRate"] = m_overview["false_positive_rate"];
            }
            if (m_overview.contains("active_agents")) {
                m_overview["activeAgents"] = m_overview["active_agents"];
            }
            if (m_overview.contains("total_agents")) {
                m_overview["totalAgents"] = m_overview["total_agents"];
            }

            emit overviewUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_overviewFailed, this, &SituationController::overviewFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ───────────────────── realtime-alarms ─────────────────────

void SituationController::refreshRealtimeAlarms(int limit) {
    qDebug() << "[SituationController] GET /api/v1/situation/realtime-alarms?limit=" << limit;
    clearFailed(m_realtimeAlarmsFailed, this, &SituationController::realtimeAlarmsFailedChanged);
    QString path = QString("/api/v1/situation/realtime-alarms?limit=%1").arg(limit);
    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: [...]} 或顶层数组
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "items", "alarms", "list"});
            m_realtimeAlarms.clear();
            for (const auto& v : arr) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                // snake_case → camelCase 兼容 (与 Web SituationAlarmStream 类型对齐)
                if (m.contains("snapshot_url") && !m.contains("snapshotUrl")) {
                    m["snapshotUrl"] = m["snapshot_url"];
                }
                if (m.contains("device_name") && !m.contains("deviceName")) {
                    m["deviceName"] = m["device_name"];
                }
                // 兼容两种位置字段 (Web: location)
                if (m.contains("location")) m["location"] = m["location"];
                // 兼容两种类型字段 (Web: type; 内置端旧 alarm_type)
                if (m.contains("alarm_type") && !m.contains("type")) {
                    m["type"] = m["alarm_type"];
                }
                m_realtimeAlarms.append(m);
            }
            emit realtimeAlarmsUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_realtimeAlarmsFailed, this, &SituationController::realtimeAlarmsFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── hourly-stats ───────────────────────

void SituationController::refreshHourlyStats() {
    qDebug() << "[SituationController] GET /api/v1/situation/hourly-stats";
    clearFailed(m_hourlyFailed, this, &SituationController::hourlyFailedChanged);
    m_api->get("/api/v1/situation/hourly-stats",
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: [{hour, alarmCount, onlineDevices}, ...]}
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "hourly", "items"});
            m_hourlyStats.clear();
            for (const auto& v : arr) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                // snake_case → camelCase 兼容
                if (m.contains("alarm_count") && !m.contains("alarmCount")) {
                    m["alarmCount"] = m["alarm_count"];
                }
                if (m.contains("online_devices") && !m.contains("onlineDevices")) {
                    m["onlineDevices"] = m["online_devices"];
                }
                m_hourlyStats.append(m);
            }
            emit hourlyStatsUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_hourlyFailed, this, &SituationController::hourlyFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── agents ────────────────────────────

void SituationController::refreshAgents() {
    qDebug() << "[SituationController] GET /api/v1/situation/agents";
    clearFailed(m_agentsFailed, this, &SituationController::agentsFailedChanged);
    m_api->get("/api/v1/situation/agents",
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: [{type, name, status, load, calls, avgLatency, lastActiveAt}]}
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "items", "agents"});
            m_agents.clear();
            for (const auto& v : arr) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                // snake_case → camelCase 兼容
                if (m.contains("avg_latency") && !m.contains("avgLatency")) {
                    m["avgLatency"] = m["avg_latency"];
                }
                if (m.contains("last_active_at") && !m.contains("lastActiveAt")) {
                    m["lastActiveAt"] = m["last_active_at"];
                }
                m_agents.append(m);
            }
            emit agentsUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_agentsFailed, this, &SituationController::agentsFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── alarm-trend (24h/7d/30d) ────────────────────────

void SituationController::refreshAlarmTrend() {
    qDebug() << "[SituationController] GET /api/v1/stats/alarm-trend?mode=" << m_alarmTrendMode;
    clearFailed(m_alarmTrendFailed, this, &SituationController::alarmTrendFailedChanged);
    QString path = QString("/api/v1/stats/alarm-trend?mode=%1").arg(m_alarmTrendMode);
    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: {trend: [{hour, count}], top_types: [{type, count, percentage}]}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray trend = data.value("trend").toArray();
            m_alarmTrend.clear();
            for (const auto& v : trend) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                m_alarmTrend.append(m);
            }
            emit alarmTrendUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_alarmTrendFailed, this, &SituationController::alarmTrendFailedChanged);
            emit errorOccurred(code, msg);
        });
}

void SituationController::setAlarmTrendMode(const QString& m) {
    // 仅接受 24h / 7d / 30d 三种模式 (对齐 Web trendModes)
    if (m != "24h" && m != "7d" && m != "30d") return;
    if (m_alarmTrendMode == m) return;
    m_alarmTrendMode = m;
    emit alarmTrendModeChanged();
    // 模式变化 → 自动重拉数据,避免陈旧数据
    refreshAlarmTrend();
}

// ──────────────────────── map devices ────────────────────────

void SituationController::refreshMapDevices() {
    qDebug() << "[SituationController] GET /api/v1/situation/map/devices";
    clearFailed(m_mapFailed, this, &SituationController::mapFailedChanged);
    m_api->get("/api/v1/situation/map/devices",
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: [{id, name, lat, lng, status, type, alarmCount, ...}]}
            QJsonArray arr = ApiClient::extractArray(obj, {"data", "devices", "items"});
            m_mapDevices.clear();
            for (const auto& v : arr) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                if (m.contains("device_type") && !m.contains("type")) {
                    m["type"] = m["device_type"];
                }
                m_mapDevices.append(m);
            }
            emit mapDevicesUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_mapFailed, this, &SituationController::mapFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── channels (视频轮巡) ────────────────────────

void SituationController::refreshChannels(int pageSize) {
    qDebug() << "[SituationController] GET /api/v1/channels?pageSize=" << pageSize;
    clearFailed(m_channelsFailed, this, &SituationController::channelsFailedChanged);
    QString path = QString("/api/v1/channels?pageSize=%1&page=1").arg(pageSize);
    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端 PageResponse: {code, message, data: {items, total, page, pageSize}}
            //   或老格式: {items, list, channels}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr;
            const QStringList keys = {"items", "list", "channels", "data"};
            for (const auto& k : keys) {
                if (data.contains(k) && data.value(k).isArray()) {
                    arr = data.value(k).toArray();
                    break;
                }
            }
            // 兜底: 顶层数组
            if (arr.isEmpty() && obj.value("items").isArray()) arr = obj.value("items").toArray();

            m_channels.clear();
            for (const auto& v : arr) {
                QJsonObject o = v.toObject();
                QVariantMap m = o.toVariantMap();
                // snake_case → camelCase 兼容 (Web ChannelItem.id / channelId 都有)
                if (m.contains("channel_id") && !m.contains("channelId")) {
                    m["channelId"] = m["channel_id"];
                }
                if (m.contains("device_id") && !m.contains("deviceId")) {
                    m["deviceId"] = m["device_id"];
                }
                if (m.contains("channel_no") && !m.contains("channelNo")) {
                    m["channelNo"] = m["channel_no"];
                }
                if (m.contains("rtsp_url") && !m.contains("rtspUrl")) {
                    m["rtspUrl"] = m["rtsp_url"];
                }
                m_channels.append(m);
            }
            emit channelsUpdated();
        },
        [this](int code, QString msg) {
            setFailed(m_channelsFailed, this, &SituationController::channelsFailedChanged);
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── scene config (体育场3D) ────────────────────────

void SituationController::refreshSceneConfig() {
    qDebug() << "[SituationController] GET /api/v1/scene/config";
    m_api->get("/api/v1/scene/config",
        [this](QJsonObject obj) {
            // 后端响应: {code, message, data: {version, activeSceneId, scenes: [...], demoDevices: [...]}}
            QJsonObject data = ApiClient::unwrapData(obj);
            const QString activeId = data.value("activeSceneId").toString();
            QJsonObject activeScene;
            for (const auto& v : data.value("scenes").toArray()) {
                QJsonObject s = v.toObject();
                if (s.value("id").toString() == activeId) { activeScene = s; break; }
            }
            if (activeScene.isEmpty()) {
                // 无匹配 activeSceneId 时取首个场景兜底
                QJsonArray scenes = data.value("scenes").toArray();
                if (!scenes.isEmpty()) activeScene = scenes.first().toObject();
            }
            if (activeScene.isEmpty()) return; // 空配置 → 保留 QML 侧 JS 常量兜底

            // meta: ground/perimeter/rotationDeg/decor
            QVariantMap meta;
            meta["ground"] = activeScene.value("ground").toObject().toVariantMap();
            meta["perimeter"] = activeScene.value("perimeter").toObject().toVariantMap();
            meta["rotationDeg"] = activeScene.value("rotationDeg").toDouble(0);
            meta["decor"] = activeScene.value("decor").toBool(true);
            m_sceneMeta = meta;

            m_sceneBuildings.clear();
            for (const auto& v : activeScene.value("buildings").toArray()) {
                m_sceneBuildings.append(v.toObject().toVariantMap());
            }

            // demoDevices 兼容顶层与场景内两种位置
            QJsonArray demos = data.value("demoDevices").toArray();
            if (demos.isEmpty()) demos = activeScene.value("demoDevices").toArray();
            m_sceneDemoDevices.clear();
            for (const auto& v : demos) {
                m_sceneDemoDevices.append(v.toObject().toVariantMap());
            }

            m_sceneConfigLoaded = true;
            emit sceneConfigUpdated();
        },
        [this](int code, QString msg) {
            // 失败不清空: QML 侧保留 StadiumSceneData.js 本地体育场常量兜底
            qWarning() << "[SituationController] scene config failed, keep JS fallback:" << code << msg;
            emit errorOccurred(code, msg);
        });
}

// ──────────────────────── refreshAll (对齐 Web fetchSituationData) ────────────────────────

void SituationController::refreshAll() {
    refreshOverview();
    refreshMapDevices();
    refreshSceneConfig();
    refreshRealtimeAlarms(20);
    refreshAgents();
    refreshHourlyStats();
    refreshAlarmTrend();
    // channels 由 VideoPatrolPanel 自行按需触发, 不在此处预拉
}