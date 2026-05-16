#pragma once
#include <QObject>
#include <QVariantList>
#include <QWebSocket>

class ApiClient;

class AlarmController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList alarms READ alarms NOTIFY alarmsUpdated)
    Q_PROPERTY(int alarmCount READ alarmCount NOTIFY alarmsUpdated)
    Q_PROPERTY(bool hasUnread READ hasUnread NOTIFY alarmsUpdated)

public:
    explicit AlarmController(ApiClient* api, QObject* parent = nullptr);
    ~AlarmController();

    QVariantList alarms() const { return m_alarms; }
    int alarmCount() const { return m_alarms.size(); }
    bool hasUnread() const { return m_hasUnread; }

    void setAlarmModel(QObject* model) { m_alarmModel = model; }

    Q_INVOKABLE void refreshAlarms(int limit = 50);
    Q_INVOKABLE void confirmAlarm(const QString& alarmId);
    Q_INVOKABLE void markFalseAlarm(const QString& alarmId);
    Q_INVOKABLE void handleAlarm(const QString& alarmId, const QString& action);
    Q_INVOKABLE void connectWebSocket();

signals:
    void alarmsUpdated();
    void newAlarm(const QVariantMap& alarm);
    void errorOccurred(int code, const QString& message);

private slots:
    void onWsTextMessage(const QString& message);

private:
    ApiClient* m_api;
    QObject* m_alarmModel = nullptr;
    QVariantList m_alarms;
    bool m_hasUnread = false;
    QWebSocket* m_ws = nullptr;
};
