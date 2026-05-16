#include "MediaController.h"
#include "utils/ApiClient.h"

MediaController::MediaController(ApiClient* api, QObject* parent)
    : QObject(parent), m_api(api) {}

void MediaController::setLayout(int grid) {
    if (m_currentLayout != grid && (grid == 1 || grid == 4 || grid == 9 || grid == 16)) {
        m_currentLayout = grid;
        emit layoutChanged();
    }
}

void MediaController::startStream(const QString& deviceId, const QString& channelId) {
    QJsonObject body;
    body["device_id"] = deviceId;
    body["channel_id"] = channelId;
    body["protocol"] = "RTSP";
    m_api->post("/api/v1/zlm/channel/urls", body,
        [this, deviceId](QJsonObject resp) {
            QString url = resp["url"].toString();
            emit streamStarted(deviceId, url);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void MediaController::stopStream(const QString& sessionId) {
    m_api->del(QString("/api/v1/zlm/streams/%1").arg(sessionId),
        [this, sessionId]() {
            emit streamStopped(sessionId);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void MediaController::ptzControl(const QString& deviceId, const QString& command, float speed) {
    QJsonObject body;
    body["command"] = command;
    body["speed"] = speed;
    m_api->post(QString("/api/v1/ptz/%1/control").arg(deviceId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::snapshot(const QString& channelId) {
    m_api->post(QString("/api/v1/channels/%1/snapshot").arg(channelId), QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::startRecording(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/start").arg(channelId), QJsonObject(),
        [this](QJsonObject) {
            m_recording = true;
            emit recordingChanged();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::stopRecording(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/stop").arg(channelId), QJsonObject(),
        [this](QJsonObject) {
            m_recording = false;
            emit recordingChanged();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::refreshStreams() {
    m_api->getList("/api/v1/zlm/streams",
        [this](QJsonArray arr) {
            m_channels.clear();
            for (const auto& item : arr)
                m_channels.append(item.toVariant().toMap());
            emit channelsUpdated();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}
