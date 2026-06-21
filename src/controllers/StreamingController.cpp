#include "StreamingController.h"
#include "utils/ApiClient.h"
#include <QJsonObject>
#include <QJsonArray>

StreamingController::StreamingController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void StreamingController::setLoading(bool v) {
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

void StreamingController::refreshStreams() {
    setLoading(true);
    m_api->get("/api/v1/streams",
        [this](QJsonObject obj) {
            QJsonArray arr = obj.value("items").toArray();
            if (arr.isEmpty()) arr = obj.value("streams").toArray();
            if (arr.isEmpty() && obj.value("data").isArray())
                arr = obj.value("data").toArray();
            m_streams.clear();
            for (const auto& v : arr) m_streams.append(v.toVariant().toMap());
            emit streamsUpdated();
            setLoading(false);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
            setLoading(false);
        });
}

void StreamingController::refreshZlmStatus() {
    m_api->get("/api/v1/zlm/status",
        [this](QJsonObject obj) {
            m_zlmStatus = obj.toVariantMap();
            emit zlmStatusUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::refreshStreamHealth() {
    m_api->get("/api/v1/media/health",
        [this](QJsonObject obj) {
            m_streamHealth = obj.toVariantMap();
            emit streamHealthUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::refreshAll() {
    refreshStreams();
    refreshZlmStatus();
    refreshStreamHealth();
}

void StreamingController::startStream(const QString& streamId) {
    m_api->post(QString("/api/v1/streams/%1/start").arg(streamId),
                QJsonObject(),
        [this, streamId](QJsonObject) {
            emit streamStarted(streamId);
            refreshStreams();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::stopStream(const QString& streamId) {
    m_api->post(QString("/api/v1/streams/%1/stop").arg(streamId),
                QJsonObject(),
        [this, streamId](QJsonObject) {
            emit streamStopped(streamId);
            refreshStreams();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::switchStream(const QString& streamId, const QString& protocol) {
    QJsonObject body; body["protocol"] = protocol;
    m_api->post(QString("/api/v1/streams/%1/switch").arg(streamId), body,
        [this](QJsonObject) { refreshStreams(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::setStreamQuality(const QString& streamId, const QString& quality) {
    QJsonObject body; body["quality"] = quality;
    m_api->post(QString("/api/v1/streams/%1/quality").arg(streamId), body,
        [this](QJsonObject) { refreshStreams(); },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::takeSnapshot(const QString& channelId) {
    m_api->post(QString("/api/v1/channels/%1/snapshot").arg(channelId),
                QJsonObject(),
        [this, channelId](QJsonObject obj) {
            QString url = obj.value("url").toString();
            if (url.isEmpty()) url = obj.value("snapshot_url").toString();
            emit snapshotTaken(channelId, url);
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::startWebRtcPlay(const QString& streamId) {
    m_api->post(QString("/api/v1/zlm/webrtc/play").arg(streamId),
                QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::stopZlmStream(const QString& streamId) {
    QJsonObject body; body["stream_id"] = streamId;
    m_api->post("/api/v1/zlm/stream/stop", body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::addProxy(const QString& srcUrl, const QString& dstKey) {
    QJsonObject body; body["src_url"] = srcUrl; body["dst_key"] = dstKey;
    m_api->post("/api/v1/zlm/proxy/add", body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void StreamingController::getStreamUrls(const QString& streamId) {
    m_api->get(QString("/api/v1/streams/%1/multi-urls").arg(streamId),
        [this, streamId](QJsonObject obj) {
            emit urlsReceived(streamId, obj.toVariantMap());
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}