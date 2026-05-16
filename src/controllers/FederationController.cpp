#include "FederationController.h"
#include "utils/ApiClient.h"

FederationController::FederationController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void FederationController::refreshNodes() {
    m_api->getList("/api/v1/federation/nodes",
        [this](QJsonArray arr) {
            m_nodes.clear();
            for (const auto& item : arr)
                m_nodes.append(item.toVariant().toMap());
            emit nodesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::refreshRounds(int limit) {
    m_api->getList(QString("/api/v1/federation/rounds?limit=%1").arg(limit),
        [this](QJsonArray arr) {
            m_rounds.clear();
            for (const auto& item : arr)
                m_rounds.append(item.toVariant().toMap());
            if (!m_rounds.isEmpty()) {
                m_currentRound = m_rounds.first().toMap();
                m_federating = m_currentRound.value("status").toString() == "running";
            }
            emit roundsUpdated();
            emit roundUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::startRound(const QVariantMap& config) {
    m_api->post("/api/v1/federation/rounds/start", QJsonObject::fromVariantMap(config),
        [this](QJsonObject) { refreshRounds(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::stopRound() {
    m_api->post("/api/v1/federation/rounds/stop", QJsonObject(),
        [this](QJsonObject) {
            m_federating = false;
            emit roundUpdated();
            refreshRounds();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::getNodeDetail(const QString& nodeId) {
    m_api->get(QString("/api/v1/federation/nodes/%1").arg(nodeId),
        [this](QJsonObject obj) { emit nodeDetailReceived(obj.toVariantMap()); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::approveNode(const QString& nodeId) {
    m_api->post(QString("/api/v1/federation/nodes/%1/approve").arg(nodeId), QJsonObject(),
        [this](QJsonObject) { refreshNodes(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void FederationController::removeNode(const QString& nodeId) {
    m_api->del(QString("/api/v1/federation/nodes/%1").arg(nodeId),
        [this]() { refreshNodes(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
