#pragma once
#include <QObject>
#include <QVariantList>

class ApiClient;

class PipelineController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList pipelines READ pipelines NOTIFY pipelinesUpdated)
    Q_PROPERTY(QString currentPipelineId READ currentPipelineId WRITE setCurrentPipelineId NOTIFY currentPipelineChanged)

public:
    explicit PipelineController(ApiClient* api, QObject* parent = nullptr);

    QVariantList pipelines() const { return m_pipelines; }
    QString currentPipelineId() const { return m_currentPipelineId; }
    void setCurrentPipelineId(const QString& id);

    Q_INVOKABLE void refreshPipelines();
    Q_INVOKABLE void createPipeline(const QVariantMap& pipeline);
    Q_INVOKABLE void updatePipeline(const QString& id, const QVariantMap& updates);
    Q_INVOKABLE void deletePipeline(const QString& id);
    Q_INVOKABLE void startPipeline(const QString& id);
    Q_INVOKABLE void stopPipeline(const QString& id);
    Q_INVOKABLE void getPipelineDetail(const QString& id);

signals:
    void pipelinesUpdated();
    void currentPipelineChanged();
    void pipelineDetailReceived(const QVariantMap& detail);
    void pipelineStarted(const QString& id);
    void pipelineStopped(const QString& id);
    void errorOccurred(int code, const QString& message);

private:
    ApiClient* m_api;
    QVariantList m_pipelines;
    QString m_currentPipelineId;
};
