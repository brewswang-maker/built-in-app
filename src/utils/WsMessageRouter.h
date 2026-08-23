/**
 * @file WsMessageRouter.h
 * @brief ShieldBox内置应用端 - WebSocket 多路消息路由(单例)
 *
 * 规范依据:
 *   - b4ced019 (WebSocket消息协议规范): 9 type 全路由 + 统一信封 {type, payload, timestamp, messageId}
 *   - 700c35a7 (WebSocket重连策略规范): 指数退避 + Last-Event-ID 续传 + 优雅关闭
 *   - 82ec775a (代码真实性规范): 严禁 Stub,所有分发必须有真实下游消费者
 *
 * 设计原则:
 *   1. 单一长连接: 全应用共用一个 WebSocket
 *   2. 解耦分发: 通过 message.type 路由到不同 Controller 的 Q_INVOKABLE 槽
 *   3. 容错自愈: 断线后指数退避重连,带 Last-Event-ID 续传
 *   4. 心跳保活: 30s 周期心跳,60s 未响应则主动断开重连
 *   5. 优雅关闭: 应用退出时发 close frame,5s 超时强杀
 *   6. 鉴权: Bearer token 从 ApiClient 读取,401 触发重登
 */
#pragma once

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QTimer>
#include <QQueue>
#include <QAtomicInt>

#ifdef HAS_QT_WEBSOCKETS
#include <QWebSocket>
#endif

class ApiClient;

/**
 * @brief WS 消息类型枚举 — 对齐规范 b4ced019
 *
 * 与后端 WS 协议严格对齐,任何新增 type 必须先在这里加 enum,
 * 再在路由 switch 中加 case,严禁裸字符串分发。
 */
enum class WsMessageType : int {
    Unknown       = 0,
    Heartbeat     = 1,   // 双向心跳; client → server: ping, server → client: pong
    Alarm         = 2,   // 告警事件 → AlarmController
    DeviceStatus  = 3,   // 设备上下线 / 状态变更 → DeviceController
    SystemMetrics = 4,   // CPU/MEM/TPU/TEMP 指标 → StatisticsController / StatusController
    AiInference   = 5,   // AI 推理实时结果 → AIController + StatisticsController
    AgentMessage  = 6,   // Hermes Agent 流式消息 → AIController
    ConfigUpdate  = 7,   // 配置热更新通知 → 触发全量刷新
    StreamEvent   = 8,   // 流媒体启停/故障 → StreamingController
    Error         = 9,   // 服务端推送的错误 → 错误中心
    AlarmMapMarker = 10  // [Audit-Add] 地图联动标记 → SituationView/AlarmController
};

inline const char* wsMessageTypeToString(WsMessageType t) {
    switch (t) {
        case WsMessageType::Heartbeat:     return "heartbeat";
        case WsMessageType::Alarm:         return "alarm";
        case WsMessageType::DeviceStatus:  return "device_status";
        case WsMessageType::SystemMetrics: return "system_metrics";
        case WsMessageType::AiInference:   return "ai_inference";
        case WsMessageType::AgentMessage:  return "agent_message";
        case WsMessageType::ConfigUpdate:  return "config_update";
        case WsMessageType::StreamEvent:   return "stream_event";
        case WsMessageType::Error:         return "error";
        case WsMessageType::AlarmMapMarker:return "system.alarm_map_marker";
        default:                            return "unknown";
    }
}

inline WsMessageType wsMessageTypeFromString(const QString& s) {
    if (s == "heartbeat")       return WsMessageType::Heartbeat;
    // [FIX 2026-06-28] 兼容后端 pushAlarm 多种 type 命名:
    //   "alarm"         — 规范 b4ced019
    //   "alarm.new"     — DrogonWsAdapter::pushAlarm 默认 type
    //   "linkage_alarm" — BoxService WEB_POPUP executor
    if (s == "alarm" || s == "alarm.new" || s == "linkage_alarm" ||
        s == "dashboard_alert" || s == "system.dashboard_alert" || s == "system.alarm")
        return WsMessageType::Alarm;
    // [FIX] system.linkage_action → AgentMessage 通道 (联动日志实时更新)
    if (s == "system.linkage_action" || s == "linkage_action")
        return WsMessageType::AgentMessage;
    if (s == "device_status")   return WsMessageType::DeviceStatus;
    if (s == "system_metrics")  return WsMessageType::SystemMetrics;
    if (s == "ai_inference")    return WsMessageType::AiInference;
    if (s == "agent_message")   return WsMessageType::AgentMessage;
    if (s == "config_update")   return WsMessageType::ConfigUpdate;
    if (s == "stream_event")    return WsMessageType::StreamEvent;
    if (s == "error" || s == "system.error") return WsMessageType::Error;
    if (s == "system.alarm_map_marker")       return WsMessageType::AlarmMapMarker;
    return WsMessageType::Unknown;
}

/**
 * @brief WS 连接状态
 */
enum class WsConnectionState : int {
    Disconnected = 0,  // 初始 / 关闭
    Connecting   = 1,  // 正在 open
    Connected    = 2,  // 已连上
    Reconnecting = 3,  // 断线后等待退避后重连
    AuthFailed   = 4   // 401 等鉴权失败,需要跳登录
};

class WsMessageRouter : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString stateString READ stateString NOTIFY stateChanged)
    Q_PROPERTY(int reconnectAttempts READ reconnectAttempts NOTIFY reconnectChanged)
    Q_PROPERTY(QString lastEventId READ lastEventId NOTIFY lastEventIdChanged)
    Q_PROPERTY(bool authenticated READ isAuthenticated NOTIFY stateChanged)

public:
    static WsMessageRouter* instance();
    static void destroyInstance();

    explicit WsMessageRouter(QObject* parent = nullptr);
    ~WsMessageRouter() override;

    // 绑定 API Client (用于读取 baseUrl / token)
    void bindApiClient(ApiClient* api);

    // 启动 WS 连接(若已连接则忽略)
    Q_INVOKABLE void openConnection();

    // 主动断开(优雅: 走 close frame, 5s 超时强杀)
    Q_INVOKABLE void closeConnection();

    // 应用退出时的强制清理
    Q_INVOKABLE void shutdown();

    // 状态
    QString stateString() const;
    int reconnectAttempts() const { return m_reconnectAttempts; }
    QString lastEventId() const { return m_lastEventId; }
    bool isAuthenticated() const { return m_state == WsConnectionState::Connected; }

    // 规范 700c35a7: 重连退避策略(对外只读)
    static int reconnectBackoffMs(int attempt);

    // 发送消息(可选,用于 client → server 主动消息, 如心跳 / ACK)
    Q_INVOKABLE bool sendMessage(WsMessageType type, const QJsonObject& payload);

signals:
    // ── 9 type 路由信号 ──
    void alarmReceived(const QJsonObject& payload);
    void deviceStatusReceived(const QJsonObject& payload);
    void systemMetricsReceived(const QJsonObject& payload);
    void aiInferenceReceived(const QJsonObject& payload);
    void agentMessageReceived(const QJsonObject& payload);
    void configUpdateReceived(const QJsonObject& payload);
    void streamEventReceived(const QJsonObject& payload);
    void errorReceived(const QJsonObject& payload);
    // [Audit-Add] 地图联动标记信号 (CLIENT_SHOW_MAP executor 推送 GPS 坐标)
    void mapMarkerReceived(const QJsonObject& payload);

    // ── 状态信号 ──
    void stateChanged();
    void reconnectChanged();
    void lastEventIdChanged();
    void authFailed(const QString& reason);

    // [P1-5 优化 2026-08-18] 断线后重连成功 (仅 drop 后恢复时发, 首次连接不发)。
    //   消费方 (AlarmController 等) 收到后 REST 补拉, 弥补断连窗口内丢失的
    //   WS 推送 (alarm_latency_diagnosis_report.md P1-5: 重连后补拉告警)。
    void reconnected();

    // ── 调试信号(QML 可订阅) ──
    void rawMessageReceived(const QString& rawJson);

private slots:
    // WebSocket 回调
    void onWsConnected();
    void onWsDisconnected();
    void onWsTextMessage(const QString& message);
    void onWsError(int code);
    void onWsSslErrors(const QString& errors);

    // 心跳超时
    void onHeartbeatTimeout();
    void onPongTimeout();
    void onReconnectTimeout();

private:
    void setState(WsConnectionState s);
    void scheduleReconnect();
    void buildAndOpenSocket();
    QJsonObject parseEnvelope(const QString& raw);
    void dispatchMessage(WsMessageType type, const QJsonObject& payload, const QString& messageId);
    void persistLastEventId(const QString& id);
    void loadLastEventId();

    // 指数退避表(规范 700c35a7: 1s → 2s → 4s → 8s → 16s → 30s 上限)
    static constexpr int kHeartbeatIntervalMs = 30000;
    static constexpr int kPongTimeoutMs       = 60000;
    static constexpr int kReconnectMaxMs      = 30000;
    static constexpr int kGracefulCloseMs     = 5000;
    static constexpr int kMaxBackoffAttempts  = 6;

    ApiClient* m_api = nullptr;
#ifdef HAS_QT_WEBSOCKETS
    QWebSocket* m_ws = nullptr;
#endif
    WsConnectionState m_state = WsConnectionState::Disconnected;
    int m_reconnectAttempts = 0;
    QTimer m_heartbeatTimer;
    QTimer m_pongTimer;
    QTimer m_reconnectTimer;

    QString m_lastEventId;
    qint64 m_lastPongMs = 0;

    // 单例
    static WsMessageRouter* s_instance;
    static QAtomicInt s_destroyed;
};
