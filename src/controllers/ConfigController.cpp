#include "ConfigController.h"
#include "utils/ApiClient.h"

ConfigController::ConfigController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void ConfigController::loadConfig() {
    m_api->get("/api/v1/config",
        [this](QJsonObject resp) {
            m_config = resp.toVariantMap();
            emit configUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::saveConfig(const QString& key, const QVariant& value) {
    QJsonObject body;
    body["key"] = key;
    body["value"] = QJsonValue::fromVariant(value);
    m_api->put("/api/v1/config", body,
        [this](QJsonObject) {
            emit configSaved();
            loadConfig();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::exportConfig() {
    m_api->post("/api/v1/config/export", QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::importConfig(const QString& path) {
    QJsonObject body;
    body["path"] = path;
    m_api->post("/api/v1/config/import", body,
        [this](QJsonObject) { loadConfig(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::getNetworkConfig() {
    m_api->get("/api/v1/config/network",
        [this](QJsonObject resp) {
            m_networkConfig = resp.toVariantMap();
            emit networkConfigUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::setNetworkConfig(const QVariantMap& config) {
    m_api->put("/api/v1/config/network", QJsonObject::fromVariantMap(config),
        [this](QJsonObject) {
            emit networkConfigUpdated();
            getNetworkConfig();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::getAlgorithmList() {
    m_api->getList("/api/v1/algorithms",
        [this](QJsonArray arr) {
            m_algorithms.clear();
            for (const auto& item : arr)
                m_algorithms.append(item.toVariant().toMap());
            emit algorithmsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void ConfigController::configureAlgorithm(const QString& id, const QVariantMap& params) {
    m_api->put(QString("/api/v1/algorithms/%1/config").arg(id),
               QJsonObject::fromVariantMap(params),
        [this](QJsonObject) {
            getAlgorithmList();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
