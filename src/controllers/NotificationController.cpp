#include "NotificationController.h"
#include <QDateTime>

NotificationController::NotificationController(QObject* parent)
    : QObject(parent) {}

void NotificationController::addNotification(const QString& title,
                                              const QString& message,
                                              const QString& type) {
    QVariantMap notif;
    notif["id"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    notif["title"] = title;
    notif["message"] = message;
    notif["type"] = type;  // "info", "warning", "error", "success"
    notif["read"] = false;
    notif["timestamp"] = QDateTime::currentDateTime().toMSecsSinceEpoch();
    m_notifications.prepend(notif);
    updateUnreadCount();
    emit notificationsUpdated();
    emit toastRequested(message, type);
}

void NotificationController::markAllRead() {
    for (int i = 0; i < m_notifications.size(); ++i) {
        QVariantMap notif = m_notifications[i].toMap();
        notif["read"] = true;
        m_notifications[i] = notif;
    }
    updateUnreadCount();
    emit notificationsUpdated();
}

void NotificationController::clearAll() {
    m_notifications.clear();
    m_unreadCount = 0;
    emit unreadCountChanged();
    emit notificationsUpdated();
}

void NotificationController::dismiss(int index) {
    if (index >= 0 && index < m_notifications.size()) {
        m_notifications.removeAt(index);
        updateUnreadCount();
        emit notificationsUpdated();
    }
}

void NotificationController::updateUnreadCount() {
    int count = 0;
    for (const auto& n : m_notifications) {
        if (!n.toMap().value("read", false).toBool())
            ++count;
    }
    if (m_unreadCount != count) {
        m_unreadCount = count;
        emit unreadCountChanged();
    }
}
