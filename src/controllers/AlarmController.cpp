#include "AlarmController.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#include <QSystemTrayIcon>

AlarmController::AlarmController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {
}

AlarmController::~AlarmController() {
    if (m_ws) {
        m_ws->close();
        delete m_ws;
    }
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
    if (m_ws) {
        m_ws->close();
        delete m_ws;
    }
    QString wsUrl = m_api->property("baseUrl").toString();
    wsUrl.replace("http://", "ws://").replace("https://", "wss://");
    wsUrl += "/api/v1/alarms/stream";
    m_ws = new QWebSocket();
    connect(m_ws, &QWebSocket::textMessageReceived,
            this, &AlarmController::onWsTextMessage);
    m_ws->open(QUrl(wsUrl));
}

void AlarmController::onWsTextMessage(const QString& message) {
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QVariantMap alarm = doc.object().toVariantMap();
    m_hasUnread = true;
    m_alarms.prepend(alarm);
    emit alarmsUpdated();
    emit newAlarm(alarm);
}
