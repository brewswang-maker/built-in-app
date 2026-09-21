#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class AuditController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList logs READ logs NOTIFY logsUpdated)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY logsUpdated)
    // [P2-E2 2026-09-21] 审计统计 (后端 stub 已补真值: audit_logs 表聚合)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY statsUpdated)

public:
    explicit AuditController(ApiClient* api, QObject* parent = nullptr);

    QVariantList logs() const { return m_logs; }
    int totalCount() const { return m_totalCount; }
    QVariantMap stats() const { return m_stats; }

    Q_INVOKABLE void refreshLogs(int page = 1, int pageSize = 50);
    Q_INVOKABLE void refreshStats();
    Q_INVOKABLE void searchLogs(const QVariantMap& filters);
    Q_INVOKABLE void exportLogs(const QString& format);

signals:
    void logsUpdated();
    void statsUpdated();
    void exportCompleted(const QString& path);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QVariantList m_logs;
    int m_totalCount = 0;
    QVariantMap m_stats;
};
