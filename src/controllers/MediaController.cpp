#include "MediaController.h"
#include "utils/ApiClient.h"
#include "streaming/StreamingDegradationChain.h"
#include "streaming/WebRTCStreamProvider.h"

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
#include <QDebug>
#include <QTimer>

namespace {
// Playback rate menu shown in the speed selector.
const QList<float> kSupportedRates = {1.0f, 2.0f, 4.0f};

// Fallback filenames when the server omits "filename".
const char* kDefaultSnapshotPrefix = "snapshot";
}  // namespace

MediaController::MediaController(ApiClient* api, QObject* parent)
    : QObject(parent),
      m_api(api),
      m_degradation(new StreamingDegradationChainController(this)),
      m_webrtcProvider(new WebRTCStreamProvider(this)) {
    // P0-1: 默认禁用 WebRTC 探测,因为 Qt MediaPlayer 不支持 webrtc://
    // (macOS AVFoundation/Windows WMF/Linux gstreamer 均未原生支持)。
    // 启用需集成 libdatachannel 或 QtWebEngine(超出本任务范围)。
    m_webrtcProvider->setEnabled(false);
}

void MediaController::setLayout(int grid) {
    if (m_currentLayout != grid && (grid == 1 || grid == 4 || grid == 9 || grid == 16)) {
        m_currentLayout = grid;
        emit layoutChanged();
    }
}

void MediaController::startStream(const QString& deviceId, const QString& channelId) {
    // Fetch real stream URLs from GET /api/v1/zlm/streams
    // The stream_id follows the pattern: gb_{channelId}
    fetchStreamUrlsFromZlm(deviceId, channelId);
}

void MediaController::startStreamWithProtocols(
    const QString& deviceId, const QString& channelId,
    const QStringList& protocols) {
    // Set up the degradation chain for this device, then fetch real URLs
    const QStringList chain = StreamingDegradationChain::normalize(protocols);
    m_degradation->setChain(deviceId, chain);
    fetchStreamUrlsFromZlm(deviceId, channelId);
}

// =====================================================================
// applyZlmStreamUrls — extract URLs from a ZLM stream JSON entry
// and populate the degradation chain + streamUrls map.
//
// P0-1: 同步提取 webrtc_url 字段。如果后端已启用 WebRTC, 该字段
// 包含 webrtc://host:port/index/api/webrtc?app=live&stream=<id> URL。
// Qt MediaPlayer 不能播放 webrtc://,降级策略:
//   1. 如果 m_webrtcProvider->isEnabled() == true,调用探测;
//   2. 探测成功 -> 用 webrtc URL(后续 QML 可选处理);
//   3. 探测失败 / 禁用 -> 走原 HLS/FLV/RTSP 优先级,保持兼容。
// =====================================================================
void MediaController::applyZlmStreamUrls(const QString& deviceId,
                                         const QJsonObject& streamObj) {
    const QString rtspUrl   = streamObj.value("rtsp_url").toString();
    const QString flvUrl    = streamObj.value("flv_url").toString();
    const QString hlsUrl    = streamObj.value("hls_url").toString();
    // P0-1: ZLM 在 enable_webrtc=true 时返回 webrtc_url 字段
    const QString webrtcUrl = streamObj.value("webrtc_url").toString();

    QVariantMap urlMap;
    if (!rtspUrl.isEmpty())   urlMap.insert(QStringLiteral("rtsp"), rtspUrl);
    if (!flvUrl.isEmpty())    urlMap.insert(QStringLiteral("flv"), flvUrl);
    if (!hlsUrl.isEmpty())    urlMap.insert(QStringLiteral("hls"), hlsUrl);
    if (!webrtcUrl.isEmpty()) urlMap.insert(QStringLiteral("webrtc"), webrtcUrl);
    if (!urlMap.isEmpty())
        m_degradation->setUrls(deviceId, urlMap);

    // Pick the best URL for the platform.
    // macOS AVFoundation: HLS native, cannot play RTSP or HTTP-FLV.
    //
    // [FIX 2026-08-22] 优先级改 FLV → HLS → RTSP:
    //   原 RTSP 优先导致 ffmpeg plugin 报 "Unable to open RTSP for listening"
    //   (Qt6 ffmpeg 解析 rtsp://host:port/... 当成 listen socket, 非 connect client;
    //    即使降级到 RTSP client, 在 Sophon CV186AH + ZLM 上也不稳定)。
    //   实际验证: http://127.0.0.1:9080/rtp/...flv 返回 200 + FLV magic,
    //   是 Qt6 ffmpeg plugin 最稳的视频源。
    QString bestUrl;
#ifdef Q_OS_MACOS
    if (!hlsUrl.isEmpty())       bestUrl = hlsUrl;
    else if (!flvUrl.isEmpty())  bestUrl = flvUrl;
    else                          bestUrl = rtspUrl;
#else
    if (!flvUrl.isEmpty())       bestUrl = flvUrl;
    else if (!hlsUrl.isEmpty())  bestUrl = hlsUrl;
    else                          bestUrl = rtspUrl;
#endif

    // P0-1: 当 bestUrl 为空且只有 webrtcUrl 可用时,尝试用 WebRTCStreamProvider 探测
    //        如果服务不可达,降级链会继续推送到下一个协议
    if (bestUrl.isEmpty() && !webrtcUrl.isEmpty() && m_webrtcProvider->isEnabled()) {
        qDebug() << "[MediaController] P0-1: best URL is webrtc, requesting probe for"
                 << deviceId;
        m_webrtcProvider->requestWebRtcUrl(QString(), 0, webrtcUrl);
        // 注意: 实际探测是异步的;在此期间 QML 会拿到空 URL,
        // 降级链会推到下一个有可用 URL 的协议。
        // 探测完成后,如果服务可用,会在 webRtcResolved 中重新设置 m_streamUrls。
    }

    if (!bestUrl.isEmpty()) {
        qDebug() << "[MediaController] applyZlmStreamUrls:" << deviceId
                 << "->" << bestUrl
                 << "(webrtc:" << (!webrtcUrl.isEmpty()) << ")";
        m_streamUrls.insert(deviceId, bestUrl);
        emit streamUrlsUpdated();
        emit streamStarted(deviceId, bestUrl);
    } else if (webrtcUrl.isEmpty()) {
        qDebug() << "[MediaController] WARNING: no usable URL in stream object for" << deviceId;
    } else {
        qDebug() << "[MediaController] P0-1: only webrtc URL available, waiting for probe" << deviceId;
    }
}

// =====================================================================
// pollZlmForStream — poll GET /api/v1/zlm/streams until the target
// stream registers in ZLM.  Each attempt is 500 ms apart.
// =====================================================================
void MediaController::pollZlmForStream(const QString& deviceId,
                                       const QString& streamId,
                                       int remaining) {
    if (remaining <= 0) {
        qDebug() << "[MediaController] Polling exhausted for" << deviceId
                 << "(streamId=" << streamId << ")";
        return;
    }

    QTimer::singleShot(500, this, [this, deviceId, streamId, remaining]() {
        m_api->get("/api/v1/zlm/streams",
            [this, deviceId, streamId, remaining](QJsonObject resp) {
                QJsonObject data = ApiClient::unwrapData(resp);
                QJsonArray streams = data.value("streams").toArray();

                const QString exactStreamId = QStringLiteral("gb_%1").arg(streamId);
                const QString idSuffix11 = streamId.length() >= 11
                    ? streamId.right(11) : streamId;

                for (const QJsonValue& item : streams) {
                    QJsonObject s = item.toObject();
                    const QString sid = s.value("stream_id").toString();
                    if (sid == exactStreamId || sid == streamId ||
                        sid.endsWith(idSuffix11)) {
                        qDebug() << "[MediaController] Stream registered after polling:"
                                 << sid << "->" << deviceId
                                 << "(" << (16 - remaining) << "attempts)";
                        applyZlmStreamUrls(deviceId, s);
                        return;
                    }
                }

                // Not found yet, keep polling
                pollZlmForStream(deviceId, streamId, remaining - 1);
            },
            [this, deviceId, streamId, remaining](int code, QString msg) {
                qDebug() << "[MediaController] Poll error for" << deviceId
                         << ":" << code << "-> retry";
                pollZlmForStream(deviceId, streamId, remaining - 1);
            });
    });
}

// =====================================================================
// triggerStreamStart — full start flow aligned with Web MiniPlayer.vue:
//   1. Check if stream already exists in ZLM (quick, no side effects)
//   2. If not, POST /streams/:id/start to trigger GB28181 SIP INVITE
//   3. Poll ZLM stream list until the stream registers
// =====================================================================
void MediaController::triggerStreamStart(const QString& deviceId,
                                         const QString& channelId) {
    const QString streamId = channelId.isEmpty() ? deviceId : channelId;

    // [RC10] 防御性前置检查：设备离线时跳过拉流，避免向后端发送无意义的 SIP INVITE
    if (!isDeviceOnline(deviceId)) {
        qWarning() << "[MediaController] [RC10] Device offline, skipping triggerStreamStart:"
                   << deviceId;
        return;
    }

    qDebug() << "[MediaController] triggerStreamStart: deviceId=" << deviceId
             << "streamId=" << streamId;

    // Step 1: Check if stream already exists in ZLM
    m_api->get("/api/v1/zlm/streams",
        [this, deviceId, streamId](QJsonObject resp) {
            QJsonObject data = ApiClient::unwrapData(resp);
            QJsonArray streams = data.value("streams").toArray();

            const QString exactStreamId = QStringLiteral("gb_%1").arg(streamId);
            const QString idSuffix11 = streamId.length() >= 11
                ? streamId.right(11) : streamId;

            for (const QJsonValue& item : streams) {
                QJsonObject s = item.toObject();
                const QString sid = s.value("stream_id").toString();
                if (sid == exactStreamId || sid == streamId ||
                    sid.endsWith(idSuffix11)) {
                    qDebug() << "[MediaController] Stream already exists:" << sid
                             << "-> skipping /start";
                    applyZlmStreamUrls(deviceId, s);
                    return;
                }
            }

            // Step 2: Not in ZLM → trigger SIP INVITE via POST /start
            qDebug() << "[MediaController] Stream not in ZLM, triggering"
                     << "POST /api/v1/streams/" << streamId << "/start";
            QJsonObject body;
            body["stream_type"] = QStringLiteral("main");

            m_api->post(QString("/api/v1/streams/%1/start").arg(streamId), body,
                [this, deviceId, streamId](QJsonObject resp) {
                    QJsonObject data = ApiClient::unwrapData(resp);
                    bool zlmReady = data.value("zlmReady").toBool();
                    qDebug() << "[MediaController] /start done for" << deviceId
                             << "zlmReady=" << zlmReady;
                    // Step 3: Poll ZLM streams until the stream registers.
                    // If /start already reported zlmReady, use fewer polls.
                    pollZlmForStream(deviceId, streamId, zlmReady ? 8 : 16);
                },
                [this, deviceId, streamId](int code, QString msg) {
                    qDebug() << "[MediaController] /start failed for" << deviceId
                             << ":" << code << msg
                             << "-> polling ZLM as fallback";
                    // /start may fail if another client already started
                    // the stream. Poll ZLM anyway.
                    pollZlmForStream(deviceId, streamId, 16);
                });
        },
        [this, deviceId, streamId](int code, QString msg) {
            qDebug() << "[MediaController] zlm/streams GET failed,"
                     << "trying /start directly for" << deviceId;
            QJsonObject body;
            body["stream_type"] = QStringLiteral("main");
            m_api->post(QString("/api/v1/streams/%1/start").arg(streamId), body,
                [this, deviceId, streamId](QJsonObject) {
                    pollZlmForStream(deviceId, streamId, 16);
                },
                [this](int code, QString msg) {
                    emit errorOccurred(code, msg);
                });
        });
}

// =====================================================================
// fetchStreamUrlsFromZlm — legacy entry point, now delegates to
// triggerStreamStart for the full start + poll flow.
// =====================================================================
void MediaController::fetchStreamUrlsFromZlm(const QString& deviceId,
                                             const QString& channelId) {
    triggerStreamStart(deviceId, channelId);
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

void MediaController::stopAllStreams() {
    m_streamUrls.clear();
    emit streamUrlsUpdated();
}

void MediaController::refreshAllStreamUrls(const QVariantList& deviceIds) {
    // For each device, trigger the full stream start flow:
    //   check ZLM → POST /start (SIP INVITE) → poll ZLM for URLs
    //
    // This replaces the old approach that only called GET /api/v1/zlm/streams
    // (read-only, never triggering SIP INVITE). On cold start with 0 active
    // streams, that approach returned empty URLs indefinitely.
    //
    // Each device's triggerStreamStart runs independently and async.
    // The UI updates progressively as each stream comes alive.
    qDebug() << "[MediaController] refreshAllStreamUrls:"
             << deviceIds.size() << "devices";

    for (const QVariant& v : deviceIds) {
        const QString devId = v.toString();
        if (devId.isEmpty()) continue;

        // Ensure a default degradation chain is set
        const QStringList existingChain = m_degradation->chain(devId);
        if (existingChain.isEmpty()) {
            m_degradation->setChain(devId,
                {"rtsp", "flv", "ws-flv", "hls", "webrtc"});
        }

        triggerStreamStart(devId, devId);
    }
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
    // Use get() instead of getList() because the response is an object
    // with a nested streams array, not a top-level array.
    m_api->get("/api/v1/zlm/streams",
        [this](QJsonObject resp) {
            QJsonObject data = ApiClient::unwrapData(resp);
            QJsonArray streams = data.value("streams").toArray();
            m_channels.clear();
            for (const auto& item : streams)
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

// P1-1: AI Detection overlay — receive detection results from WebSocket
void MediaController::updateDetections(const QString& deviceId, const QVariantList& boxes) {
    m_detections[deviceId] = boxes;
    emit detectionsUpdated();
}

// [RC10] 设备在线状态缓存管理
void MediaController::setDeviceOnlineStatus(const QString& deviceId, bool online) {
    if (deviceId.isEmpty()) return;
    auto it = m_deviceOnline.find(deviceId);
    if (it == m_deviceOnline.end() || it.value() != online) {
        m_deviceOnline[deviceId] = online;
        qDebug() << "[MediaController] [RC10] Device online status updated:"
                 << deviceId << "->" << (online ? "online" : "offline");
    }
}

bool MediaController::isDeviceOnline(const QString& deviceId) const {
    auto it = m_deviceOnline.constFind(deviceId);
    // 未知设备（未同步过状态）默认允许拉流，避免误阻断
    if (it == m_deviceOnline.constEnd()) return true;
    return it.value();
}
