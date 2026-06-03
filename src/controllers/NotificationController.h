#pragma once
#include <QObject>
#include <QVariantList>

class NotificationController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY unreadCountChanged)
    Q_PROPERTY(QVariantList notifications READ notifications NOTIFY notificationsUpdated)

public:
    explicit NotificationController(QObject* parent = nullptr);

    int unreadCount() const { return m_unreadCount; }
    QVariantList notifications() const { return m_notifications; }

    Q_INVOKABLE void addNotification(const QString& title, const QString& message,
                                      const QString& type = "info");
    Q_INVOKABLE void markAllRead();
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void dismiss(int index);

signals:
    void unreadCountChanged();
    void notificationsUpdated();
    void toastRequested(const QString& message, const QString& type);

private:
    void updateUnreadCount();

    QVariantList m_notifications;
    int m_unreadCount = 0;
};
