#include "MediaController.h"
#include "utils/ApiClient.h"
#include "streaming/StreamingDegradationChain.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QBuffer>
#include <QImage>
#include <QImageReader>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QJsonDocument>

namespace {
// Playback rate menu shown in the speed selector.
const QList<float> kSupportedRates = {1.0f, 2.0f, 4.0f};

// Fallback filenames when the server omits "filename".
const char* kDefaultSnapshotPrefix = "snapshot";
}  // namespace

MediaController::MediaController(ApiClient* api, QObject* parent)
    : QObject(parent),
      m_api(api),
      m_degradation(new StreamingDegradationChainController(this)) {}

void MediaController::setLayout(int grid) {
    if (m_currentLayout != grid && (grid == 1 || grid == 4 || grid == 9 || grid == 16)) {
        m_currentLayout = grid;
        emit layoutChanged();
    }
}

void MediaController::startStream(const QString& deviceId, const QString& channelId) {
    // Preserve the legacy behaviour: single RTSP URL, but also seed
    // the degradation controller so QML tiles can subscribe.
    QJsonObject body;
    body["device_id"] = deviceId;
    body["channel_id"] = channelId;
    body["protocol"] = "RTSP";
    m_api->post("/api/v1/zlm/channel/urls", body,
        [this, deviceId](QJsonObject resp) {
            handleStreamUrlsResponse(deviceId, resp);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void MediaController::startStreamWithProtocols(
    const QString& deviceId, const QString& channelId,
    const QStringList& protocols) {
    const QStringList chain = StreamingDegradationChain::normalize(protocols);
    QJsonArray arr;
    for (const QString& p : chain) arr.append(p);

    QJsonObject body;
    body["device_id"] = deviceId;
    body["channel_id"] = channelId;
    body["protocols"] = arr;
    body["chain"] = QStringList(chain).join(',');

    m_degradation->setChain(deviceId, chain);

    m_api->post("/api/v1/zlm/channel/urls", body,
        [this, deviceId](QJsonObject resp) {
            handleStreamUrlsResponse(deviceId, resp);
        },
        [this](int code, QString msg) {
            emit errorOccurred(code, msg);
        });
}

void MediaController::handleStreamUrlsResponse(const QString& deviceId,
                                               const QJsonObject& resp) {
    // Legacy single-URL response ("url" + optional "session_id").
    const QString legacyUrl = resp.value("url").toString();
    QVariantMap urls;
    if (const QJsonValue v = resp.value("urls"); v.isObject()) {
        urls = v.toObject().toVariantMap();
    }
    if (urls.isEmpty() && !legacyUrl.isEmpty())
        urls.insert(QStringLiteral("rtsp"), legacyUrl);

    if (!urls.isEmpty())
        m_degradation->setUrls(deviceId, urls);

    m_streamUrls.insert(deviceId, legacyUrl.isEmpty()
                                     ? m_degradation->activeUrl(deviceId)
                                     : legacyUrl);
    emit streamUrlsUpdated();

    const QString active = m_degradation->activeUrl(deviceId);
    emit streamStarted(deviceId, active.isEmpty() ? legacyUrl : active);
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

void MediaController::ptzControl(const QString& deviceId,
                                 const QString& command, float speed) {
    QJsonObject body;
    body["command"] = command;
    body["speed"] = speed;
    m_api->post(QString("/api/v1/ptz/%1/control").arg(deviceId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::snapshot(const QString& channelId) {
    m_api->post(QString("/api/v1/channels/%1/snapshot").arg(channelId),
                QJsonObject(),
        [](QJsonObject) {},
        [this, channelId](int code, QString msg) {
            emit errorOccurred(code, msg);
            emit snapshotFailed(channelId, code, msg);
        });
}

QString MediaController::defaultSnapshotDir() {
    QString base = QStandardPaths::writableLocation(
        QStandardPaths::PicturesLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/Pictures");
    const QString dir = base + QStringLiteral("/ShieldBox");
    QDir().mkpath(dir);
    return dir;
}

QString MediaController::timestampedFileName(const QString& channelId,
                                             const QString& hint) {
    QString name = hint.trimmed();
    if (name.isEmpty())
        name = QStringLiteral("%1_%2.jpg")
                   .arg(QString::fromLatin1(kDefaultSnapshotPrefix))
                   .arg(channelId);
    if (!name.endsWith(QStringLiteral(".jpg"), Qt::CaseInsensitive) &&
        !name.endsWith(QStringLiteral(".jpeg"), Qt::CaseInsensitive))
        name.append(QStringLiteral(".jpg"));
    return name;
}

void MediaController::snapshotToFile(const QString& channelId) {
    m_api->post(QString("/api/v1/channels/%1/snapshot").arg(channelId),
                QJsonObject(),
        [this, channelId](QJsonObject resp) {
            const QString url = resp.value("url").toString();
            const QString dataB64 = resp.value("data_base64").toString();
            const QString hint = resp.value("filename").toString();
            const QString fileName = timestampedFileName(channelId, hint);
            const QString fullPath = defaultSnapshotDir() + QLatin1Char('/') + fileName;

            if (!dataB64.isEmpty()) {
                const QByteArray bytes = QByteArray::fromBase64(dataB64.toLatin1());
                QFile f(fullPath);
                if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                    emit snapshotFailed(channelId, -1,
                                        QStringLiteral("open failed: %1").arg(fullPath));
                    return;
                }
                f.write(bytes);
                f.close();
                emit snapshotSaved(channelId, fullPath);
                return;
            }
            if (!url.isEmpty()) {
                auto* nam = new QNetworkAccessManager(this);
                QNetworkRequest req((QUrl(url)));
                QNetworkReply* reply = nam->get(req);
                connect(reply, &QNetworkReply::finished, this,
                        [this, reply, nam, channelId, fullPath]() {
                            if (reply->error() != QNetworkReply::NoError) {
                                emit snapshotFailed(channelId,
                                    int(reply->error()),
                                    reply->errorString());
                                reply->deleteLater();
                                nam->deleteLater();
                                return;
                            }
                            const QByteArray bytes = reply->readAll();
                            // Accept either raw JPEG bytes or a JSON
                            // envelope with a data_base64 field.
                            QByteArray payload = bytes;
                            if (bytes.startsWith("{")) {
                                QJsonParseError err{};
                                const auto doc = QJsonDocument::fromJson(bytes, &err);
                                if (err.error == QJsonParseError::NoError &&
                                    doc.isObject()) {
                                    const QString b64 =
                                        doc.object().value("data_base64").toString();
                                    if (!b64.isEmpty())
                                        payload = QByteArray::fromBase64(b64.toLatin1());
                                }
                            } else if (bytes.startsWith("\xFF\xD8")) {
                                // Raw JPEG - good.
                            } else {
                                // Try to decode as image and re-encode
                                // so we always store a normalized JPEG.
                                QImage img = QImage::fromData(bytes);
                                if (!img.isNull()) {
                                    QByteArray buf;
                                    QBuffer b(&buf);
                                    b.open(QIODevice::WriteOnly);
                                    img.save(&b, "JPG");
                                    payload = buf;
                                }
                            }
                            QFile f(fullPath);
                            if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                                emit snapshotFailed(channelId, -1,
                                    QStringLiteral("open failed: %1").arg(fullPath));
                            } else {
                                f.write(payload);
                                f.close();
                                emit snapshotSaved(channelId, fullPath);
                            }
                            reply->deleteLater();
                            nam->deleteLater();
                        });
                return;
            }
            // Server returned no usable payload - signal failure so
            // the QML toast can surface the problem.
            emit snapshotFailed(channelId, -1,
                                QStringLiteral("empty snapshot response"));
        },
        [this, channelId](int code, QString msg) {
            emit errorOccurred(code, msg);
            emit snapshotFailed(channelId, code, msg);
        });
}

void MediaController::startRecording(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/start").arg(channelId),
                QJsonObject(),
        [this](QJsonObject) {
            m_recording = true;
            emit recordingChanged();
        },
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::stopRecording(const QString& channelId) {
    m_api->post(QString("/api/v1/recording/%1/stop").arg(channelId),
                QJsonObject(),
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

void MediaController::startTalk(const QString& channelId) {
    QJsonObject body;
    body["channel_id"] = channelId;
    m_api->post(QString("/api/v1/channels/%1/talk/start").arg(channelId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::stopTalk() {
    m_api->post("/api/v1/channels/talk/stop", QJsonObject(),
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::ptzGotoPreset(const QString& deviceId, int presetId) {
    QJsonObject body;
    body["preset_id"] = presetId;
    m_api->post(QString("/api/v1/ptz/%1/preset/%2/goto").arg(deviceId).arg(presetId),
                body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::ptzSetPreset(const QString& deviceId, int presetId) {
    QJsonObject body;
    body["preset_id"] = presetId;
    m_api->post(QString("/api/v1/ptz/%1/preset/%2/set").arg(deviceId).arg(presetId),
                body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::startPatrol(const QString& deviceId) {
    QJsonObject body;
    m_api->post(QString("/api/v1/ptz/%1/patrol/start").arg(deviceId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

void MediaController::stopPatrol(const QString& deviceId) {
    QJsonObject body;
    m_api->post(QString("/api/v1/ptz/%1/patrol/stop").arg(deviceId), body,
        [](QJsonObject) {},
        [this](int code, QString msg) { emit errorOccurred(code, msg); });
}

QString MediaController::getStreamUrl(const QString& deviceId) const {
    return m_streamUrls.value(deviceId).toString();
}

QString MediaController::resolveStreamUrl(const QString& deviceId) const {
    const QString active = m_degradation->activeUrl(deviceId);
    if (!active.isEmpty()) return active;
    return m_streamUrls.value(deviceId).toString();
}

void MediaController::reportProtocolFailure(const QString& deviceId,
                                            const QString& protocol) {
    m_degradation->advance(deviceId, protocol);
    const QString next = m_degradation->activeUrl(deviceId);
    if (!next.isEmpty()) {
        m_streamUrls.insert(deviceId, next);
        emit streamUrlsUpdated();
        emit streamStarted(deviceId, next);
    }
}

void MediaController::setPipChannelId(const QString& channelId) {
    if (m_pipChannelId == channelId) return;
    m_pipChannelId = channelId;
    emit pipChanged();
}

void MediaController::setPipOpacity(float opacity) {
    const float v = qBound(0.0f, opacity, 1.0f);
    if (qFuzzyCompare(v, m_pipOpacity)) return;
    m_pipOpacity = v;
    emit pipChanged();
}

void MediaController::enterPip(const QString& channelId) {
    setPipChannelId(channelId);
}

void MediaController::exitPip() {
    setPipChannelId(QString());
}

void MediaController::setPlaybackRate(float rate) {
    const float v = normalizePlaybackRate(rate);
    if (qFuzzyCompare(v, m_playbackRate)) return;
    m_playbackRate = v;
    emit playbackRateChanged();
}

float MediaController::normalizePlaybackRate(float rate) const {
    float best = kSupportedRates.first();
    float bestDelta = qFabs(rate - best);
    for (float r : kSupportedRates) {
        const float d = qFabs(rate - r);
        if (d < bestDelta) { best = r; bestDelta = d; }
    }
    return best;
}

QVariantList MediaController::supportedPlaybackRates() const {
    QVariantList out;
    for (float r : kSupportedRates) out.append(r);
    return out;
}
