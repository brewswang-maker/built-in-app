#pragma once
#include <QObject>
#include <QVariantList>

class ApiClient;

class LinkageController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rules READ rules NOTIFY rulesUpdated)
    Q_PROPERTY(QVariantList logs READ logs NOTIFY logsUpdated)
    Q_PROPERTY(int totalRules READ totalRules NOTIFY rulesUpdated)
    Q_PROPERTY(int enabledRules READ enabledRules NOTIFY rulesUpdated)

public:
    explicit LinkageController(ApiClient* api, QObject* parent = nullptr);

    QVariantList rules() const { return m_rules; }
    QVariantList logs() const { return m_logs; }
    int totalRules() const { return m_rules.size(); }
    int enabledRules() const;

    Q_INVOKABLE void refreshRules();
    Q_INVOKABLE void createRule(const QVariantMap& rule);
    Q_INVOKABLE void updateRule(const QString& ruleId, const QVariantMap& updates);
    Q_INVOKABLE void deleteRule(const QString& ruleId);
    Q_INVOKABLE void toggleRule(const QString& ruleId, bool enabled);
    Q_INVOKABLE void refreshLogs(int limit = 50);
    Q_INVOKABLE void getRuleStats();

signals:
    void rulesUpdated();
    void logsUpdated();
    void ruleCreated(const QVariantMap& rule);
    void ruleDeleted(const QString& ruleId);
    void statsReceived(const QVariantMap& stats);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QVariantList m_rules;
    QVariantList m_logs;
};
