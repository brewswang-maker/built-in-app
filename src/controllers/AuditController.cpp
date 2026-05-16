#include "AuditController.h"
#include "utils/ApiClient.h"

AuditController::AuditController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void AuditController::refreshLogs(int page, int pageSize) {
    m_api->getList(QString("/api/v1/audit/logs?page=%1&pageSize=%2").arg(page).arg(pageSize),
        [this](QJsonArray arr) {
            m_logs.clear();
            for (const auto& item : arr)
                m_logs.append(item.toVariant().toMap());
            m_totalCount = m_logs.size();
            emit logsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AuditController::searchLogs(const QVariantMap& filters) {
    QStringList params;
    for (auto it = filters.begin(); it != filters.end(); ++it) {
        if (!it.value().toString().isEmpty())
            params << QString("%1=%2").arg(it.key(), it.value().toString());
    }
    QString query = params.isEmpty() ? "" : "?" + params.join("&");
    m_api->getList("/api/v1/audit/logs" + query,
        [this](QJsonArray arr) {
            m_logs.clear();
            for (const auto& item : arr)
                m_logs.append(item.toVariant().toMap());
            emit logsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void AuditController::exportLogs(const QString& format) {
    m_api->get(QString("/api/v1/audit/export?format=%1").arg(format),
        [this](QJsonObject obj) {
            emit exportCompleted(obj["path"].toString());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
