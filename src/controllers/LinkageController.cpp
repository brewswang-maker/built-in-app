#include "LinkageController.h"
#include "utils/ApiClient.h"
#include <QJsonDocument>
#include <QJsonObject>

LinkageController::LinkageController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

int LinkageController::enabledRules() const {
    int c = 0;
    for (const auto& r : m_rules)
        if (r.toMap().value("enabled").toBool()) c++;
    return c;
}

void LinkageController::refreshRules() {
    m_api->getList("/api/v1/linkage/rules",
        [this](QJsonArray arr) {
            m_rules.clear();
            for (const auto& item : arr)
                m_rules.append(item.toVariant().toMap());
            emit rulesUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::createRule(const QVariantMap& rule) {
    QJsonObject body = QJsonObject::fromVariantMap(rule);
    m_api->post("/api/v1/linkage/rules", body,
        [this](QJsonObject obj) {
            emit ruleCreated(obj.toVariantMap());
            refreshRules();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::updateRule(const QString& ruleId, const QVariantMap& updates) {
    QJsonObject body = QJsonObject::fromVariantMap(updates);
    m_api->put(QString("/api/v1/linkage/rules/%1").arg(ruleId), body,
        [this](QJsonObject) { refreshRules(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::deleteRule(const QString& ruleId) {
    m_api->del(QString("/api/v1/linkage/rules/%1").arg(ruleId),
        [this, ruleId]() {
            emit ruleDeleted(ruleId);
            refreshRules();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::toggleRule(const QString& ruleId, bool enabled) {
    QJsonObject body;
    body["enabled"] = enabled;
    m_api->put(QString("/api/v1/linkage/rules/%1").arg(ruleId), body,
        [this]() { refreshRules(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::refreshLogs(int limit) {
    m_api->getList(QString("/api/v1/linkage/logs?limit=%1").arg(limit),
        [this](QJsonArray arr) {
            m_logs.clear();
            for (const auto& item : arr)
                m_logs.append(item.toVariant().toMap());
            emit logsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void LinkageController::getRuleStats() {
    m_api->get("/api/v1/linkage/stats",
        [this](QJsonObject obj) {
            emit statsReceived(obj.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
