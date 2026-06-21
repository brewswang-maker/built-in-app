#pragma once
/**
 * @file StreamingController.h
 * @brief 流媒体管理 Controller（推流/拉流/转码/码流/快照/启停）
 *
 * 对齐后端端点：
 *   - GET    /api/v1/streams
 *   - POST   /api/v1/streams/:id/start
 *   - POST   /api/v1/streams/:id/stop
 *   - POST   /api/v1/streams/:id/switch
 *   - POST   /api/v1/streams/:id/quality
 *   - GET    /api/v1/streams/:id/multi-urls
 *   - GET    /api/v1/streams/:id/hls-url
 *   - POST   /api/v1/streams/proxy
 *   - GET    /api/v1/streams/zlm-status
 *   - GET    /api/v1/zlm/status
 *   - GET    /api/v1/zlm/streams
 *   - POST   /api/v1/zlm/stream/screenshot
 *   - POST   /api/v1/zlm/stream/stop
 *   - POST   /api/v1/zlm/webrtc/play
 *   - POST   /api/v1/zlm/proxy/add
 *   - GET    /api/v1/channels/:id/snapshot
 *   - GET    /api/v1/channels/:id/stream
 */
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApiClient;

class StreamingController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList streams READ streams NOTIFY streamsUpdated)
    Q_PROPERTY(QVariantMap zlmStatus READ zlmStatus NOTIFY zlmStatusUpdated)
    Q_PROPERTY(QVariantMap streamHealth READ streamHealth NOTIFY streamHealthUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit StreamingController(ApiClient* api, QObject* parent = nullptr);

    QVariantList streams() const { return m_streams; }
    QVariantMap zlmStatus() const { return m_zlmStatus; }
    QVariantMap streamHealth() const { return m_streamHealth; }
    bool loading() const { return m_loading; }

    Q_INVOKABLE void refreshStreams();
    Q_INVOKABLE void refreshZlmStatus();
    Q_INVOKABLE void refreshStreamHealth();
    Q_INVOKABLE void refreshAll();

    Q_INVOKABLE void startStream(const QString& streamId);
    Q_INVOKABLE void stopStream(const QString& streamId);
    Q_INVOKABLE void switchStream(const QString& streamId, const QString& protocol);
    Q_INVOKABLE void setStreamQuality(const QString& streamId, const QString& quality);
    Q_INVOKABLE void takeSnapshot(const QString& channelId);
    Q_INVOKABLE void startWebRtcPlay(const QString& streamId);
    Q_INVOKABLE void stopZlmStream(const QString& streamId);
    Q_INVOKABLE void addProxy(const QString& srcUrl, const QString& dstKey);
    Q_INVOKABLE void getStreamUrls(const QString& streamId);

signals:
    void streamsUpdated();
    void zlmStatusUpdated();
    void streamHealthUpdated();
    void loadingChanged();
    void streamStarted(const QString& streamId);
    void streamStopped(const QString& streamId);
    void snapshotTaken(const QString& channelId, const QString& url);
    void urlsReceived(const QString& streamId, const QVariantMap& urls);
    void errorOccurred(int code, const QString& message);

private:
    void setLoading(bool v);

    ApiClient* m_api;
    QVariantList m_streams;
    QVariantMap m_zlmStatus;
    QVariantMap m_streamHealth;
    bool m_loading = false;
};