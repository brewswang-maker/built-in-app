// =============================================================================
// [S3-4/S3-5/G1 2026-09-20] webrtc_render_probe — 设备端 WebRTC 端到端探针
//
// 目的: 在真机(aarch64, QT_QPA_PLATFORM=offscreen + software backend)上验证
//   WebRTC 全链路: WHEP 信令 → RTP 解包 → H264 软解 → WebRtcFrameSink
//   → QQuickPaintedItem 软渲染; 输出逐秒帧统计 + grabWindow 截图 PNG。
//
// 两种模式:
//   default(C++): QQuickWindow + WebRtcRendererItem 直接实例化
//                 (对应计划 S3-5 的 QQuickWindow::grabWindow 取证设计)
//   --qml      : QQmlApplicationEngine 加载 qrc:/probe.qml(内含真实
//                 src/qml/WebRtcView.qml), 验证 S3-4 QML 接线层可加载可播放
//
// G1(--chain): 内置 StreamingDegradationChainController(与 MediaController
//   同款组件): 断流(STALL/streamFailed) → advance(webrtc→下一协议) 日志;
//   恢复(produced 回升) → reset 日志。完整"断流→advance→恢复→reset"取证。
//   注: 探针不执行 URL 换源重播(需 QML MediaPlayer/QtMultimedia), 仅驱动
//   与 MediaController.reportProtocolFailure 相同的降级决策链并记录。
//
// 用法: webrtc_render_probe <webrtc-url> <out.png> [duration_sec] [--qml] [--chain]
// 退出码: 0=有帧+截图OK  2=超时无帧  3=截图失败  4=参数错误
// =============================================================================

#include <QGuiApplication>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>
#include <QElapsedTimer>
#include <QImage>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>
#include <cstdio>

#include "streaming/WebRtcRenderer.h"
#include "streaming/StreamingDegradationChain.h"

namespace {

struct ProbeArgs {
    QString url;
    QString outPng;
    int durationSec = 20;
    bool qmlMode = false;
    bool chainMode = false;
    bool ok = false;
};

ProbeArgs parseArgs(int argc, char* argv[]) {
    ProbeArgs a;
    QStringList positional;
    for (int i = 1; i < argc; ++i) {
        const QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == "--qml") a.qmlMode = true;
        else if (arg == "--chain") a.chainMode = true;
        else positional << arg;
    }
    if (positional.size() < 2) return a;
    a.url = positional.at(0);
    a.outPng = positional.at(1);
    if (positional.size() >= 3) {
        bool ok = false;
        const int d = positional.at(2).toInt(&ok);
        if (ok && d > 0) a.durationSec = d;
    }
    a.ok = true;
    return a;
}

// 从 webrtc URL 推导同 stream 的 FLV 兜底 URL(降级链 next 候选, ZLM HTTP 端口)
QString deriveFlvUrl(const QString& webrtcUrl) {
    const QUrl u(webrtcUrl);
    const QString stream = QUrlQuery(u).queryItemValue(QStringLiteral("stream"));
    if (stream.isEmpty()) return {};
    return QStringLiteral("http://%1:%2/rtp/%3.flv")
        .arg(u.host())
        .arg(u.port(9080))
        .arg(stream);
}

} // namespace

int main(int argc, char* argv[]) {
    // offscreen + 软渲染(56mf 无 GL): 须在 QGuiApplication 构造前设置(未显式指定时)
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");
    if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND"))
        qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    const ProbeArgs args = parseArgs(argc, argv);
    if (!args.ok) {
        std::fprintf(stderr,
            "usage: webrtc_render_probe <webrtc-url> <out.png> [duration_sec] [--qml] [--chain]\n");
        return 4;
    }

    qInfo("[probe] url=%s out=%s duration=%ds qml=%d chain=%d",
          qUtf8Printable(args.url), qUtf8Printable(args.outPng),
          args.durationSec, args.qmlMode, args.chainMode);

    // ── 降级链(G1): 与 MediaController 内部同款控制器 ──
    StreamingDegradationChainController chain;
    if (args.chainMode) {
        chain.setChain(QStringLiteral("probe-device"),
                       {QStringLiteral("webrtc"), QStringLiteral("flv"),
                        QStringLiteral("ws-flv"), QStringLiteral("hls"),
                        QStringLiteral("rtsp")});
        QVariantMap urls;
        urls.insert(QStringLiteral("webrtc"), args.url);
        const QString flv = deriveFlvUrl(args.url);
        if (!flv.isEmpty()) urls.insert(QStringLiteral("flv"), flv);
        chain.setUrls(QStringLiteral("probe-device"), urls);
        QObject::connect(&chain, &StreamingDegradationChainController::protocolFailed,
                         [](const QString& dev, const QString& failed, const QString& next) {
            qInfo("[probe][chain] protocolFailed dev=%s failed=%s next=%s",
                  qUtf8Printable(dev), qUtf8Printable(failed),
                  next.isEmpty() ? "<none>" : qUtf8Printable(next));
        });
        QObject::connect(&chain, &StreamingDegradationChainController::activeProtocolChanged,
                         [](const QString& dev, const QString& proto) {
            qInfo("[probe][chain] activeProtocol dev=%s -> %s",
                  qUtf8Printable(dev), qUtf8Printable(proto));
        });
        qInfo("[probe][chain] init chain=webrtc->flv->ws-flv->hls->rtsp active=%s",
              qUtf8Printable(chain.activeProtocol(QStringLiteral("probe-device"))));
    }

    // ── 构建窗口与渲染 item ──
    QQuickWindow* win = nullptr;
    WebRtcRendererItem* item = nullptr;
    QQmlApplicationEngine engine;

    if (args.qmlMode) {
        const int rc = qmlRegisterType<WebRtcRendererItem>("ShieldBox", 1, 0, "WebRtcRendererItem");
        Q_UNUSED(rc);
        engine.rootContext()->setContextProperty(QStringLiteral("probeUrl"), args.url);
        engine.load(QUrl(QStringLiteral("qrc:/probe.qml")));
        if (engine.rootObjects().isEmpty()) {
            qCritical("[probe] QML load failed: qrc:/probe.qml");
            return 3;
        }
        win = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
        if (win) item = win->findChild<WebRtcRendererItem*>();
        qInfo("[probe] qml mode: window=%p item=%p", static_cast<void*>(win),
              static_cast<void*>(item));
    } else {
        win = new QQuickWindow();
        win->resize(1280, 720);
        item = new WebRtcRendererItem(win->contentItem());
        item->setWidth(1280);
        item->setHeight(720);
        win->show();
    }
    if (!win || !item) {
        qCritical("[probe] window/item creation failed");
        return 3;
    }

    // ── 事件记录 ──
    QElapsedTimer since;      // setStreamUrl 起
    QElapsedTimer runClock;   // 全程
    since.start();
    runClock.start();
    bool firstFrameSeen = false;

    QObject::connect(item, &WebRtcRendererItem::firstFrameRendered, [&]() {
        firstFrameSeen = true;
        qInfo("[probe] FIRST_FRAME t=%lldms",
              static_cast<long long>(since.elapsed()));
    });
    QObject::connect(item, &WebRtcRendererItem::streamFailed,
                     [](const QString& reason) {
        qWarning("[probe] streamFailed: %s", qUtf8Printable(reason));
    });

    // ── 逐秒统计 + STALL/RECOVERY 检测 ──
    uint64_t lastProduced = 0;
    int stallSeconds = 0;
    int lastPliSecond = -100;
    bool advanced = false;

    QTimer statsTimer;
    statsTimer.setInterval(1000);
    QObject::connect(&statsTimer, &QTimer::timeout, [&]() {
        const uint64_t produced = static_cast<uint64_t>(item->totalProduced());
        const uint64_t consumed = static_cast<uint64_t>(item->totalConsumed());
        const uint64_t dropped = static_cast<uint64_t>(item->totalDropped());
        const uint64_t decoded = static_cast<uint64_t>(item->totalDecoded());
        qInfo("[probe] t=%llds Dc=%llu P=%llu C=%llu D=%llu",
              static_cast<long long>(runClock.elapsed() / 1000),
              static_cast<unsigned long long>(decoded),
              static_cast<unsigned long long>(produced),
              static_cast<unsigned long long>(consumed),
              static_cast<unsigned long long>(dropped));

        if (produced > lastProduced) {
            if (stallSeconds >= 3 && lastProduced > 0) {
                qInfo("[probe] RECOVERED after %ds stall (produced %llu -> %llu)",
                      stallSeconds, static_cast<unsigned long long>(lastProduced),
                      static_cast<unsigned long long>(produced));
                if (args.chainMode && advanced) {
                    advanced = false;
                    chain.reset(QStringLiteral("probe-device"));
                    qInfo("[probe][chain] reset -> active=%s",
                          qUtf8Printable(chain.activeProtocol(QStringLiteral("probe-device"))));
                }
            }
            stallSeconds = 0;
            lastProduced = produced;
        } else if (produced > 0 || firstFrameSeen) {
            ++stallSeconds;
            if (stallSeconds >= 3 && (stallSeconds % 3) == 0) {
                qWarning("[probe] STALL %ds (produced=%llu)",
                         stallSeconds, static_cast<unsigned long long>(produced));
                if (args.chainMode && !advanced) {
                    advanced = true;
                    qInfo("[probe][chain] 断流 -> advance(webrtc)");
                    chain.advance(QStringLiteral("probe-device"), QStringLiteral("webrtc"));
                }
            }
            // 停流期间周期 PLI: 恢复时更快等到 IDR(4s 间隔, WebRtcClient 内部亦有节流)
            const int sec = static_cast<int>(runClock.elapsed() / 1000);
            if (stallSeconds >= 1 && sec - lastPliSecond >= 4) {
                lastPliSecond = sec;
                const bool ok = item->requestKeyframe();
                qInfo("[probe] requestKeyframe -> %s", ok ? "sent" : "unavailable");
            }
        }
    });
    statsTimer.start();

    // ── 结束: 截图 + 统计落盘 ──
    int resultCode = 0;
    QTimer::singleShot(args.durationSec * 1000, [&]() {
        statsTimer.stop();
        if (args.chainMode) {
            qInfo("[probe][chain] final active=%s",
                  qUtf8Printable(chain.activeProtocol(QStringLiteral("probe-device"))));
        }
        QImage shot = win->grabWindow();
        if (shot.isNull()) {
            qCritical("[probe] grabWindow returned null image");
            resultCode = 3;
        } else if (!shot.save(args.outPng)) {
            qCritical("[probe] PNG save failed: %s", qUtf8Printable(args.outPng));
            resultCode = 3;
        } else {
            qInfo("[probe] screenshot saved: %s (%dx%d)",
                  qUtf8Printable(args.outPng), shot.width(), shot.height());
        }
        if (resultCode == 0 && item->totalProduced() == 0) {
            qCritical("[probe] no frames produced within %ds", args.durationSec);
            resultCode = 2;
        }
        std::printf("PROBE_RESULT {\"url\":\"%s\",\"decoded\":%llu,\"produced\":%llu,"
                    "\"consumed\":%llu,\"dropped\":%llu,\"ran_ms\":%lld,\"png\":\"%s\","
                    "\"rc\":%d}\n",
                    qUtf8Printable(args.url),
                    static_cast<unsigned long long>(item->totalDecoded()),
                    static_cast<unsigned long long>(item->totalProduced()),
                    static_cast<unsigned long long>(item->totalConsumed()),
                    static_cast<unsigned long long>(item->totalDropped()),
                    static_cast<long long>(runClock.elapsed()),
                    qUtf8Printable(args.outPng), resultCode);
        std::fflush(stdout);
        app.exit(resultCode);
    });

    // 硬看门狗: duration+20s 仍未退出(事件循环异常)则强制失败退出
    QTimer::singleShot((args.durationSec + 20) * 1000, [&]() {
        qCritical("[probe] watchdog fired, aborting");
        app.exit(5);
    });

    // ── 启动收流 ──
    qInfo("[probe] setStreamUrl ...");
    item->setStreamUrl(args.url);

    const int rc = app.exec();
    if (rc == 0 && resultCode != 0) return resultCode;
    return rc;
}
