#pragma once
#include <QQuickFramebufferObject>
#include <QImage>
#include <memory>

#include "WebRtcFrameSink.h"

/**
 * @brief WebRtcRendererItem
 *
 * 子任务 2 — V4-V1 WebRTC 渲染引擎集成(SmartGateWay v4.0 §4.1)
 *
 * QQuickFramebufferObject 子类,作为 QML 中可放置的 WebRTC 视频节点。
 *   - QML 端:`WebRtcView { anchors.fill: parent; url: "..." }`
 *   - 渲染端:createRenderer() 返回 QtQuick 自管理线程的 Renderer 实例。
 *
 * 渲染流程:
 *   1. QML 渲染线程 → FBO Renderer::render() 每帧调用一次。
 *   2. render() 从 WebRtcFrameSink::swapFrameForRender() 取出最新 decoded frame。
 *   3. 通过 QPainter::drawImage() 绘制到 FBO → Qt Quick 主合成 → HDMI 输出。
 *
 * 设计要点:
 *   - **零拷贝纹理上传**:QImage 直接 drawImage,Qt Quick 内部升级为纹理
 *     (避免 glTexImage2D 调用)。
 *   - **生产/消费线程分离**:Producer = H264Decoder / 测试桩,Consumer = Quick FBO 线程,
 *     中间通过 WebRtcFrameSink 的 lock-free 双缓冲协调。
 *   - **Q_INVOKABLE 接口**:暴露给 QML,允许 QML 侧读取 stats 监控丢帧率。
 *
 * 局限(子任务 3 解决):
 *   - 当前无 PeerConnection 接入,frames 通过 injectTestFrame() 仅用于测试桩与 QML 调试。
 *
 * 验收(本子任务):test_webrtc_framebuffer.cpp --6 TEST_F PASS。
 *   真实 SDP/ICE/H264 在子任务 3 由 libdatachannel + FFmpeg 完成。
 */
class WebRtcRendererItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)
    Q_PROPERTY(int totalProduced READ totalProduced NOTIFY statsChanged)
    Q_PROPERTY(int totalConsumed READ totalConsumed NOTIFY statsChanged)
    Q_PROPERTY(int totalDropped READ totalDropped NOTIFY statsChanged)

public:
    explicit WebRtcRendererItem(QQuickItem* parent = nullptr);
    ~WebRtcRendererItem() override;

    /// 注入测试桩(Q_INVOKABLE,QML 调试用;子任务 3 删)
    Q_INVOKABLE void injectTestFrame(int width, int height, int sequence);

    /// QML 设置 URL(setEnabled + requestWebRtcUrl 链路后续接入)
    Q_INVOKABLE void setStreamUrl(const QString& url);

    /// 渲染骨架入口(createRenderer 自定义)
    /// 注意:嵌套类名 Renderer 与基类 QQuickFramebufferObject::Renderer 同名,
    ///       必须用完全限定名作为返回类型,否则 override 检查不通过。
    class Renderer;
    QQuickFramebufferObject::Renderer* createRenderer() const override;

    // Property getters
    QSize sourceSize() const;
    int totalProduced() const;
    int totalConsumed() const;
    int totalDropped() const;

    /// 暴露给测试桩以直接 pushFrame
    WebRtcFrameSink* frameSink() { return m_sink.get(); }

signals:
    void sourceSizeChanged();
    void statsChanged();

private:
    std::unique_ptr<WebRtcFrameSink> m_sink;
};

/**
 * @brief Renderer
 *
 * QtQuick 自管理线程上的渲染器。当 FBO 需要重新绘制时调用 render()。
 * 这里实现一次性 QPainter::drawImage,把 WebRtcFrameSink 中的最新帧贴到 FBO。
 *
 * 与 QQuickFramebufferObject::Renderer 关系:
 *   - Qt 会在专用线程(RenderThread)上创建 Renderer 实例。
 *   - 每个 Renderer 实例对应一个 FBO,该 FBO 由 Qt Quick 主合成器采样。
 *   - 多线程安全:由 Qt Quick 通过信号控制 render() 的调用节流(vsync 60Hz / 30Hz)。
 */
class WebRtcRendererItem::Renderer : public QQuickFramebufferObject::Renderer {
public:
    Renderer();
    ~Renderer() override;

    /// 每帧调用(Qt 内部 vsync 同步)
    /// render() 必须在 RenderThread 上短暂执行,Qt Quick 会保证不会与合成线程同时访问
    void render() override;

    /// 首次创建 / 尺寸变更时调用,FBO texture 由 Qt 分配
    QOpenGLFramebufferObject* createFramebufferObject(const QSize& size) override;

    /// 同步 FBO 渲染线程看到的源尺寸(主线程 → 渲染线程)
    void synchronize(QQuickFramebufferObject* item) override;

private:
    QImage m_image;
    QSize m_source_size;
};
