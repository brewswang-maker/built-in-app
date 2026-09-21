// =============================================================================
// [S3-3/S3-4 2026-09-20] WebRtcRendererItem — QQuickPaintedItem 软渲染实现
//
// 渲染链路: WebRtcClient(libdatachannel+FFmpeg 软解) → WebRtcFrameSink(SPSC)
//           → paint() swapFrameForRender + drawImage → Qt Quick 软渲染合成
//
// 线程模型:
//   - 解码在 libdatachannel 回调线程; sink 为 lock-free 单生产/单消费
//   - paint/update/QTimer 均在 GUI 线程(软渲染后端即 GUI 线程渲染)
// =============================================================================

#include "WebRtcRenderer.h"

#include <QDebug>
#include <QPainter>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
#include "WebRtcClient.h"
#endif

namespace {
// 渲染轮询间隔: 30fps(软渲染设备上限; 低于解码帧率不影响取帧, 只丢显示帧)
constexpr int kRepaintIntervalMs = 33;
} // namespace

WebRtcRendererItem::WebRtcRendererItem(QQuickItem* parent)
    : QQuickPaintedItem(parent),
      m_sink(std::make_unique<WebRtcFrameSink>(QSize(1280, 720))) {
    // 视频贴图无需抗锯齿放大(省 CPU); QQuickPaintedItem 默认软渲染目标 Image,
    // 兼容 56mf 软渲染后端(GL 不可用)。
    setAntialiasing(false);
    setOpaquePainting(false);

    m_repaint_timer = new QTimer(this);
    m_repaint_timer->setInterval(kRepaintIntervalMs);
    connect(m_repaint_timer, &QTimer::timeout, this, [this]() {
        update(); // 触发 paint(): 取 sink 最新帧
        const uint64_t produced = totalProduced();
        if (produced != m_last_emitted_produced) {
            m_last_emitted_produced = produced;
            emit statsChanged(); // QML stats 标签(节流到帧数变化时)
        }
    });

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    m_client = new WebRtcClient(this);
    m_client->setFrameSink(m_sink.get());

    connect(m_client, &WebRtcClient::firstFrameDecoded, this, [this]() {
        qDebug() << "[WebRtcRendererItem] first frame decoded"
                 << "(sink P:" << totalProduced() << ")";
        ensureRepaintTimer(true);
        emit firstFrameRendered();
    });
    connect(m_client, &WebRtcClient::stateChanged, this,
            [this](WebRtcClient::State s) {
                qDebug() << "[WebRtcRendererItem] client state ->" << static_cast<int>(s);
                emit statsChanged();
            });
    connect(m_client, &WebRtcClient::errorOccurred, this, [this](const QString& msg) {
        qWarning() << "[WebRtcRendererItem] client error:" << msg;
        emit streamFailed(msg);
    });
    connect(m_client, &WebRtcClient::decodeError, this, [this](uint64_t consecutive) {
        qWarning() << "[WebRtcRendererItem] decode errors consecutive:"
                   << static_cast<qulonglong>(consecutive);
    });
#endif
}

WebRtcRendererItem::~WebRtcRendererItem() {
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    // 先停收流(join 解码回调), 再释放 sink(m_client 是 QObject 子对象,
    // 若只等 QObject 析构会晚于 m_sink 成员释放 → 必须在此显式 stop)
    if (m_client) m_client->stop();
#endif
    if (m_repaint_timer) m_repaint_timer->stop();
}

void WebRtcRendererItem::injectTestFrame(int width, int height, int sequence) {
    if (!m_sink) return;
    if (width <= 0) width = m_sink->expectedSize().width();
    if (height <= 0) height = m_sink->expectedSize().height();

    QImage frame(width, height, QImage::Format_RGBA8888);
    // 生成测试 pattern: 渐变色 + 序列号
    for (int y = 0; y < height; ++y) {
        uint8_t* row = frame.scanLine(y);
        for (int x = 0; x < width; ++x) {
            row[x * 4 + 0] = static_cast<uint8_t>((x + sequence) & 0xFF); // R
            row[x * 4 + 1] = static_cast<uint8_t>((y + sequence) & 0xFF); // G
            row[x * 4 + 2] = static_cast<uint8_t>(((x + y) / 2) & 0xFF);   // B
            row[x * 4 + 3] = 0xFF;                                         // A
        }
    }

    m_sink->pushFrame(frame.constBits(), static_cast<uint32_t>(width),
                      static_cast<uint32_t>(height),
                      static_cast<uint32_t>(frame.bytesPerLine()),
                      WebRtcFrameSink::PixelFormat::RGBA8888,
                      reinterpret_cast<uint64_t>(QThread::currentThreadId()) & 0xFFFFFFFFFFULL);

    update(); // 单帧注入 → 立即重绘一次
    emit statsChanged();
}

void WebRtcRendererItem::setStreamUrl(const QString& url) {
    if (url == m_stream_url) return; // 同 URL 不重启
    m_stream_url = url;

    if (url.isEmpty()) {
        stopStream();
        return;
    }
    parseAndStart(url);
}

void WebRtcRendererItem::parseAndStart(const QString& url) {
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    const QUrl parsed(url);
    const QString scheme = parsed.scheme().toLower();
    // 后端 webrtc_url 形如 webrtc://host:port/index/api/webrtc?app=live&stream=<id>
    if (scheme != QStringLiteral("webrtc") && scheme != QStringLiteral("http")
        && scheme != QStringLiteral("https")) {
        qWarning() << "[WebRtcRendererItem] 不支持的 URL 方案:" << url;
        emit streamFailed(QStringLiteral("unsupported scheme: %1").arg(scheme));
        return;
    }
    if (parsed.host().isEmpty()) {
        qWarning() << "[WebRtcRendererItem] URL 缺少主机名:" << url;
        emit streamFailed(QStringLiteral("malformed url (no host)"));
        return;
    }

    WebRtcClient::Config cfg;
    cfg.signaling_host = parsed.host();
    // 未显式端口时用设备实测的 ZLM HTTP API 端口 9080
    cfg.signaling_port = static_cast<quint16>(parsed.port(9080));
    const QUrlQuery query(parsed);
    cfg.app = query.queryItemValue(QStringLiteral("app"));
    if (cfg.app.isEmpty()) cfg.app = QStringLiteral("rtp");
    cfg.stream = query.queryItemValue(QStringLiteral("stream"));
    if (cfg.stream.isEmpty()) {
        // 兼容 path 形式 .../live/<id>
        QStringList segs = parsed.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
        if (!segs.isEmpty()) cfg.stream = segs.last();
    }
    if (cfg.stream.isEmpty()) {
        qWarning() << "[WebRtcRendererItem] URL 缺少 stream 参数:" << url;
        emit streamFailed(QStringLiteral("malformed url (no stream)"));
        return;
    }

    qDebug() << "[WebRtcRendererItem] start WebRTC:" << cfg.signaling_host
             << cfg.signaling_port << cfg.app << cfg.stream;
    if (m_client) m_client->start(cfg);
    ensureRepaintTimer(true);
#else
    qWarning() << "[WebRtcRendererItem] WebRTC 客户端未编译(ENABLE_WEBRTC_CLIENT=OFF), 忽略:"
               << url;
    emit streamFailed(QStringLiteral("WebRTC client not compiled (ENABLE_WEBRTC_CLIENT=OFF)"));
#endif
}

void WebRtcRendererItem::stopStream() {
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    if (m_client) m_client->stop();
#endif
    ensureRepaintTimer(false);
}

bool WebRtcRendererItem::requestKeyframe() {
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    return m_client ? m_client->requestKeyframe() : false;
#else
    return false;
#endif
}

void WebRtcRendererItem::ensureRepaintTimer(bool start) {
    if (!m_repaint_timer) return;
    if (start && !m_repaint_timer->isActive()) m_repaint_timer->start();
    else if (!start && m_repaint_timer->isActive()) m_repaint_timer->stop();
}

// ───────────────────── paint(软渲染消费端) ─────────────────────

void WebRtcRendererItem::paint(QPainter* painter) {
    if (!painter || !m_sink) return;

    // 取最新帧(无新帧时沿用上次 m_image, 避免重绘闪黑)
    QImage frame;
    if (m_sink->swapFrameForRender(frame)) {
        m_image = std::move(frame);
        if (m_image.size() != m_last_frame_size) {
            m_last_frame_size = m_image.size();
            emit sourceSizeChanged();
        }
    }
    if (m_image.isNull()) return;

    // 等比缩放 + 居中 letterbox
    const QRectF bounds = boundingRect();
    const QSizeF scaled = QSizeF(m_image.size()).scaled(bounds.size(), Qt::KeepAspectRatio);
    const QRectF target(QPointF(bounds.x() + (bounds.width() - scaled.width()) / 2.0,
                                bounds.y() + (bounds.height() - scaled.height()) / 2.0),
                        scaled);
    painter->setRenderHint(QPainter::SmoothPixmapTransform, false); // 视频缩放省 CPU
    painter->drawImage(target, m_image);
}

// ───────────────────── stats/property getters ─────────────────────

QSize WebRtcRendererItem::sourceSize() const {
    if (m_last_frame_size.isValid()) return m_last_frame_size;
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

int WebRtcRendererItem::totalDecoded() const {
#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT
    if (m_client) return static_cast<int>(m_client->stats().frames_decoded);
#endif
    return 0;
}
