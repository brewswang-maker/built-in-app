#include "RecordingController.h"
#include "utils/ApiClient.h"
#include <QJsonObject>
#include <QJsonArray>

RecordingController::RecordingController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void RecordingController::setLoading(bool v) {
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

void RecordingController::query(const QVariantMap& filter) {
    setLoading(true);
    m_api->post("/api/v1/recordings/query",
                QJsonObject::fromVariantMap(filter),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/recordings:[...],total: N}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "recordings" });
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

// [V4-X2 2026-07-08] AI 标签智能检索 — POST /api/v1/recordings/smart-search
//  filter.ai_tag  → 转 target_type (后端从 metadata.class_name 提取)
//  filter.min_confidence / date / channel 透传
void RecordingController::querySmart(const QVariantMap& filter) {
    setLoading(true);
    QJsonObject body = QJsonObject::fromVariantMap(filter);
    // 客户端字段名 ai_tag → 后端字段名 target_type (语义对齐 web-admin)
    if (body.contains("ai_tag") && !body.value("ai_tag").toString().isEmpty()) {
        body["target_type"] = body.value("ai_tag");
    }
    // channel 字段 → channel_id
    if (body.contains("channel") && !body.value("channel").toString().isEmpty()) {
        body["channel_id"] = body.value("channel");
    }
    // date (YYYY-MM-DD) → start_time / end_time (YYYY-MM-DDT00:00:00 / T23:59:59)
    if (body.contains("date") && body.value("date").isString()) {
        QString d = body.value("date").toString();
        if (d.length() == 10 && d[4] == '-' && d[7] == '-') {
            body["start_time"] = d + QStringLiteral("T00:00:00");
            body["end_time"]   = d + QStringLiteral("T23:59:59");
        }
    }
    m_api->post("/api/v1/recordings/smart-search", body,
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("results").toArray();
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

// [V4-X2 2026-07-08] 获取 AI 标签可选值 — GET /api/v1/recordings/smart-search/target-types
//  用于 UI 下拉框初始化
void RecordingController::refreshTargetTypes() {
    m_api->get("/api/v1/recordings/smart-search/target-types",
        [this](QJsonObject obj) {
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = data.value("target_types").toArray();
            m_targetTypes.clear();
            for (const auto& v : arr) m_targetTypes.append(v.toString());
            // 即使空也更新, 清空下拉框
            if (m_targetTypes.isEmpty()) m_targetTypes.append(QStringLiteral("person"));
            emit targetTypesUpdated();
        },
        [this](int /*code*/, QString /*msg*/) {
            // 失败时使用默认值, 不阻塞 UI
            if (m_targetTypes.isEmpty()) m_targetTypes.append(QStringLiteral("person"));
            emit targetTypesUpdated();
        });
}

void RecordingController::refreshRecordings(int page, int pageSize) {
    setLoading(true);
    QString path = QString("/api/v1/recordings?page=%1&pageSize=%2").arg(page).arg(pageSize);
    m_api->get(path,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{items:[...]/recordings:[...],total:N}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QJsonArray arr = ApiClient::extractArray(obj, {"items", "recordings"});
            m_recordings.clear();
            for (const auto& v : arr) m_recordings.append(v.toVariant().toMap());
            m_total = data.value("total").toInt(m_recordings.size());
            emit recordingsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void RecordingController::refreshStorage() {
    m_api->get("/api/v1/system/info",
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{storage:{...}}}
            QJsonObject data = ApiClient::unwrapData(obj);
            m_storageInfo = data.value("storage").toObject().toVariantMap();
            emit storageInfoUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::play(const QString& recordingId, double startTs) {
    QJsonObject body;
    body["recording_id"] = recordingId;
    body["start_time"] = startTs;
    m_api->post(QString("/api/v1/recordings/%1/play").arg(recordingId), body,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{call_id,urls/stream_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString callId = data.value("call_id").toString();
            emit playStarted(callId, data.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::stop(const QString& recordingId) {
    m_api->post(QString("/api/v1/recordings/%1/stop").arg(recordingId),
                QJsonObject(),
        [this, recordingId](QJsonObject) { emit playStopped(recordingId); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::seek(const QString& callId, double timestamp) {
    QJsonObject body; body["timestamp"] = timestamp;
    m_api->post(QString("/api/v1/recordings/%1/seek").arg(callId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::control(const QString& callId, const QString& action) {
    QJsonObject body; body["action"] = action;
    m_api->post(QString("/api/v1/recordings/%1/control").arg(callId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::startRecord(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/start").arg(channelId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::stopRecord(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/stop").arg(channelId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::download(const QString& recordingId) {
    m_api->get(QString("/api/v1/recordings/%1/download").arg(recordingId),
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{url/download_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            emit downloadReady(url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::batchDownload(const QVariantList& recordingIds) {
    QJsonObject body;
    QJsonArray arr;
    for (const auto& v : recordingIds) arr.append(v.toString());
    body["recording_ids"] = arr;
    m_api->post("/api/v1/recordings/download", body,
        [this](QJsonObject obj) {
            // 后端响应: {code,message,data:{url/download_url}}
            QJsonObject data = ApiClient::unwrapData(obj);
            QString url = data.value("url").toString();
            emit downloadReady(url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::addTag(const QString& recordingId, const QString& tag) {
    // 标签与录像的关联通过 metadata 更新实现
    QJsonObject body;
    QJsonObject meta;
    meta["tag"] = tag;
    body["metadata"] = meta;
    m_api->put(QString("/api/v1/recordings/%1").arg(recordingId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void RecordingController::deleteRecording(const QString& recordingId) {
    m_api->del(QString("/api/v1/recordings/%1").arg(recordingId),
        [this]() { refreshRecordings(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}