#include "FaceController.h"
#include "utils/ApiClient.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>

// [FIX api-contract 2026-09-22] 全量路径补 /api/v1 前缀:
// box-sdk 人脸路由族注册在 /api/v1/face/database/*,此前 15 处调用缺前缀 → 全 404。
// 与 web-admin face.ts 对齐(baseURL=/api/v1 + /face/database/...)。
FaceController::FaceController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void FaceController::setLoading(bool v) {
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

// ══════════════════════════════════════════════════════════════
// 统计数据
// ══════════════════════════════════════════════════════════════

void FaceController::refreshStats() {
    m_api->get("/api/v1/face/database/stats",
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            m_stats = data.toVariantMap();
            emit statsUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

// ══════════════════════════════════════════════════════════════
// 记录列表 CRUD
// ══════════════════════════════════════════════════════════════

void FaceController::refreshRecords(const QString& groupType,
                                     const QString& search,
                                     int page, int pageSize) {
    setLoading(true);

    // 构建查询参数
    QStringList params;
    if (!groupType.isEmpty())
        params << QString("group_type=%1").arg(groupType);
    if (!search.isEmpty())
        params << QString("search=%1").arg(QString::fromUtf8(search.toUtf8().toPercentEncoding()));
    params << QString("page=%1").arg(page);
    params << QString("page_size=%1").arg(pageSize);

    QString path = "/api/v1/face/database/records?" + params.join("&");

    m_api->get(path,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            // 后端响应: {data: {records: [...], total, page, page_size}}
            QJsonArray arr;
            if (data.contains("records") && data["records"].isArray())
                arr = data["records"].toArray();
            else
                arr = ApiClient::extractArray(obj, {"records", "items"});

            m_records.clear();
            for (const auto& v : arr)
                m_records.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_records.size());
            emit recordsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void FaceController::addRecord(const QVariantMap& data) {
    QJsonObject body = QJsonObject::fromVariantMap(data);
    m_api->post("/api/v1/face/database/records", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QString personId = data.value("person_id").toString();
            emit recordAdded(personId);
            refreshStats();
            refreshRecords();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::updateRecord(const QString& personId, const QVariantMap& data) {
    QJsonObject body = QJsonObject::fromVariantMap(data);
    m_api->put(QString("/api/v1/face/database/records/%1").arg(personId), body,
        [this, personId](QJsonObject) {
            emit recordUpdated(personId);
            refreshRecords();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::deleteRecord(const QString& personId) {
    m_api->del(QString("/api/v1/face/database/records/%1").arg(personId),
        [this, personId]() {
            emit recordDeleted(personId);
            refreshStats();
            refreshRecords();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::batchAdd(const QVariantList& recordsData) {
    QJsonObject body;
    QJsonArray arr;
    for (const auto& v : recordsData)
        arr.append(QJsonValue::fromVariant(v));
    body["records"] = arr;

    m_api->post("/api/v1/face/database/records/batch", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            int added = data.value("added").toInt();
            int total = data.value("total").toInt();
            emit batchAdded(added, total);
            refreshStats();
            refreshRecords();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::clearGroup(const QString& groupType) {
    // [FIX 2026-07-01] del() success callback 无参数，改用 get() 获取响应
    // 先获取当前数量再删，以便 emit 准确的 deleted 数量
    m_api->get(QString("/api/v1/face/database/records?group_type=%1&page_size=1").arg(groupType),
        [this, groupType](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            int deleted = data.value("total").toInt(0);
            // 执行删除
            m_api->del(QString("/api/v1/face/database/groups/%1").arg(groupType),
                [this, groupType, deleted]() {
                    emit groupCleared(groupType, deleted);
                    refreshStats();
                    refreshRecords();
                },
                [this](int code, QString msg) {
                    emit errorOccurred(code, msg);
                });
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

// ══════════════════════════════════════════════════════════════
// 人脸比对
// ══════════════════════════════════════════════════════════════

void FaceController::matchFace(const QVariantList& embedding, int topK) {
    QJsonObject body;
    QJsonArray embArr;
    for (const auto& v : embedding)
        embArr.append(v.toDouble());
    body["embedding"] = embArr;
    body["top_k"] = topK;

    m_api->post("/api/v1/face/database/match", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray matches = data.value("matches").toArray();
            QVariantList matchList;
            for (const auto& v : matches)
                matchList.append(v.toVariant().toMap());
            emit matchResult(matchList);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

// ══════════════════════════════════════════════════════════════
// 告警 & 通行记录
// ══════════════════════════════════════════════════════════════

void FaceController::refreshAlarms(qint64 since, int limit) {
    QString path = QString("/api/v1/face/database/alarms?limit=%1").arg(limit);
    if (since > 0)
        path += QString("&since=%1").arg(since);

    m_api->get(path,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("alarms").toArray();
            m_alarms.clear();
            for (const auto& v : arr)
                m_alarms.append(v.toVariant().toMap());
            emit alarmsUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::refreshPassRecords(int hours, int limit) {
    QString path = QString("/api/v1/face/database/pass-records?hours=%1&limit=%2").arg(hours).arg(limit);

    m_api->get(path,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("pass_records").toArray();
            m_passRecords.clear();
            for (const auto& v : arr)
                m_passRecords.append(v.toVariant().toMap());
            emit passRecordsUpdated();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

// ══════════════════════════════════════════════════════════════
// 导入 / 导出 / 清理
// ══════════════════════════════════════════════════════════════

void FaceController::exportDatabase() {
    m_api->get("/api/v1/face/database/export",
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QString jsonData = data.value("json_data").toString();
            emit exportReady(jsonData);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::importDatabase(const QString& jsonData) {
    QJsonObject body;
    body["json_data"] = jsonData;
    m_api->post("/api/v1/face/database/import", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            int imported = data.value("imported").toInt();
            emit importDone(imported);
            refreshStats();
            refreshRecords();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void FaceController::cleanupExpired() {
    m_api->post("/api/v1/face/database/cleanup", QJsonObject(),
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            int disabled = data.value("disabled").toInt();
            emit cleanupDone(disabled);
            refreshStats();
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}
