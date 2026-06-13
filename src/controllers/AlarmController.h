#pragma once
#include <QObject>
#include <QVariantList>
#include <QTimer>
#include <QSettings>
#include <QDateTime>
#ifdef HAS_QT_WEBSOCKETS
#include <QWebSocket>
#endif

class ApiClient;
class AlarmListModel;

class AlarmController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList alarms READ alarms NOTIFY alarmsUpdated)
    Q_PROPERTY(int alarmCount READ alarmCount NOTIFY alarmsUpdated)
    Q_PROPERTY(bool hasUnread READ hasUnread NOTIFY alarmsUpdated)
    Q_PROPERTY(int popupDebounceMs READ popupDebounceMs WRITE setPopupDebounceMs NOTIFY popupDebounceChanged)

public:
    explicit AlarmController(ApiClient* api, QObject* parent = nullptr);
    ~AlarmController();

    QVariantList alarms() const { return m_alarms; }
    int alarmCount() const { return m_alarms.size(); }
    bool hasUnread() const { return m_hasUnread; }

    // 弹窗防抖配置 (默认 30000ms = 30s, 参考海康威视)
    int popupDebounceMs() const;
    void setPopupDebounceMs(int ms);

    void setAlarmModel(AlarmListModel* model);

    Q_INVOKABLE void refreshAlarms(int limit = 50);
    Q_INVOKABLE void confirmAlarm(const QString& alarmId);
    Q_INVOKABLE void markFalseAlarm(const QString& alarmId);
    Q_INVOKABLE void handleAlarm(const QString& alarmId, const QString& action);
    Q_INVOKABLE void connectWebSocket();
    Q_INVOKABLE void exportAlarms(const QString& format);
    Q_INVOKABLE void batchConfirm(const QVariantList& alarmIds);
    Q_INVOKABLE void batchFalseAlarm(const QVariantList& alarmIds);

signals:
    void alarmsUpdated();
    void newAlarm(const QVariantMap& alarm);
    void suppressedAlarm(const QVariantMap& alarm);
    void errorOccurred(int code, const QString& message);
    void popupDebounceChanged();

private slots:
    void onWsTextMessage(const QString& message);
    void flushPendingUI();

private:
    ApiClient* m_api;
    AlarmListModel* m_alarmModel = nullptr;
    QVariantList m_alarms;
    bool m_hasUnread = false;
    void* m_ws = nullptr;  // QWebSocket* when HAS_QT_WEBSOCKETS
    QTimer* m_flushTimer = nullptr;
    QSettings m_settings;

    // 弹窗防抖: key = "channelId:alarmType" → last popup timestamp
    QMap<QString, qint64> m_lastPopupMs;
};
