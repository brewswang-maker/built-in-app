#include "AlarmController.h"
#include "models/AlarmListModel.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
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

void AlarmController::setAlarmModel(AlarmListModel* model) {
    m_alarmModel = model;
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
            if (m_alarmModel)
                m_alarmModel->setAlarms(m_alarms);
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
    if (m_alarmModel)
        m_alarmModel->prependAlarm(alarm);
}

void AlarmController::exportAlarms(const QString& format) {
    if (m_alarms.isEmpty()) {
        emit errorOccurred(0, "No alarms to export");
        return;
    }

    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString filename = dir + "/alarms_export_" +
                       QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".csv";
    QFile file(filename);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit errorOccurred(0, "Cannot create export file");
        return;
    }

    QTextStream stream(&file);
    stream << "ID,Type,Level,Description,Status,Timestamp,Channel,Confidence\n";
    for (const auto& a : m_alarms) {
        QVariantMap m = a.toMap();
        stream << m["alarm_id"].toString() << ","
               << m["alarm_type"].toString() << ","
               << m["level"].toString() << ","
               << "\"" << m["description"].toString().replace("\"", "\"\"") << "\"" << ","
               << m["status"].toString() << ","
               << m["timestamp"].toString() << ","
               << m["channel_id"].toString() << ","
               << m["confidence"].toString() << "\n";
    }
    file.close();
}

void AlarmController::batchConfirm(const QVariantList& alarmIds) {
    QJsonArray ids;
    for (const auto& id : alarmIds)
        ids.append(id.toString());
    QJsonObject body;
    body["alarm_ids"] = ids;
    m_api->post("/api/v1/alarms/batch-confirm", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AlarmController::batchFalseAlarm(const QVariantList& alarmIds) {
    QJsonArray ids;
    for (const auto& id : alarmIds)
        ids.append(id.toString());
    QJsonObject body;
    body["alarm_ids"] = ids;
    m_api->post("/api/v1/alarms/batch-false", body,
        [this](QJsonObject) { refreshAlarms(50); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
