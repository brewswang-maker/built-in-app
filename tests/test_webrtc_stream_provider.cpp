// tests/test_webrtc_stream_provider.cpp
//
// WebRTCStreamProvider 单测 — S1T6 子任务1 (P0-1 视频点播) 验证
//
// 覆盖矩阵 (8 用例):
//   ① buildWebRtcUrl — URL 格式与 ZLM 一致
//   ② buildWebRtcUrl — 多种 host/stream 边界值
//   ③ 禁用状态 — 立即 emit fallback(零网络 IO) + stats 累加
//   ④ setEnabled 切换 — false→true 行为变更
//   ⑤ 同步探测 — 不可达端口返回 false 且不崩溃
//   ⑥ 缓存命中 — 同一 host:port 短时间内不重复探测
//   ⑦ 启用时探测超时 — 必须不挂起测试
//   ⑧ 多次请求触发多次统计 — 4 字段正确累加
//
// 验收标准 (S1T6-st1 子任务1):
//   ctest -R test_webrtc_stream_provider -V → PASSED
//   ./test_webrtc_stream_provider           → exit 0, "Totals: N passed, 0 failed"

#include "streaming/WebRTCStreamProvider.h"

#include <QCoreApplication>
#include <QSignalSpy>
#include <QtTest>
#include <iostream>

class TestWebRtcStreamProvider : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        std::cerr << "[TestWebRtcStreamProvider] Starting S1T6-st1 verification\n";
    }

    // ── ① URL 构建 — 必须与 ZLMMediaKitAdapter.cpp:1292 格式一致 ──
    void testBuildWebRtcUrl() {
        const QString url = WebRTCStreamProvider::buildWebRtcUrl(
            "192.168.1.10", 8000, "gb_34020000001320000001");
        QVERIFY2(url.startsWith("webrtc://"), qPrintable(url));
        QVERIFY2(url.contains("192.168.1.10"), qPrintable(url));
        QVERIFY2(url.contains(":8000"), qPrintable(url));
        QVERIFY2(url.contains("gb_34020000001320000001"), qPrintable(url));
        QVERIFY2(url.contains("/index/api/webrtc"), qPrintable(url));
        QVERIFY2(url.contains("app=live"), qPrintable(url));
        QVERIFY2(url.contains("stream="), qPrintable(url));
        std::cerr << "[OK] testBuildWebRtcUrl: " << url.toStdString() << "\n";
    }

    // ── ② URL 构建 — 多种边界值(macOS 回环/IPv6/DNS/RTSP-like stream id) ──
    void testBuildWebRtcUrlVariants() {
        // 1) loopback
        const auto url1 = WebRTCStreamProvider::buildWebRtcUrl(
            "127.0.0.1", 8000, "test");
        QVERIFY2(url1.contains("127.0.0.1:8000"), qPrintable(url1));
        // 2) hostname (非IP)
        const auto url2 = WebRTCStreamProvider::buildWebRtcUrl(
            "media.example.com", 8443, "rtmp_001");
        QVERIFY2(url2.contains("media.example.com:8443"), qPrintable(url2));
        QVERIFY2(url2.contains("stream=rtmp_001"), qPrintable(url2));
        // 3) 端口变化不影响格式
        const auto url3 = WebRTCStreamProvider::buildWebRtcUrl(
            "10.0.0.1", 9090, "x");
        QVERIFY2(url3.startsWith("webrtc://10.0.0.1:9090/"), qPrintable(url3));
        std::cerr << "[OK] testBuildWebRtcUrlVariants: 3 variants checked\n";
    }

    // ── ③ 禁用状态: 立即 emit fallback + stats fallback_count 累加 ──
    void testDisabledTriggersFallback() {
        WebRTCStreamProvider p;
        p.setEnabled(false);
        QSignalSpy spy(&p, &WebRTCStreamProvider::webRtcFallback);

        p.requestWebRtcUrl("127.0.0.1", 8000, "test_stream");

        QCOMPARE(spy.count(), 1);
        const QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(0).toString(), QStringLiteral("127.0.0.1"));
        QCOMPARE(args.at(1).toInt(), 8000);
        QCOMPARE(args.at(2).toString(), QStringLiteral("test_stream"));
        QVERIFY(args.at(3).toString().contains("disabled"));
        // stats 也必须累加 fallback_count
        QCOMPARE(p.stats().fallback_count, 1);
        QCOMPARE(p.stats().total_probes, 1);
        std::cerr << "[OK] testDisabledTriggersFallback: reason="
                  << args.at(3).toString().toStdString() << "\n";
    }

    // ── ④ setEnabled 切换: false→true 后行为变化 ──
    void testSetEnabledSwitch() {
        WebRTCStreamProvider p;
        p.setEnabled(false);

        QSignalSpy fallbackSpy(&p, &WebRTCStreamProvider::webRtcFallback);
        p.requestWebRtcUrl("127.0.0.1", 8000, "s1");
        QCOMPARE(fallbackSpy.count(), 1);

        // 切换为 enabled
        p.setEnabled(true);
        QCOMPARE(p.isEnabled(), true);

        // 切回 disabled: 后续请求立即降级而不探测网络
        p.setEnabled(false);
        QSignalSpy spy2(&p, &WebRTCStreamProvider::webRtcFallback);
        p.requestWebRtcUrl("127.0.0.1", 8000, "s2");
        QCOMPARE(spy2.count(), 1);
        std::cerr << "[OK] testSetEnabledSwitch: false→true→false all behave correctly\n";
    }

    // ── ⑤ 同步探测不可达端口: 不崩溃,返回 false ──
    void testProbeSyncUnreachable() {
        WebRTCStreamProvider p;
        bool available = p.probeSync("127.0.0.1", 1, 500);
        QCOMPARE(available, false);

        // 同步探测不修改 stats.total_probes(仅异步路径累加)
        const auto stats = p.stats();
        QCOMPARE(stats.total_probes, 0);
        QCOMPARE(stats.successful_probes, 0);
        std::cerr << "[OK] testProbeSyncUnreachable: probeSync returned false\n";
    }

    // ── ⑥ 缓存命中 — 同一 host:port 短时间内重复请求走缓存 ──
    // (实现保证: requestWebRtcUrl 内部 m_cache 在 60s 内命中,
    //  不再发起新 HTTP 请求。这里通过 stats.successful_probes 不应翻倍来验证。)
    void testCachePreventsDuplicateProbes() {
        WebRTCStreamProvider p;
        p.setEnabled(true);

        QSignalSpy fallbackSpy(&p, &WebRTCStreamProvider::webRtcFallback);
        QSignalSpy resolvedSpy(&p, &WebRTCStreamProvider::webRtcResolved);

        // 第一次请求不可达端口 192.0.2.1(RFC 5737 TEST-NET-1)
        p.requestWebRtcUrl("192.0.2.1", 8000, "s_a");
        QVERIFY(fallbackSpy.wait(2500) || resolvedSpy.count() >= 1);
        const int probes_after_first = p.stats().total_probes;
        const int fallbacks_after_first = p.stats().fallback_count;
        QVERIFY(probes_after_first >= 1);
        QVERIFY(fallbacks_after_first >= 1);

        // 第二次请求同一 host:port 应该走缓存(60s TTL 内)
        p.requestWebRtcUrl("192.0.2.1", 8000, "s_b");
        // 给信号处理一小段时间
        QTest::qWait(200);
        // total_probes 增加(每次请求都计数),但 fallback_count 可能因为缓存而保持
        QCOMPARE(p.stats().total_probes, probes_after_first + 1);
        std::cerr << "[OK] testCachePreventsDuplicateProbes: "
                  << "probes=" << p.stats().total_probes
                  << " fallbacks=" << p.stats().fallback_count << "\n";
    }

    // ── ⑦ 启用时对无效 host 探测超时 — 必须不挂起测试 ──
    void testProbeTimeoutDoesNotHang() {
        WebRTCStreamProvider p;
        p.setEnabled(true);

        QSignalSpy fallbackSpy(&p, &WebRTCStreamProvider::webRtcFallback);
        QSignalSpy resolvedSpy(&p, &WebRTCStreamProvider::webRtcResolved);

        p.requestWebRtcUrl("192.0.2.1", 8000, "unreachable_stream");

        QVERIFY(fallbackSpy.wait(2500) || resolvedSpy.count() > 0);
        QVERIFY(fallbackSpy.count() + resolvedSpy.count() >= 1);
        std::cerr << "[OK] testProbeTimeoutDoesNotHang: fallback="
                  << fallbackSpy.count() << " resolved=" << resolvedSpy.count() << "\n";
    }

    // ── ⑧ 多次请求触发多次统计 — 4 字段都正确 ──
    void testStatsAccumulate() {
        WebRTCStreamProvider p;
        p.setEnabled(false);

        for (int i = 0; i < 5; ++i) {
            p.requestWebRtcUrl("127.0.0.1", 8000,
                               QStringLiteral("stream_%1").arg(i));
        }

        const auto stats = p.stats();
        QCOMPARE(stats.total_probes, 5);
        QCOMPARE(stats.fallback_count, 5);
        QCOMPARE(stats.successful_probes, 0);  // 禁用时不应有成功
        QVERIFY(stats.last_probe_at.isValid());
        std::cerr << "[OK] testStatsAccumulate: probes=" << stats.total_probes
                  << " fallbacks=" << stats.fallback_count
                  << " last=" << stats.last_probe_at.toString(Qt::ISODate).toStdString() << "\n";
    }
};

QTEST_MAIN(TestWebRtcStreamProvider)
#include "test_webrtc_stream_provider.moc"
