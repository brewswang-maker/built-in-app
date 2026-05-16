#pragma once
#include <QObject>
#include <QVariantMap>
#include <QVariantList>

class ApiClient;

class ConfigController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap config READ config NOTIFY configUpdated)
    Q_PROPERTY(QVariantMap networkConfig READ networkConfig NOTIFY networkConfigUpdated)
    Q_PROPERTY(QVariantList algorithms READ algorithms NOTIFY algorithmsUpdated)

public:
    explicit ConfigController(ApiClient* api, QObject* parent = nullptr);

    QVariantMap config() const { return m_config; }
    QVariantMap networkConfig() const { return m_networkConfig; }
    QVariantList algorithms() const { return m_algorithms; }

    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void saveConfig(const QString& key, const QVariant& value);
    Q_INVOKABLE void exportConfig();
    Q_INVOKABLE void importConfig(const QString& path);
    Q_INVOKABLE void getNetworkConfig();
    Q_INVOKABLE void setNetworkConfig(const QVariantMap& config);
    Q_INVOKABLE void getAlgorithmList();
    Q_INVOKABLE void configureAlgorithm(const QString& id, const QVariantMap& params);

signals:
    void configUpdated();
    void networkConfigUpdated();
    void algorithmsUpdated();
    void configSaved();
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QVariantMap m_config;
    QVariantMap m_networkConfig;
    QVariantList m_algorithms;
};
