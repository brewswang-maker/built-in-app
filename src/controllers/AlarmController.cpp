#include "AlarmController.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#ifdef HAS_QT_WEBSOCKETS
#include <QSystemTrayIcon>
#endif

AlarmController::AlarmController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
}

AlarmController::~AlarmController() {
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
    }
#endif
}

void AlarmController::refreshAlarms(int limit) {
    m_api->getList(QString("/api/v1/alarms?limit=%1").arg(limit),
        [this](QJsonArray arr) {
            m_alarms.clear();
            for (const auto& item : arr)
                m_alarms.append(item.toVariant().toMap());
            m_hasUnread = false;
            for (const auto& a : m_alarms) {
                if (a.toMap().value("status").toString() == "unhandled") {
                    m_hasUnread = true;
                    break;
                }
            }
            emit alarmsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::confirmAlarm(const QString& alarmId) {
    m_api->post(QString("/api/v1/alarms/%1/confirm").arg(alarmId), QJsonObject(),
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::markFalseAlarm(const QString& alarmId) {
    m_api->post(QString("/api/v1/alarms/%1/false").arg(alarmId), QJsonObject(),
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::handleAlarm(const QString& alarmId, const QString& action) {
    QJsonObject body;
    body["action"] = action;
    m_api->post(QString("/api/v1/alarms/%1/handle").arg(alarmId), body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::connectWebSocket() {
#ifdef HAS_QT_WEBSOCKETS
    if (m_ws) {
        static_cast<QWebSocket*>(m_ws)->close();
        delete static_cast<QWebSocket*>(m_ws);
        m_ws = nullptr;
    }
    QString wsUrl = m_api->property("baseUrl").toString();
    wsUrl.replace("http://", "ws://").replace("https://", "wss://");
    wsUrl += "/api/v1/alarms/stream";
    auto* ws = new QWebSocket();
    m_ws = ws;
    connect(ws, &QWebSocket::textMessageReceived,
            this, &AlarmController::onWsTextMessage);
    ws->open(QUrl(wsUrl));
#endif
}

void AlarmController::onWsTextMessage(const QString& message) {
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QVariantMap alarm = doc.object().toVariantMap();
    m_hasUnread = true;
    m_alarms.prepend(alarm);
    emit alarmsUpdated();
    emit newAlarm(alarm);
}
