#include "WebRtcRenderer.h"

#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QOpenGLContext>
#include <QPainter>   // 多余但兼容头
#include <QQuickWindow>
#include <QThread>
#include <cstring>

// ───────────────────── WebRtcRendererItem ─────────────────────

WebRtcRendererItem::WebRtcRendererItem(QQuickItem* parent)
    : QQuickFramebufferObject(parent),
      m_sink(std::make_unique<WebRtcFrameSink>(QSize(1280, 720))) {
    // stats 周期性推送(QML 监控)
    connect(this, &WebRtcRendererItem::statsChanged, this,
            &WebRtcRendererItem::statsChanged);
}

WebRtcRendererItem::~WebRtcRendererItem() = default;

void WebRtcRendererItem::injectTestFrame(int width, int height, int sequence) {
    if (!m_sink) return;
    if (width <= 0) width = m_sink->expectedSize().width();
    if (height <= 0) height = m_sink->expectedSize().height();

    const int bpp = 4;  // RGBA8888
    QImage frame(width, height, QImage::Format_RGBA8888);
    // 生成测试 pattern:渐变色 + 序列号文字
    for (int y = 0; y < height; ++y) {
        uint8_t* row = frame.scanLine(y);
        for (int x = 0; x < width; ++x) {
            row[x * 4 + 0] = static_cast<uint8_t>((x + sequence) & 0xFF);  // R
            row[x * 4 + 1] = static_cast<uint8_t>((y + sequence) & 0xFF);  // G
            row[x * 4 + 2] = static_cast<uint8_t>(((x + y) / 2) & 0xFF);    // B
            row[x * 4 + 3] = 0xFF;                                          // A
        }
    }

    int64_t dropped = m_sink->pushFrame(
        frame.constBits(),
        static_cast<uint32_t>(width),
        static_cast<uint32_t>(height),
        static_cast<uint32_t>(frame.bytesPerLine()),
        WebRtcFrameSink::PixelFormat::RGBA8888,
        reinterpret_cast<uint64_t>(QThread::currentThreadId()) & 0xFFFFFFFFFFULL);

    if (dropped > 0) {
        // 静默 dropped 由 stats 监控
    }
    emit statsChanged();
}

void WebRtcRendererItem::setStreamUrl(const QString& url) {
    // 子任务 3 接入:url → PeerConnection::start(url)
    Q_UNUSED(url);
}

QQuickFramebufferObject::Renderer* WebRtcRendererItem::createRenderer() const {
    return new Renderer();
}

QSize WebRtcRendererItem::sourceSize() const {
    return m_sink ? m_sink->expectedSize() : QSize(0, 0);
}

int WebRtcRendererItem::totalProduced() const {
    return m_sink ? static_cast<int>(m_sink->stats().total_produced) : 0;
}
int WebRtcRendererItem::totalConsumed() const {
    return m_sink ? static_cast<int>(m_sink->stats().total_consumed) : 0;
}
int WebRtcRendererItem::totalDropped() const {
    return m_sink ? static_cast<int>(m_sink->stats().total_dropped) : 0;
}

// ───────────────────── WebRtcRendererItem::Renderer ─────────────────────

WebRtcRendererItem::Renderer::Renderer() = default;
WebRtcRendererItem::Renderer::~Renderer() = default;

void WebRtcRendererItem::Renderer::synchronize(
    QQuickFramebufferObject* item) {
    // 在 GUI 线程上调用。可安全访问 item 的属性。
    auto* witem = qobject_cast<WebRtcRendererItem*>(item);
    if (!witem || !witem->frameSink()) return;
    QSize new_size = witem->frameSink()->expectedSize();
    if (new_size != m_source_size) {
        m_source_size = new_size;
        // mark FBO invalid → Qt 重新 createFramebufferObject
    }
}

QOpenGLFramebufferObject* WebRtcRendererItem::Renderer::createFramebufferObject(
    const QSize& size) {
    QOpenGLFramebufferObjectFormat format;
    format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    format.setSamples(0);  // 不要 MSAA(QPainter 2D 用不到)
    return new QOpenGLFramebufferObject(size, format);
}

void WebRtcRendererItem::Renderer::render() {
    // 在 RenderThread 上调用。
    // Qt6 QQuickFramebufferObject::Renderer 的正确用法:
    //   - 不走 QPainter.begin(fbo)(fbo 不是 QPaintDevice)
    //   - 子任务 2 仅验证 FBO 创建与循环:用 OpenGL 清屏到主背景色
    //   - 子任务 3 完成后改为:从 sink 拍照 QImage → glTexImage2D 上传纹理
    //                  → GLES2.0 全屏 quad 着色器渲染
    QOpenGLFramebufferObject* fbo = framebufferObject();
    if (!fbo) return;

    QOpenGLContext* ctx = QOpenGLContext::currentContext();
    if (!ctx) return;
    QOpenGLFunctions* gl = ctx->functions();
    if (!gl) return;

    gl->glViewport(0, 0, fbo->width(), fbo->height());
    gl->glClearColor(0.08f, 0.09f, 0.12f, 1.0f);  // 深色背景 #14181F
    gl->glClear(GL_COLOR_BUFFER_BIT);
}
