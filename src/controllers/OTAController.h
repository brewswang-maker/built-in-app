#pragma once
#include <QObject>
#include <QVariantList>

class ApiClient;

class OTAController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY versionUpdated)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY versionUpdated)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY versionUpdated)
    Q_PROPERTY(double upgradeProgress READ upgradeProgress NOTIFY progressChanged)
    Q_PROPERTY(bool upgrading READ upgrading NOTIFY progressChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyUpdated)

public:
    explicit OTAController(ApiClient* api, QObject* parent = nullptr);

    QString currentVersion() const { return m_currentVersion; }
    QString latestVersion() const { return m_latestVersion; }
    bool updateAvailable() const { return m_updateAvailable; }
    double upgradeProgress() const { return m_progress; }
    bool upgrading() const { return m_upgrading; }
    QVariantList history() const { return m_history; }

    Q_INVOKABLE void checkUpdate();
    Q_INVOKABLE void startUpgrade();
    Q_INVOKABLE void refreshHistory();
    Q_INVOKABLE void rollback(const QString& partition);

signals:
    void versionUpdated();
    void progressChanged();
    void historyUpdated();
    void upgradeCompleted(bool success);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QString m_currentVersion;
    QString m_latestVersion;
    bool m_updateAvailable = false;
    double m_progress = 0;
    bool m_upgrading = false;
    QVariantList m_history;
    int m_pollCount = 0;

    void pollProgress();
};
