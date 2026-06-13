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
    : QObject(parent), m_api(api), m_settings("SmartGateWay", "AlarmSettings") {
}

int AlarmController::popupDebounceMs() const {
    return m_settings.value("popupDebounceMs", 30000).toInt();
}

void AlarmController::setPopupDebounceMs(int ms) {
    if (ms < 0) ms = 0;
    if (ms != popupDebounceMs()) {
        m_settings.setValue("popupDebounceMs", ms);
        emit popupDebounceChanged();
    }
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

    // 同通道同类型去重: 仅保留最新一条
    QString chId = alarm["channel_id_str"].toString();
    if (chId.isEmpty()) chId = alarm["channel_id"].toString();
    QString alarmType = alarm["alarm_type"].toString();

    for (int i = 0; i < m_alarms.size(); ++i) {
        QVariantMap existing = m_alarms[i].toMap();
        QString exCh = existing["channel_id_str"].toString();
        if (exCh.isEmpty()) exCh = existing["channel_id"].toString();
        if (exCh == chId && existing["alarm_type"].toString() == alarmType) {
            m_alarms.removeAt(i);
            break;
        }
    }

    m_hasUnread = true;
    m_alarms.prepend(alarm);

    // 防抖: 500ms 合并窗口，批量刷新 UI
    if (!m_flushTimer) {
        m_flushTimer = new QTimer(this);
        m_flushTimer->setSingleShot(true);
        connect(m_flushTimer, &QTimer::timeout, this, &AlarmController::flushPendingUI);
    }
    m_flushTimer->start(500);

    // 弹窗防抖: 同设备同类型在 N 秒内不重复弹窗 (记录但抑制弹窗)
    qint64 now = QDateTime::currentDateTime().toMSecsSinceEpoch();
    QString popupKey = chId + ":" + alarmType;
    int debounceMs = popupDebounceMs();
    qint64 lastPopup = m_lastPopupMs.value(popupKey, 0);

    if (debounceMs > 0 && (now - lastPopup) < debounceMs) {
        // 被抑制: 记录到列表但不弹窗
        emit suppressedAlarm(alarm);
    } else {
        // 弹窗
        m_lastPopupMs[popupKey] = now;
        emit newAlarm(alarm);
    }
}

void AlarmController::flushPendingUI() {
    emit alarmsUpdated();
    if (m_alarmModel)
        m_alarmModel->setAlarms(m_alarms);
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
