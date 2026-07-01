#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QHash>
#include <QStringList>

// Q_PROPERTY 需要 StreamingDegradationChainController 完整定义(moc 会调用 QMetaType::fromType)
#include "streaming/StreamingDegradationChain.h"

class ApiClient;
class WebRTCStreamProvider;  // P0-1: 前向声明避免循环包含

/**
 * @brief MediaController
 *
 * Manages live video streaming, PTZ, recording, snapshot, talk-back and
 * picture-in-picture for the built-in app. Protocol selection is
 * delegated to StreamingDegradationChainController which exposes the
 * 5-protocol degradation chain (rtsp / flv / ws-flv / hls / webrtc) to
 * QML.
 */
class MediaController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int currentLayout READ currentLayout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QVariantList channels READ channels NOTIFY channelsUpdated)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingChanged)
    Q_PROPERTY(QVariantMap streamUrls READ streamUrls NOTIFY streamUrlsUpdated)
    Q_PROPERTY(StreamingDegradationChainController* degradation
               READ degradation CONSTANT)
    Q_PROPERTY(QString pipChannelId READ pipChannelId
               WRITE setPipChannelId NOTIFY pipChanged)
    Q_PROPERTY(float pipOpacity READ pipOpacity
               WRITE setPipOpacity NOTIFY pipChanged)
    Q_PROPERTY(float playbackRate READ playbackRate
               WRITE setPlaybackRate NOTIFY playbackRateChanged)
    // P1-1: AI detection overlay data (deviceId -> detection boxes array)
    Q_PROPERTY(QVariantMap detections READ detections NOTIFY detectionsUpdated)

public:
    explicit MediaController(ApiClient* api, QObject* parent = nullptr);

    int currentLayout() const { return m_currentLayout; }
    void setLayout(int grid);
    QVariantList channels() const { return m_channels; }
    bool isRecording() const { return m_recording; }
    QVariantMap streamUrls() const { return m_streamUrls; }
    StreamingDegradationChainController* degradation() const { return m_degradation; }
    QString pipChannelId() const { return m_pipChannelId; }
    void setPipChannelId(const QString& channelId);
    float pipOpacity() const { return m_pipOpacity; }
    void setPipOpacity(float opacity);
    float playbackRate() const { return m_playbackRate; }
    void setPlaybackRate(float rate);
    QVariantMap detections() const { return m_detections; }

    Q_INVOKABLE void startStream(const QString& deviceId, const QString& channelId);
    /// Variant that requests a server-side degradation chain. The
    /// response is fed into the StreamingDegradationChainController so
    /// QML tiles can subscribe to per-protocol failover events.
    Q_INVOKABLE void startStreamWithProtocols(
        const QString& deviceId, const QString& channelId,
        const QStringList& protocols);

    Q_INVOKABLE void stopStream(const QString& sessionId);
    /// Clears all cached stream URLs and notifies QML so every
    /// VideoTile reverts to its placeholder state.
    Q_INVOKABLE void stopAllStreams();
    /// Fetches ALL active streams from ZLM and maps them to the given
    /// device IDs by index position. This bypasses the GB28181
    /// device_id/channel_id mismatch problem entirely.
    Q_INVOKABLE void refreshAllStreamUrls(const QVariantList& deviceIds);
    Q_INVOKABLE void ptzControl(const QString& deviceId,
                                const QString& command, float speed);
    Q_INVOKABLE void snapshot(const QString& channelId);
    /// Server-side snapshot + local JPEG save into
    /// QStandardPaths::PicturesLocation / "ShieldBox" / filename. The
    /// server response should include {url, filename} or
    /// {data_base64, filename}. Emits snapshotSaved() on success.
    Q_INVOKABLE void snapshotToFile(const QString& channelId);
    Q_INVOKABLE void startRecording(const QString& channelId);
    Q_INVOKABLE void stopRecording(const QString& channelId);
    Q_INVOKABLE void refreshStreams();
    Q_INVOKABLE void startTalk(const QString& channelId);
    Q_INVOKABLE void stopTalk();
    Q_INVOKABLE void ptzGotoPreset(const QString& deviceId, int presetId);
    Q_INVOKABLE void ptzSetPreset(const QString& deviceId, int presetId);
    Q_INVOKABLE void startPatrol(const QString& deviceId);
    Q_INVOKABLE void stopPatrol(const QString& deviceId);
    Q_INVOKABLE QString getStreamUrl(const QString& deviceId) const;
    /// Returns the URL the QML tile should bind to for the given
    /// device, taking the active protocol of the degradation chain
    /// into account. Falls back to the legacy single-URL map.
    Q_INVOKABLE QString resolveStreamUrl(const QString& deviceId) const;
    /// Notifies the controller that the @p protocol failed to deliver
    /// frames. The controller advances the cursor and emits
    /// protocolFailed() so QML can show a toast.
    Q_INVOKABLE void reportProtocolFailure(const QString& deviceId,
                                           const QString& protocol);
    /// Suggests the PiP tile bind to @p channelId. Pass an empty id
    /// to disable PiP.
    Q_INVOKABLE void enterPip(const QString& channelId);
    Q_INVOKABLE void exitPip();
    /// Returns one of {1, 2, 4} clamped to the supported set.
    Q_INVOKABLE float normalizePlaybackRate(float rate) const;
    /// Returns the list of supported playback rates for the UI.
    Q_INVOKABLE QVariantList supportedPlaybackRates() const;
    /// P1-1: Receive detection results from WebSocket and update QML tiles
    Q_INVOKABLE void updateDetections(const QString& deviceId, const QVariantList& boxes);

signals:
    void layoutChanged();
    void channelsUpdated();
    void recordingChanged();
    void streamUrlsUpdated();
    void streamStarted(const QString& deviceId, const QString& url);
    void streamStopped(const QString& sessionId);
    void errorOccurred(int code, const QString& message);
    void pipChanged();
    void playbackRateChanged();
    void snapshotSaved(const QString& channelId, const QString& filePath);
    void snapshotFailed(const QString& channelId,
                        int code, const QString& message);
    void detectionsUpdated();

private:
    // Legacy single-query path (now delegates to triggerStreamStart)
    void fetchStreamUrlsFromZlm(const QString& deviceId,
                                  const QString& channelId);
    // Triggers GB28181 SIP INVITE via POST /streams/:id/start, then polls
    // GET /api/v1/zlm/streams until the stream registers in ZLM.
    void triggerStreamStart(const QString& deviceId,
                            const QString& channelId);
    // Polls ZLM stream list for streamId, up to `remaining` attempts
    // (500 ms apart). Extracts absolute URLs when found.
    void pollZlmForStream(const QString& deviceId,
                          const QString& streamId, int remaining);
    // Extracts rtsp/flv/hls URLs from a ZLM stream JSON object and
    // applies them to the degradation chain + streamUrls map.
    void applyZlmStreamUrls(const QString& deviceId,
                            const QJsonObject& streamObj);
    static QString defaultSnapshotDir();
    static QString timestampedFileName(const QString& channelId,
                                       const QString& hint = {});

    ApiClient* m_api;
    int m_currentLayout = 4;
    QVariantList m_channels;
    bool m_recording = false;
    QVariantMap m_streamUrls;
    StreamingDegradationChainController* m_degradation = nullptr;
    // P0-1: WebRTC 探测器,默认禁用(Qt MediaPlayer 不支持 webrtc://)
    WebRTCStreamProvider* m_webrtcProvider = nullptr;
    QString m_pipChannelId;
    float m_pipOpacity = 0.85f;
    float m_playbackRate = 1.0f;
    QVariantMap m_detections; // deviceId -> [{x,y,width,height,label,confidence,color}, ...]
};
