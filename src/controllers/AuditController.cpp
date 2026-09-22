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

void AuditController::refreshStats() {
    // [P2-E2 2026-09-21] 审计统计真值 (totalLogs/todayCount/errorCount)
    m_api->get("/api/v1/audit/stats",
        [this](QJsonObject obj) {
            m_stats = ApiClient::unwrapData(obj).toVariantMap();
            emit statsUpdated();
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
    // [FIX api-contract 2026-09-22] 契约纠正: 后端 export 为 POST + body{format},
    // 响应信封 data.{url,format,count,filename}(无 "path" 字段)。
    // 旧实现 GET ?format= → 404(方法不匹配)。
    QJsonObject body;
    body["format"] = format;
    m_api->post("/api/v1/audit/export", body,
        [this](QJsonObject obj) {
            emit exportCompleted(ApiClient::unwrapData(obj).value("url").toString());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
