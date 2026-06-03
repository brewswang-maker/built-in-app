#include "AlgorithmController.h"
#include "models/AlgorithmListModel.h"
#include "utils/ApiClient.h"

AlgorithmController::AlgorithmController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void AlgorithmController::setAlgorithmModel(AlgorithmListModel* model) {
    m_algoModel = model;
}

void AlgorithmController::refreshAlgorithms() {
    m_loading = true;
    emit loadingChanged();

    m_api->getList("/api/v1/algorithms",
        [this](QJsonArray arr) {
            m_loading = false;
            m_algorithms.clear();
            for (const auto& item : arr)
                m_algorithms.append(item.toVariant().toMap());
            emit algorithmsUpdated();
            emit loadingChanged();

            if (m_algoModel)
                m_algoModel->setAlgorithms(m_algorithms);
        },
        [this](int code, QString msg) {
            m_loading = false;
            emit loadingChanged();
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::refreshModels() {
    m_api->getList("/api/v1/models",
        [this](QJsonArray arr) {
            m_models.clear();
            for (const auto& item : arr)
                m_models.append(item.toVariant().toMap());
            emit modelsUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::refreshTpuUsage() {
    m_api->get("/api/v1/models/tpu-usage",
        [this](QJsonObject resp) {
            m_tpuUsage = resp["utilization"].toDouble();
            m_activeModels = resp["active_models"].toInt();
            m_tpuMemoryUsed = resp["memory_used"].toInt();
            emit tpuUsageUpdated();
        },
        [](int, QString) {});
}

void AlgorithmController::refreshAll() {
    refreshAlgorithms();
    refreshModels();
    refreshTpuUsage();
}

void AlgorithmController::getAlgorithmConfig(const QString& algoId) {
    m_api->get(QString("/api/v1/algorithms/%1/config").arg(algoId),
        [this, algoId](QJsonObject resp) {
            QVariantMap config = resp.toVariantMap();
            emit algorithmConfigReceived(algoId, config);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::updateAlgorithmConfig(const QString& algoId, const QVariantMap& config) {
    QJsonObject body = QJsonObject::fromVariantMap(config);
    m_api->put(QString("/api/v1/algorithms/%1/config").arg(algoId), body,
        [this, algoId](QJsonObject) {
            emit configUpdated(algoId);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::activateModel(const QString& modelId) {
    m_api->post(QString("/api/v1/models/%1/activate").arg(modelId), QJsonObject(),
        [this, modelId](QJsonObject) {
            emit modelActivated(modelId);
            refreshModels();
            refreshTpuUsage();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::deactivateModel(const QString& modelId) {
    m_api->post(QString("/api/v1/models/%1/deactivate").arg(modelId), QJsonObject(),
        [this, modelId](QJsonObject) {
            emit modelDeactivated(modelId);
            refreshModels();
            refreshTpuUsage();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void AlgorithmController::deleteModel(const QString& modelId) {
    m_api->del(QString("/api/v1/models/%1").arg(modelId),
        [this]() {
            refreshModels();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}
