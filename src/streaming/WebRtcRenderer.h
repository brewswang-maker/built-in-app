#pragma once
#include <QQuickPaintedItem>
#include <QImage>
#include <QSize>
#include <memory>

#include "WebRtcFrameSink.h"

class QTimer;
class QPainter;
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
class WebRtcClient;
#endif

/**
 * @brief WebRtcRendererItem
 *
 * 子任务 2 — V4-V1 WebRTC 渲染引擎集成(SmartGateway v4.0 §4.1)
 *
 * QML 中可放置的 WebRTC 视频节点(类型名沿用 main.cpp qmlRegisterType 注册)。
 *   - QML 端:`WebRtcView { streamUrl: "webrtc://..." }`
 *
 * [S3-3 2026-09-20] 基类改判: QQuickFramebufferObject → QQuickPaintedItem
 *   - 原因: 56mf 设备为软渲染(software backend, GL 不可用), FBO/GL 路径全失效;
 *     解码亦按实改判为 CPU 软解(见 H264Decoder)。S1T6 原"FBO + 硬解"假设作废。
 *   - paint() 从 WebRtcFrameSink 取最新帧 drawImage(等比缩放 + letterbox),
 *     由 33ms 定时器(有流时)驱动 update()。
 *   - 兼容保留: injectTestFrame / setStreamUrl / stats 属性 / sourceSize 接口不变。
 *
 * [S3-4 2026-09-20] setStreamUrl 接入真实通路:
 *   - 解析 webrtc://host:port/... 或 http(s)://... 的 app/stream 查询参数
 *   - 驱动内部 WebRtcClient(start/stop)收流解码 → sink → paint
 *   - 默认 OFF 构建(无 SHIELDBOX_ENABLE_WEBRTC_CLIENT)时 setStreamUrl 仅告警
 */
class WebRtcRendererItem : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)
    Q_PROPERTY(int totalProduced READ totalProduced NOTIFY statsChanged)
    Q_PROPERTY(int totalConsumed READ totalConsumed NOTIFY statsChanged)
    Q_PROPERTY(int totalDropped READ totalDropped NOTIFY statsChanged)
    Q_PROPERTY(int totalDecoded READ totalDecoded NOTIFY statsChanged)

public:
    explicit WebRtcRendererItem(QQuickItem* parent = nullptr);
    ~WebRtcRendererItem() override;

    /// 注入测试帧(Q_INVOKABLE,QML 调试/单测用)
    Q_INVOKABLE void injectTestFrame(int width, int height, int sequence);

    /// 设置流地址(webrtc:// 或 http(s)://, 空串=停止); 内部驱动 WebRtcClient
    Q_INVOKABLE void setStreamUrl(const QString& url);

    /// 停止收流并复位渲染定时器
    Q_INVOKABLE void stopStream();

    /// 请求关键帧(PLI; 断流恢复/G1 故障注入用)
    Q_INVOKABLE bool requestKeyframe();

    /// 当前流地址
    Q_INVOKABLE QString streamUrl() const { return m_stream_url; }

    /// 渲染回调(QQuickPaintedItem, 软渲染线程=GUI 线程)
    void paint(QPainter* painter) override;

    // Property getters
    QSize sourceSize() const;
    int totalProduced() const;
    int totalConsumed() const;
    int totalDropped() const;
    int totalDecoded() const;

    /// 暴露给测试桩以直接 pushFrame
    WebRtcFrameSink* frameSink() { return m_sink.get(); }

signals:
    void sourceSizeChanged();
    void statsChanged();
    void firstFrameRendered();               // 首帧送达渲染器(S3-5 取证锚点)
    void streamFailed(const QString& reason); // 收流失败(降级链输入)

private:
    void ensureRepaintTimer(bool start);
    void parseAndStart(const QString& url);

    std::unique_ptr<WebRtcFrameSink> m_sink;
    QImage m_image;              // 最近一帧(paint 复用, 无新帧时重绘不闪黑)
    QSize m_last_frame_size;     // 实际解码尺寸(sourceSize 上报)
    QTimer* m_repaint_timer = nullptr;
    QString m_stream_url;
    uint64_t m_last_emitted_produced = 0;

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    WebRtcClient* m_client = nullptr; // QObject 子对象(生命周期随本 item)
#endif
};
