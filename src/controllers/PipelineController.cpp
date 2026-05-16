#include "PipelineController.h"
#include "utils/ApiClient.h"

PipelineController::PipelineController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void PipelineController::setCurrentPipelineId(const QString& id) {
    if (m_currentPipelineId != id) {
        m_currentPipelineId = id;
        emit currentPipelineChanged();
    }
}

void PipelineController::refreshPipelines() {
    m_api->getList("/api/v1/pipelines",
        [this](QJsonArray arr) {
            m_pipelines.clear();
            for (const auto& item : arr)
                m_pipelines.append(item.toVariant().toMap());
            emit pipelinesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::createPipeline(const QVariantMap& pipeline) {
    m_api->post("/api/v1/pipelines", QJsonObject::fromVariantMap(pipeline),
        [this](QJsonObject) { refreshPipelines(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::updatePipeline(const QString& id, const QVariantMap& updates) {
    m_api->put(QString("/api/v1/pipelines/%1").arg(id), QJsonObject::fromVariantMap(updates),
        [this]() { refreshPipelines(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::deletePipeline(const QString& id) {
    m_api->del(QString("/api/v1/pipelines/%1").arg(id),
        [this]() { refreshPipelines(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::startPipeline(const QString& id) {
    m_api->post(QString("/api/v1/pipelines/%1/start").arg(id), QJsonObject(),
        [this, id]() { emit pipelineStarted(id); refreshPipelines(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::stopPipeline(const QString& id) {
    m_api->post(QString("/api/v1/pipelines/%1/stop").arg(id), QJsonObject(),
        [this, id]() { emit pipelineStopped(id); refreshPipelines(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void PipelineController::getPipelineDetail(const QString& id) {
    m_api->get(QString("/api/v1/pipelines/%1").arg(id),
        [this](QJsonObject obj) { emit pipelineDetailReceived(obj.toVariantMap()); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
