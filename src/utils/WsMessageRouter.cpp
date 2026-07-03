/**
 * @file WsMessageRouter.cpp
 * @brief WsMessageRouter 单例实现 — 9 type 路由 + 重连 + 心跳 + 续传
 *
 * 严格遵循规范:
 *   - b4ced019 (WebSocket消息协议): 9 type enum + {type, payload, timestamp, messageId} 信封
 *   - 700c35a7 (WebSocket重连策略): 1s→2s→4s→8s→16s→30s 指数退避 + Last-Event-ID 续传
 *   - 82ec775a (代码真实性): 全部逻辑可执行,无 Stub
 */
#include "WsMessageRouter.h"
#include "ApiClient.h"

#include <QJsonDocument>
#include <QJsonParseError>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>
#include <QDateTime>
#include <QDebug>

#ifdef HAS_QT_WEBSOCKETS
#include <QWebSocket>
#endif

WsMessageRouter* WsMessageRouter::s_instance = nullptr;
QAtomicInt WsMessageRouter::s_destroyed(0);

// ============================================================================
// 单例管理
// ============================================================================

WsMessageRouter* WsMessageRouter::instance() {
    if (s_destroyed.loadAcquire()) {
        qWarning() << "[WsMessageRouter] instance() called after destroyInstance() — abort";
        return nullptr;
    }
    if (!s_instance) {
        s_instance = new WsMessageRouter();
    }
    return s_instance;
}

void WsMessageRouter::destroyInstance() {
    if (s_instance && !s_destroyed.loadAcquire()) {
        s_destroyed.storeRelease(1);
        delete s_instance;
        s_instance = nullptr;
    }
}

// ============================================================================
// 构造 / 析构
// ============================================================================

WsMessageRouter::WsMessageRouter(QObject* parent) : QObject(parent) {
    // 心跳定时器(30s 周期发 heartbeat)
    m_heartbeatTimer.setInterval(kHeartbeatIntervalMs);
    m_heartbeatTimer.setSingleShot(false);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &WsMessageRouter::onHeartbeatTimeout);

    // Pong 超时检测(60s 未收到 server pong 则主动断开)
    m_pongTimer.setInterval(kPongTimeoutMs);
    m_pongTimer.setSingleShot(true);
    connect(&m_pongTimer, &QTimer::timeout, this, &WsMessageRouter::onPongTimeout);

    // 重连定时器
    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &WsMessageRouter::onReconnectTimeout);

    // 启动时尝试加载上次的 lastEventId(用于续传)
    loadLastEventId();
}

WsMessageRouter::~WsMessageRouter() {
    shutdown();
}

// ============================================================================
// 公共接口
// ============================================================================

void WsMessageRouter::bindApiClient(ApiClient* api) {
    m_api = api;
    // baseUrl 变化时自动重连
    if (m_api) {
        QObject::connect(m_api, &ApiClient::baseUrlChanged, this, [this]() {
            qInfo() << "[WsMessageRouter] baseUrl changed — reconnecting";
            closeConnection();
            openConnection();
        });
    }
}

void WsMessageRouter::openConnection() {
#ifdef HAS_QT_WEBSOCKETS
    if (m_state == WsConnectionState::Connecting ||
        m_state == WsConnectionState::Connected) {
        return;  // 已在连接中
    }
    setState(WsConnectionState::Connecting);
    buildAndOpenSocket();
#else
    qWarning() << "[WsMessageRouter] HAS_QT_WEBSOCKETS not defined — WS disabled";
    setState(WsConnectionState::Disconnected);
#endif
}

void WsMessageRouter::closeConnection() {
#ifdef HAS_QT_WEBSOCKETS
    if (!m_ws) {
        setState(WsConnectionState::Disconnected);
        return;
    }
    // 优雅关闭: 发 close frame + reason
    m_ws->close(QWebSocketProtocol::CloseCodeGoingAway, "client_disconnect");
    // 5s 超时强杀
    QTimer::singleShot(kGracefulCloseMs, this, [this]() {
        if (m_ws && m_ws->state() != QAbstractSocket::UnconnectedState) {
            qWarning() << "[WsMessageRouter] graceful close timeout — force abort";
            m_ws->abort();
        }
    });
#else
    setState(WsConnectionState::Disconnected);
#endif
}

void WsMessageRouter::shutdown() {
    m_heartbeatTimer.stop();
    m_pongTimer.stop();
    m_reconnectTimer.stop();
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        m_ws->close(QWebSocketProtocol::CloseCodeGoingAway, "app_shutdown");
        QTimer::singleShot(kGracefulCloseMs, this, [this]() {
            if (m_ws) {
                m_ws->abort();
                delete m_ws;
                m_ws = nullptr;
            }
        });
    }
#endif
    setState(WsConnectionState::Disconnected);
}

QString WsMessageRouter::stateString() const {
    switch (m_state) {
        case WsConnectionState::Disconnected:  return "disconnected";
        case WsConnectionState::Connecting:    return "connecting";
        case WsConnectionState::Connected:     return "connected";
        case WsConnectionState::Reconnecting:  return "reconnecting";
        case WsConnectionState::AuthFailed:    return "auth_failed";
        default:                                return "unknown";
    }
}

bool WsMessageRouter::sendMessage(WsMessageType type, const QJsonObject& payload) {
#ifdef HAS_QT_WEBSOCKETS
    if (!m_ws || m_state != WsConnectionState::Connected) {
        return false;
    }
    QJsonObject envelope;
    envelope["type"] = QString::fromUtf8(wsMessageTypeToString(type));
    envelope["payload"] = payload;
    envelope["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    envelope["messageId"] = QString("client-%1-%2")
        .arg(QDateTime::currentMSecsSinceEpoch())
        .arg(qrand() % 100000);
    QJsonDocument doc(envelope);
    return m_ws->sendTextMessage(QString::fromUtf8(doc.toJson(QJsonDocument::Compact))) > 0;
#else
    Q_UNUSED(type) Q_UNUSED(payload)
    return false;
#endif
}

int WsMessageRouter::reconnectBackoffMs(int attempt) {
    // 规范 700c35a7: 1s → 2s → 4s → 8s → 16s → 30s 上限
    if (attempt < 0) attempt = 0;
    if (attempt > kMaxBackoffAttempts) attempt = kMaxBackoffAttempts;
    int ms = 1000 << attempt;  // 1, 2, 4, 8, 16, 32 秒
    if (ms > kReconnectMaxMs) ms = kReconnectMaxMs;
    return ms;
}

// ============================================================================
// WebSocket 生命周期
// ============================================================================

void WsMessageRouter::buildAndOpenSocket() {
#ifdef HAS_QT_WEBSOCKETS
    if (!m_api) {
        qWarning() << "[WsMessageRouter] ApiClient not bound";
        setState(WsConnectionState::Disconnected);
        return;
    }

    // 复用现有连接
    if (m_ws) {
        m_ws->deleteLater();
        m_ws = nullptr;
    }

    QString wsBase = m_api->baseUrl();
    wsBase.replace(QStringLiteral("http://"),  QStringLiteral("ws://"));
    wsBase.replace(QStringLiteral("https://"), QStringLiteral("wss://"));

    // 规范 700c35a7: 携带 Last-Event-ID 续传
    // [FIX 2026-06-28] WS 路径修正: DrogonWsAdapter 注册在 /ws, 不是 /api/v1/ws
    QUrl url(wsBase + QStringLiteral("/ws"));
    if (!m_lastEventId.isEmpty()) {
        QUrlQuery q;
        q.addQueryItem("last_event_id", m_lastEventId);
        url.setQuery(q);
    }
    // 携带 token 鉴权(query 方式,因浏览器/部分代理不支持自定义 header)
    QString token = m_api->authToken();
    if (!token.isEmpty()) {
        QUrlQuery q(url.query());
        q.addQueryItem("token", token);
        url.setQuery(q);
    }

    qInfo() << "[WsMessageRouter] connecting to" << url.toString();
    m_ws = new QWebSocket();
    connect(m_ws, &QWebSocket::connected,         this, &WsMessageRouter::onWsConnected);
    connect(m_ws, &QWebSocket::disconnected,      this, &WsMessageRouter::onWsDisconnected);
    connect(m_ws, &QWebSocket::textMessageReceived, this, &WsMessageRouter::onWsTextMessage);
    connect(m_ws, QOverload<int>::of(&QWebSocket::error), this, [this](int code) {
        onWsError(code);
    });
    m_ws->open(url);
#else
    setState(WsConnectionState::Disconnected);
#endif
}

void WsMessageRouter::onWsConnected() {
    qInfo() << "[WsMessageRouter] connected";
    setState(WsConnectionState::Connected);
    m_reconnectAttempts = 0;
    emit reconnectChanged();

    // 启动心跳
    m_heartbeatTimer.start();
    m_lastPongMs = QDateTime::currentMSecsSinceEpoch();
    m_pongTimer.start();
}

void WsMessageRouter::onWsDisconnected() {
    qInfo() << "[WsMessageRouter] disconnected";
    m_heartbeatTimer.stop();
    m_pongTimer.stop();

    // 鉴权失败(401)→ 不重连,触发跳登录
    if (m_state == WsConnectionState::AuthFailed) {
        return;
    }
    // 非预期断开 → 安排重连
    if (m_state != WsConnectionState::Disconnected) {
        scheduleReconnect();
    } else {
        setState(WsConnectionState::Disconnected);
    }
}

void WsMessageRouter::onWsError(int code) {
#ifdef HAS_QT_WEBSOCKETS
    QString errStr = m_ws ? m_ws->errorString() : QString("unknown");
    qWarning() << "[WsMessageRouter] error code=" << code << "msg=" << errStr;
    // 401 / 403 → 鉴权失败
    if (code == 401 || code == 403 || errStr.contains("Unauthorized", Qt::CaseInsensitive)) {
        setState(WsConnectionState::AuthFailed);
        emit authFailed(QString("HTTP %1: %2").arg(code).arg(errStr));
    }
#else
    Q_UNUSED(code)
#endif
}

void WsMessageRouter::onWsSslErrors(const QString& errors) {
    qWarning() << "[WsMessageRouter] ssl errors:" << errors;
}

// ============================================================================
// 消息分发 — 9 type 全路由
// ============================================================================

void WsMessageRouter::onWsTextMessage(const QString& message) {
    emit rawMessageReceived(message);

    QJsonObject env = parseEnvelope(message);
    if (env.isEmpty()) {
        qWarning() << "[WsMessageRouter] invalid envelope:" << message.left(200);
        return;
    }

    QString typeStr = env.value("type").toString();
    QString messageId = env.value("messageId").toString();
    // [FIX 2026-06-28] 兼容后端三种 payload 格式:
    //   1. 规范信封: {type, payload: {...}}
    //   2. pushSystemEvent: {type, data: {...}}
    //   3. pushAlarm flat JSON: {type: "alarm.new", alarm_id: "...", alarm_type: "...", ...}
    //      (后端 pushAlarm 将 alarm 字段展开到顶层, 无 payload/data/alarm 嵌套)
    QJsonObject payload = env.value("payload").toObject();
    if (payload.isEmpty()) payload = env.value("data").toObject();
    if (payload.isEmpty()) payload = env.value("alarm").toObject();
    // [FIX] 当三种嵌套格式都为空时, 使用整个 env 作为 payload (flat JSON 兼容)
    if (payload.isEmpty()) payload = env;

    // 持久化 lastEventId, 用于断线重连时续传
    if (!messageId.isEmpty()) {
        persistLastEventId(messageId);
    }

    WsMessageType type = wsMessageTypeFromString(typeStr);
    if (type == WsMessageType::Unknown) {
        qWarning() << "[WsMessageRouter] unknown message type:" << typeStr;
        return;
    }

    // 心跳特殊处理: 收到 server → client 的 pong 时刷新 pong 计时器
    if (type == WsMessageType::Heartbeat) {
        m_lastPongMs = QDateTime::currentMSecsSinceEpoch();
        m_pongTimer.start();
        return;  // 心跳不需要向下游分发
    }

    dispatchMessage(type, payload, messageId);
}

void WsMessageRouter::dispatchMessage(WsMessageType type, const QJsonObject& payload, const QString& messageId) {
    Q_UNUSED(messageId)
    switch (type) {
        case WsMessageType::Alarm:
            emit alarmReceived(payload);
            break;
        case WsMessageType::DeviceStatus:
            emit deviceStatusReceived(payload);
            break;
        case WsMessageType::SystemMetrics:
            emit systemMetricsReceived(payload);
            break;
        case WsMessageType::AiInference:
            emit aiInferenceReceived(payload);
            break;
        case WsMessageType::AgentMessage:
            emit agentMessageReceived(payload);
            break;
        case WsMessageType::ConfigUpdate:
            emit configUpdateReceived(payload);
            break;
        case WsMessageType::StreamEvent:
            emit streamEventReceived(payload);
            break;
        case WsMessageType::Error:
            emit errorReceived(payload);
            break;
        case WsMessageType::AlarmMapMarker:
            // [Audit-Add] 地图联动标记分发 → SituationView 告警位置渲染
            emit mapMarkerReceived(payload);
            break;
        default:
            qWarning() << "[WsMessageRouter] dispatch skipped for unknown type";
            break;
    }
}

QJsonObject WsMessageRouter::parseEnvelope(const QString& raw) {
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        return {};
    }
    return doc.object();
}

// ============================================================================
// 心跳 / 重连
// ============================================================================

void WsMessageRouter::onHeartbeatTimeout() {
    // 主动发 heartbeat 到 server
    QJsonObject payload;
    payload["ts"] = QDateTime::currentMSecsSinceEpoch();
    sendMessage(WsMessageType::Heartbeat, payload);
    // 重置 pong 超时计时
    m_pongTimer.start();
}

void WsMessageRouter::onPongTimeout() {
    qWarning() << "[WsMessageRouter] pong timeout (" << kPongTimeoutMs << "ms) — aborting";
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) m_ws->abort();
#endif
    scheduleReconnect();
}

void WsMessageRouter::scheduleReconnect() {
    if (m_state == WsConnectionState::AuthFailed) {
        return;  // 鉴权失败不重连
    }
    int delayMs = reconnectBackoffMs(m_reconnectAttempts);
    qInfo() << "[WsMessageRouter] reconnect in" << delayMs << "ms (attempt" << m_reconnectAttempts << ")";
    setState(WsConnectionState::Reconnecting);
    m_reconnectAttempts++;
    emit reconnectChanged();
    m_reconnectTimer.start(delayMs);
}

void WsMessageRouter::onReconnectTimeout() {
    qInfo() << "[WsMessageRouter] reconnecting now";
    buildAndOpenSocket();
}

// ============================================================================
// Last-Event-ID 持久化
// ============================================================================

void WsMessageRouter::persistLastEventId(const QString& id) {
    if (m_lastEventId == id) return;
    m_lastEventId = id;
    QSettings s("ShieldBox", "WsRouter");
    s.setValue("lastEventId", id);
    s.sync();
    emit lastEventIdChanged();
}

void WsMessageRouter::loadLastEventId() {
    QSettings s("ShieldBox", "WsRouter");
    m_lastEventId = s.value("lastEventId", QString()).toString();
    if (!m_lastEventId.isEmpty()) {
        emit lastEventIdChanged();
    }
}

// ============================================================================
// 状态
// ============================================================================

void WsMessageRouter::setState(WsConnectionState s) {
    if (m_state == s) return;
    m_state = s;
    emit stateChanged();
}