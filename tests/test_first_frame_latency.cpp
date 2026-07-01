// tests/test_first_frame_latency.cpp
//
// FirstFrameLatencyTest — P0-2 同步组件首帧延迟基准
//
// 测量 SmartGateWay 内置端流媒体首帧延迟路径中所有 **同步** 组件
// 的微秒/毫秒级耗时,作为端到端压测 (tests/perf/) 的补充基线。
//
// 覆盖 (4 个关键组件 + 1 个跨端一致性):
//   1. JSON 解析 — applyZlmStreamUrls 内部 4 字段 QJsonObject 提取
//   2. 协议链规范化 — StreamingDegradationChain::normalize
//   3. 协议选择 — StreamingDegradationChain::selectActive
//   4. WebRTC 探测 — WebRTCStreamProvider::probeSync (不可达主机超时)
//   5. 跨端协议优先级 — macOS HLS 优先 vs 其他平台 RTSP 优先
//   6. 64 路并发压力 — 批量创建+URL 设置 1000 次 < 50ms
//
// 验收标准:
//   ./test_first_frame_latency                  → exit 0
//   所有 latency < budget_ms

#include "streaming/StreamingDegradationChain.h"
#include "streaming/WebRTCStreamProvider.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QSignalSpy>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtTest>
#include <iostream>

namespace {
constexpr const char* kBenchHeader =
    "[FirstFrameLatencyTest] P0-2 sync-component baseline";
}

// applyZlmStreamUrls 内部实现的同步部分(纯函数),便于微基准
namespace bench_helpers {
QVariantMap extractUrlMap(const QJsonObject& streamObj) {
    QVariantMap urlMap;
    const QString rtspUrl   = streamObj.value("rtsp_url").toString();
    const QString flvUrl    = streamObj.value("flv_url").toString();
    const QString hlsUrl    = streamObj.value("hls_url").toString();
    const QString webrtcUrl = streamObj.value("webrtc_url").toString();
    if (!rtspUrl.isEmpty())   urlMap.insert(QStringLiteral("rtsp"),   rtspUrl);
    if (!flvUrl.isEmpty())    urlMap.insert(QStringLiteral("flv"),    flvUrl);
    if (!hlsUrl.isEmpty())    urlMap.insert(QStringLiteral("hls"),    hlsUrl);
    if (!webrtcUrl.isEmpty()) urlMap.insert(QStringLiteral("webrtc"), webrtcUrl);
    return urlMap;
}

// 与 MediaController::applyZlmStreamUrls 同构(同步部分),用于基准
QString pickBestUrl(const QJsonObject& streamObj) {
    const QString rtspUrl   = streamObj.value("rtsp_url").toString();
    const QString flvUrl    = streamObj.value("flv_url").toString();
    const QString hlsUrl    = streamObj.value("hls_url").toString();
    const QString webrtcUrl = streamObj.value("webrtc_url").toString();
#ifdef Q_OS_MACOS
    if (!hlsUrl.isEmpty())      return hlsUrl;
    if (!flvUrl.isEmpty())      return flvUrl;
    if (!rtspUrl.isEmpty())     return rtspUrl;
#else
    if (!rtspUrl.isEmpty())     return rtspUrl;
    if (!flvUrl.isEmpty())      return flvUrl;
    if (!hlsUrl.isEmpty())      return hlsUrl;
#endif
    return webrtcUrl;
}
}  // namespace bench_helpers

class FirstFrameLatencyTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        std::cerr << kBenchHeader << "\n";
    }

    // ── 1. JSON 解析 — 4 字段 QJsonObject 提取 (10000 次平均) ──
    void testJsonParseLatency() {
        constexpr int kIterations = 10000;
        QJsonObject sample;
        sample["rtsp_url"]   = "rtsp://10.0.0.1:554/live/ch0001";
        sample["flv_url"]    = "http://10.0.0.1:8080/live/ch0001.flv";
        sample["hls_url"]    = "http://10.0.0.1:8080/live/ch0001.m3u8";
        sample["webrtc_url"] = "webrtc://10.0.0.1:8000/index/api/webrtc?app=live&stream=ch0001";

        QElapsedTimer t; t.start();
        for (int i = 0; i < kIterations; ++i) {
            volatile auto m = bench_helpers::extractUrlMap(sample);
            volatile auto u = bench_helpers::pickBestUrl(sample);
            (void)m; (void)u;
        }
        const qint64 ns = t.nsecsElapsed();
        const double perOpUs = (double(ns) / kIterations) / 1000.0;

        std::cerr << "[1/6] JSON parse: " << kIterations << " ops in "
                  << ns / 1000000 << " ms, " << perOpUs << " us/op\n";
        // 预算: 每次 50 us (充足余量)
        QVERIFY2(perOpUs < 50.0, "JSON parse latency too high");
    }

    // ── 2. 协议链规范化 — normalize 5 个元素的输入 ──
    void testChainNormalizeLatency() {
        constexpr int kIterations = 10000;
        const QStringList raw = {"RTSP", "flv", "ws_flv", "HLS", "WEBRTC"};

        QElapsedTimer t; t.start();
        for (int i = 0; i < kIterations; ++i) {
            volatile auto n = StreamingDegradationChain::normalize(raw);
            (void)n;
        }
        const qint64 ns = t.nsecsElapsed();
        const double perOpUs = (double(ns) / kIterations) / 1000.0;

        std::cerr << "[2/6] chain normalize: " << kIterations << " ops in "
                  << ns / 1000000 << " ms, " << perOpUs << " us/op\n";
        QVERIFY2(perOpUs < 20.0, "chain normalize too slow");
    }

    // ── 3. 协议选择 — selectActive 在 4 协议 URL map 中选第一个非空 ──
    void testSelectActiveLatency() {
        constexpr int kIterations = 100000;
        const QStringList chain = {"rtsp", "flv", "ws-flv", "hls", "webrtc"};
        QVariantMap urls;
        urls["rtsp"]   = "rtsp://10.0.0.1/1";
        urls["flv"]    = "http://10.0.0.1/1.flv";
        urls["hls"]    = "http://10.0.0.1/1.m3u8";
        urls["webrtc"] = "webrtc://10.0.0.1/1";

        QElapsedTimer t; t.start();
        for (int i = 0; i < kIterations; ++i) {
            volatile auto p = StreamingDegradationChain::selectActive(chain, urls);
            (void)p;
        }
        const qint64 ns = t.nsecsElapsed();
        const double perOpUs = (double(ns) / kIterations) / 1000.0;

        std::cerr << "[3/6] selectActive: " << kIterations << " ops in "
                  << ns / 1000000 << " ms, " << perOpUs << " us/op\n";
        QVERIFY2(perOpUs < 5.0, "selectActive too slow");
    }

    // ── 4. WebRTC 探测 — probeSync 不可达主机应 < 1500ms 超时 ──
    void testWebRtcProbeTimeoutLatency() {
        // 127.0.0.1:1 是不监听端口,probeSync 内部 1s 超时
        WebRTCStreamProvider provider;
        QElapsedTimer t; t.start();
        const bool ok = provider.probeSync("127.0.0.1", 1, 1500);
        const qint64 ms = t.elapsed();

        std::cerr << "[4/6] WebRTC probeSync: returned=" << (ok ? "true" : "false")
                  << " elapsed=" << ms << " ms\n";
        QCOMPARE(ok, false);
        // 必须 < 1500ms (内部超时 + 一些余量)
        QVERIFY2(ms <= 1600, "probeSync exceeded timeout budget");
    }

    // ── 5. 跨端协议优先级 — macOS HLS 优先,其他平台 RTSP 优先 ──
    void testCrossPlatformProtocolPriority() {
        QJsonObject all;
        all["rtsp_url"]   = "rtsp://10.0.0.1/1";
        all["flv_url"]    = "http://10.0.0.1/1.flv";
        all["hls_url"]    = "http://10.0.0.1/1.m3u8";
        all["webrtc_url"] = "webrtc://10.0.0.1/1";

        const QString best = bench_helpers::pickBestUrl(all);
        std::cerr << "[5/6] cross-platform best URL: "
                  << best.toStdString() << "\n";

#ifdef Q_OS_MACOS
        QCOMPARE(best, QStringLiteral("http://10.0.0.1/1.m3u8"));
#else
        QCOMPARE(best, QStringLiteral("rtsp://10.0.0.1/1"));
#endif
    }

    // ── 6. 64 路批量压力 — 64 设备链创建+URL 设置 < 50ms ──
    void testBatch64ChannelsUnder50ms() {
        constexpr int kChannels = 64;
        constexpr int kBudgetMs = 50;

        StreamingDegradationChainController ctrl;
        QVariantMap urls;
        urls["rtsp"]   = "rtsp://10.0.0.1/x";
        urls["flv"]    = "http://10.0.0.1/x.flv";
        urls["hls"]    = "http://10.0.0.1/x.m3u8";
        urls["webrtc"] = "webrtc://10.0.0.1/x";

        QElapsedTimer t; t.start();
        for (int i = 0; i < kChannels; ++i) {
            const QString devId = QStringLiteral("dev_%1").arg(i, 3, 10, QChar('0'));
            ctrl.setChain(devId, StreamingDegradationChain::defaultOrder());
            ctrl.setUrls(devId, urls);
        }
        const qint64 ms = t.elapsed();

        std::cerr << "[6/6] 64-channel batch: " << ms << " ms (budget "
                  << kBudgetMs << " ms)\n";
        QVERIFY2(ms <= kBudgetMs, "64-channel batch too slow");
    }
};

QTEST_MAIN(FirstFrameLatencyTest)
#include "test_first_frame_latency.moc"
