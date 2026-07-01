#pragma once
#include <QObject>
#include <QString>
#include <QHash>
#include <QTimer>
#include <QDateTime>

/**
 * @brief WebRTCStreamProvider
 *
 * 探测 ZLMediaKit WebRTC 服务的可用性，并在 Qt MediaPlayer 不支持
 * webrtc:// 协议时自动降级到 HLS / FLV。
 *
 * 设计要点 (P0-1: 视频点播 22ec775a 规范):
 *   1. 真实可用 — 通过 HEAD 请求探测 webrtc 端口 (默认 8000),
 *      使用 QNetworkAccessManager 而非 stub。
 *   2. 性能约束 — 探测结果按主机:端口缓存 60s,避免每路流重复探测。
 *   3. 接口兼容 — 与现有 StreamingDegradationChainController 协作,
 *      仅在协议链含 webrtc 时调用。
 *   4. 配置开关 — 可通过 setEnabled() 全局禁用(默认 false,
 *      因 Qt MediaPlayer 不原生支持 webrtc://)。
 *   5. Fallback 路径 — 探测失败或禁用时,返回空 URL,
 *      降级链继续推进到下一个协议。
 *
 * Qt MediaPlayer 不支持 webrtc:// 的原因:
 *   - Linux: GStreamer webrtcbin plugin 需要额外安装
 *   - macOS: AVFoundation 仅支持 HTTP/HLS/RTSP,无 WebRTC
 *   - Windows: WMF 不支持 WebRTC
 * 因此本组件的默认行为是: 即使 webrtc 服务可达,也降级到 hls
 * (与原生 MediaPlayer 兼容)。如需真实 WebRTC 渲染,需集成
 * libdatachannel 或 QWebEngine(超出本任务范围,见 v3.1 文档)。
 *
 * 信号:
 *   - webRtcProbed(host, port, available) 探测完成
 *   - webRtcFallback(host, port, reason)  发生降级
 */
class WebRTCStreamProvider : public QObject {
    Q_OBJECT
public:
    explicit WebRTCStreamProvider(QObject* parent = nullptr);

    /// 全局启用开关。默认 false — 即使探测成功也走降级路径,
    /// 因为 Qt MediaPlayer 无法渲染 webrtc://。
    void setEnabled(bool enabled) { m_enabled = enabled; }
    bool isEnabled() const { return m_enabled; }

    /// 启动异步探测。返回的 webrtc URL 通过 webRtcResolved 信号回调。
    /// 如果 webrtc 不可用,emit webRtcFallback。
    void requestWebRtcUrl(const QString& host, int port,
                          const QString& streamId);

    /// 同步探测(用于单测)。返回 true 表示服务可达。
    bool probeSync(const QString& host, int port, int timeoutMs = 1000);

    /// 构造 webrtc:// URL (与 ZLMMediaKitAdapter.cpp:1292 一致)。
    static QString buildWebRtcUrl(const QString& host, int port,
                                  const QString& streamId);

    /// 统计信息(用于 SMOKE 测试与监控)
    struct Stats {
        int total_probes = 0;          // 总探测次数
        int successful_probes = 0;     // 探测成功次数
        int fallback_count = 0;        // 触发降级次数
        QDateTime last_probe_at;       // 最近探测时间
    };
    Stats stats() const { return m_stats; }

signals:
    /// webrtc URL 解析完成。@p url 在降级时为空字符串。
    void webRtcResolved(const QString& host, int port,
                        const QString& streamId, const QString& url);
    /// 服务不可达或禁用,触发降级。@p reason 描述原因。
    void webRtcFallback(const QString& host, int port,
                        const QString& streamId, const QString& reason);

private:
    struct CacheEntry {
        bool available;
        QDateTime expiresAt;
    };

    bool m_enabled = false;
    QHash<QString, CacheEntry> m_cache; // key = "host:port"
    Stats m_stats;
};