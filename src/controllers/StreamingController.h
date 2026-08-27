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
#include <QJsonObject>

class QTimer;
class ApiClient;
class WsMessageRouter;

class StreamingController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList streams READ streams NOTIFY streamsUpdated)
    Q_PROPERTY(QVariantMap zlmStatus READ zlmStatus NOTIFY zlmStatusUpdated)
    Q_PROPERTY(QVariantMap streamHealth READ streamHealth NOTIFY streamHealthUpdated)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    // [P2-#14 v7.6+] 定时健康巡检
    Q_PROPERTY(bool healthMonitoring READ healthMonitoring NOTIFY healthMonitoringChanged)
    Q_PROPERTY(int healthCheckIntervalSec READ healthCheckIntervalSec WRITE setHealthCheckIntervalSec NOTIFY healthCheckIntervalChanged)

public:
    explicit StreamingController(ApiClient* api, QObject* parent = nullptr);

    QVariantList streams() const { return m_streams; }
    QVariantMap zlmStatus() const { return m_zlmStatus; }
    QVariantMap streamHealth() const { return m_streamHealth; }
    bool loading() const { return m_loading; }
    bool healthMonitoring() const { return m_healthMonitoring; }
    int healthCheckIntervalSec() const { return m_healthCheckIntervalSec; }
    void setHealthCheckIntervalSec(int s);

    Q_INVOKABLE void refreshStreams();
    Q_INVOKABLE void refreshZlmStatus();
    Q_INVOKABLE void refreshStreamHealth();
    Q_INVOKABLE void refreshAll();

    // [P2-#14 v7.6+] 启动/停止 定时健康巡检
    Q_INVOKABLE void startHealthMonitoring();
    Q_INVOKABLE void stopHealthMonitoring();

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
    // [P2-#14 v7.6+] 健康度异常信号 (用于 UI 提示 + 自动降级)
    void healthDegraded(const QString& streamId, const QString& reason, const QString& suggestedProtocol);
    // [P2-#14 v7.6+] 巡检状态变化
    void healthMonitoringChanged();
    void healthCheckIntervalChanged();

private:
    void setLoading(bool v);
    // [P2-#14 v7.6+] 健康巡检定时器回调 (检测阈值后自动切换协议)
    void onHealthTimerTick();
    // 检测单条流的健康状态并选择降级协议
    QString pickFallbackProtocol(const QString& currentProtocol, const QString& streamId) const;
    // [FIX v7.6 2026-08-26] WS 流事件订阅 (WsMessageRouter 9 类路由补齐)
    void onStreamEventReceived(const QJsonObject& payload);

    ApiClient* m_api;
    WsMessageRouter* m_wsRouter = nullptr;
    QVariantList m_streams;
    QVariantMap m_zlmStatus;
    QVariantMap m_streamHealth;
    bool m_loading = false;
    QTimer* m_healthTimer = nullptr;
    bool m_healthMonitoring = false;
    int m_healthCheckIntervalSec = 30;
};