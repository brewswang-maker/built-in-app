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