#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;
class AlgorithmListModel;

class AlgorithmController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList algorithms READ algorithms NOTIFY algorithmsUpdated)
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsUpdated)
    Q_PROPERTY(float tpuUsage READ tpuUsage NOTIFY tpuUsageUpdated)
    Q_PROPERTY(int activeModels READ activeModels NOTIFY tpuUsageUpdated)
    Q_PROPERTY(int tpuMemoryUsed READ tpuMemoryUsed NOTIFY tpuUsageUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit AlgorithmController(ApiClient* api, QObject* parent = nullptr);

    QVariantList algorithms() const { return m_algorithms; }
    QVariantList models() const { return m_models; }
    float tpuUsage() const { return m_tpuUsage; }
    int activeModels() const { return m_activeModels; }
    int tpuMemoryUsed() const { return m_tpuMemoryUsed; }
    bool loading() const { return m_loading; }

    void setAlgorithmModel(AlgorithmListModel* model);

    Q_INVOKABLE void refreshAlgorithms();
    Q_INVOKABLE void refreshModels();
    Q_INVOKABLE void refreshTpuUsage();
    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void getAlgorithmConfig(const QString& algoId);
    Q_INVOKABLE void updateAlgorithmConfig(const QString& algoId, const QVariantMap& config);
    Q_INVOKABLE void activateModel(const QString& modelId);
    Q_INVOKABLE void deactivateModel(const QString& modelId);
    Q_INVOKABLE void deleteModel(const QString& modelId);

signals:
    void algorithmsUpdated();
    void modelsUpdated();
    void tpuUsageUpdated();
    void loadingChanged();
    void algorithmConfigReceived(const QString& algoId, const QVariantMap& config);
    void configUpdated(const QString& algoId);
    void modelActivated(const QString& modelId);
    void modelDeactivated(const QString& modelId);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    AlgorithmListModel* m_algoModel = nullptr;
    QVariantList m_algorithms;
    QVariantList m_models;
    float m_tpuUsage = 0;
    int m_activeModels = 0;
    int m_tpuMemoryUsed = 0;
    bool m_loading = false;
};
