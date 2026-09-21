/**
 * @file test_webrtc_client.cpp
 * @brief V4-V1 S1T6 子任务 3 (S3-2) — WebRtcClient 单测:
 *        信令协商(mock WHEP HTTP) / RTP 解包(FU-A 重组) / H264 解码(90 帧样本) /
 *        错误注入(HTTP 500 / ZLM code!=0 / 非法 answer SDP) / 停止-重启幂等
 *
 * 编译(需 ENABLE_WEBRTC_CLIENT=ON):
 *   cd clients/built-in-app && mkdir -p build-webrtc-x86 && cd build-webrtc-x86 && \
 *     cmake .. -DENABLE_WEBRTC_CLIENT=ON && make -j$(nproc) test_webrtc_client
 * 运行:
 *   QT_QPA_PLATFORM=offscreen ./tests/test_webrtc_client
 *
 * 说明:
 *   - mock WHEP 服务端(QTcpServer)按 ZLM /index/api/webrtc 契约响应:
 *     请求 body=裸 SDP offer; 响应 JSON {code,sdp,msg}
 *   - 信令测试不断言端到端媒体连通(mock 无 ICE/DTLS 对端), 只断言:
 *     请求契约正确 + answer 被应用(state→Connecting) + 错误路径 Fail
 */

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT

#include <QtTest>
#include <QSharedPointer>
#include <QTcpServer>
#include <QTcpSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QByteArray>
#include <QFile>

#include <cstring>
#include <utility>
#include <vector>

#include "streaming/WebRtcClient.h"
#include "streaming/H264Decoder.h"
#include "streaming/WebRtcFrameSink.h"

#include "rtc/rtc.hpp"

// ─────────── mock WHEP 服务端 ───────────

class MockWhepServer : public QTcpServer {
    Q_OBJECT
public:
    enum class Mode {
        OkJson,       // 200 + {"code":0,"sdp":canned}
        RawSdp,       // 200 + 裸 SDP(WHEP 变体兼容)
        Http500,      // 500
        ZlmErrorCode, // 200 + {"code":-400,"msg":"stream not found"}
        BadSdp,       // 200 + {"code":0,"sdp":"garbage"}
    };
    Mode mode = Mode::OkJson;
    QByteArray canned_answer;

    // 记录
    int request_count = 0;
    QByteArray last_request_line;
    QByteArray last_path;
    QByteArray last_query;
    QByteArray last_body;

protected:
    void incomingConnection(qintptr socketDescriptor) override {
        auto* sock = new QTcpSocket(this);
        sock->setSocketDescriptor(socketDescriptor);
        connect(sock, &QTcpSocket::disconnected, sock, &QObject::deleteLater);

        auto buf = QSharedPointer<QByteArray>::create();
        connect(sock, &QTcpSocket::readyRead, this, [this, sock, buf]() {
            buf->append(sock->readAll());
            const int hdr_end = buf->indexOf("\r\n\r\n");
            if (hdr_end < 0) return;
            const QByteArray head = buf->left(hdr_end);
            int content_len = 0;
            for (const QByteArray& line : head.split('\n')) {
                if (line.toLower().trimmed().startsWith("content-length:"))
                    content_len = line.mid(line.indexOf(':') + 1).trimmed().toInt();
            }
            if (buf->size() < hdr_end + 4 + content_len) return; // 未收全

            const QByteArray request_line = head.split('\n').first().trimmed();
            const int sp1 = request_line.indexOf(' ');
            const int sp2 = request_line.indexOf(' ', sp1 + 1);
            last_request_line = request_line.left(sp1);
            const QByteArray path_query = request_line.mid(sp1 + 1, sp2 - sp1 - 1);
            const int qpos = path_query.indexOf('?');
            last_path = qpos >= 0 ? path_query.left(qpos) : path_query;
            last_query = qpos >= 0 ? path_query.mid(qpos + 1) : QByteArray();
            last_body = buf->mid(hdr_end + 4, content_len);
            ++request_count;

            sock->write(buildResponse());
            sock->flush();
            sock->disconnectFromHost();
        });
    }

private:
    QByteArray buildResponse() const {
        int status = 200;
        QByteArray body;
        switch (mode) {
        case Mode::Http500:
            status = 500;
            body = QByteArrayLiteral("{\"code\":-500,\"msg\":\"internal error\"}");
            break;
        case Mode::ZlmErrorCode:
            body = QByteArrayLiteral("{\"code\":-400,\"msg\":\"stream not found\"}");
            break;
        case Mode::BadSdp:
            body = QByteArrayLiteral("{\"code\":0,\"type\":\"answer\",\"sdp\":\"this is not a valid sdp\"}");
            break;
        case Mode::RawSdp:
            body = canned_answer;
            break;
        case Mode::OkJson:
        default: {
            QJsonObject obj;
            obj.insert(QStringLiteral("code"), 0);
            obj.insert(QStringLiteral("type"), QStringLiteral("answer"));
            obj.insert(QStringLiteral("sdp"), QString::fromUtf8(canned_answer));
            obj.insert(QStringLiteral("id"), QStringLiteral("mock"));
            body = QJsonDocument(obj).toJson(QJsonDocument::Compact);
            break;
        }
        }
        QByteArray resp = "HTTP/1.1 " + QByteArray::number(status) + " X\r\n";
        resp += "Content-Type: application/json\r\n";
        resp += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
        resp += "Connection: close\r\n\r\n";
        resp += body;
        return resp;
    }
};

// 合法 answer SDP(结构与 ZLM 实测 answer 同构: mid=video / PT 102 / ssrc=1 /
// a=setup:active; 供 libdatachannel setRemoteDescription 解析)
static QByteArray makeCannedAnswer() {
    const char* sdp =
        "v=0\r\n"
        "o=- 1234567890 2 IN IP4 127.0.0.1\r\n"
        "s=mock-zlm\r\n"
        "t=0 0\r\n"
        "a=group:BUNDLE video\r\n"
        "a=msid-semantic: WMS mock\r\n"
        "m=video 9 UDP/TLS/RTP/SAVPF 102\r\n"
        "c=IN IP4 0.0.0.0\r\n"
        "a=rtcp:9 IN IP4 0.0.0.0\r\n"
        "a=ice-ufrag:mockufrag\r\n"
        "a=ice-pwd:mockpwd1234567890abcdef\r\n"
        "a=ice-options:trickle\r\n"
        "a=fingerprint:sha-256 "
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:"
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99\r\n"
        "a=setup:active\r\n"
        "a=mid:video\r\n"
        "a=sendonly\r\n"
        "a=msid:mock stream\r\n"
        "a=rtcp-mux\r\n"
        "a=rtpmap:102 H264/90000\r\n"
        "a=fmtp:102 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\n"
        "a=ssrc:1 cname:mock\r\n"
        "a=ssrc:1 msid:mock stream\r\n";
    return QByteArray(sdp);
}

// ─────────── 测试类 ───────────

class TestWebRtcClient : public QObject {
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    /// 1. 信令协商: offer 契约 + answer 应用 → Connecting, 无错误
    void test_signaling_roundtrip_mock();
    /// 2. 错误注入: HTTP 500 → Failed + errorOccurred
    void test_signaling_http_500();
    /// 3. 错误注入: ZLM code=-400 → Failed + msg 透传
    void test_signaling_zlm_error_code();
    /// 4. 错误注入: 非法 answer SDP → Failed
    void test_signaling_bad_answer_sdp();
    /// 5. 解包: FU-A 两段重组为完整 Annex-B NAL
    void test_depacketizer_fua_reassembly();
    /// 6. 解包: 单 NAL 包直通(带起始码)
    void test_depacketizer_single_nal_passthrough();
    /// 7. 解码: 90 帧 Annex-B 样本 → ≥80 帧解码并推入 sink
    void test_decoder_decodes_annexb_file();
    /// 8. 解码容错: 坏输入不崩溃, 合法流可恢复
    void test_decoder_error_injection_recovers();
    /// 9. 停止/重启: 幂等, 第二次 start 重新发起信令
    void test_stop_restart();

private:
    WebRtcClient* m_client = nullptr;
    MockWhepServer* m_mock = nullptr;

    WebRtcClient::Config config() const;
    QByteArray load_h264_sample() const;
};

void TestWebRtcClient::init() {
    m_mock = new MockWhepServer;
    QVERIFY(m_mock->listen(QHostAddress::LocalHost, 0));
    m_mock->canned_answer = makeCannedAnswer();
    m_client = new WebRtcClient;
    m_client->setFrameSink(new WebRtcFrameSink(QSize(1280, 720))); // 泄漏至进程结束(测试简化)
}

void TestWebRtcClient::cleanup() {
    if (m_client) {
        m_client->stop();
        delete m_client;
        m_client = nullptr;
    }
    if (m_mock) {
        m_mock->close();
        delete m_mock;
        m_mock = nullptr;
    }
}

WebRtcClient::Config TestWebRtcClient::config() const {
    WebRtcClient::Config cfg;
    cfg.signaling_host = QStringLiteral("127.0.0.1");
    cfg.signaling_port = static_cast<quint16>(m_mock->serverPort());
    cfg.app = QStringLiteral("rtp");
    cfg.stream = QStringLiteral("gb_test");
    cfg.gather_timeout_ms = 5000;
    cfg.signaling_timeout_ms = 5000;
    return cfg;
}

QByteArray TestWebRtcClient::load_h264_sample() const {
    QFile f(QStringLiteral(SHIELDBOX_TEST_DATA_DIR) + QStringLiteral("/h264_90f.h264"));
    if (!f.open(QIODevice::ReadOnly)) return QByteArray();
    return f.readAll();
}

// ─────────── 1. 信令协商 ───────────

void TestWebRtcClient::test_signaling_roundtrip_mock() {
    QSignalSpy errSpy(m_client, &WebRtcClient::errorOccurred);
    m_client->start(config());

    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Connecting, 10000);

    // mock 侧请求契约
    QCOMPARE(m_mock->request_count, 1);
    QCOMPARE(m_mock->last_request_line, QByteArrayLiteral("POST"));
    QCOMPARE(m_mock->last_path, QByteArrayLiteral("/index/api/webrtc"));
    QVERIFY(m_mock->last_query.contains("app=rtp"));
    QVERIFY(m_mock->last_query.contains("stream=gb_test"));
    QVERIFY(m_mock->last_query.contains("type=play"));
    // offer 内容: mid=video + H264 PT 102 + 候选(非 trickle, gather 完成才发)
    QVERIFY(m_mock->last_body.contains("m=video"));
    QVERIFY(m_mock->last_body.contains("a=rtpmap:102 H264/90000"));
    QVERIFY(m_mock->last_body.contains("a=recvonly"));
    QVERIFY(m_mock->last_body.contains("a=candidate:"));

    QCOMPARE(errSpy.count(), 0);
    qDebug() << "[PASS] test_signaling_roundtrip_mock: state=" << m_client->state()
             << "offer_bytes=" << m_mock->last_body.size();
}

// ─────────── 2/3/4. 错误注入 ───────────

void TestWebRtcClient::test_signaling_http_500() {
    m_mock->mode = MockWhepServer::Mode::Http500;
    QSignalSpy errSpy(m_client, &WebRtcClient::errorOccurred);
    m_client->start(config());

    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Failed, 10000);
    QCOMPARE(errSpy.count(), 1);
    QVERIFY2(m_client->lastError().contains("500"), qPrintable(m_client->lastError()));
    QVERIFY(!m_client->lastError().isEmpty());
    qDebug() << "[PASS] test_signaling_http_500:" << m_client->lastError();
}

void TestWebRtcClient::test_signaling_zlm_error_code() {
    m_mock->mode = MockWhepServer::Mode::ZlmErrorCode;
    QSignalSpy errSpy(m_client, &WebRtcClient::errorOccurred);
    m_client->start(config());

    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Failed, 10000);
    QCOMPARE(errSpy.count(), 1);
    QVERIFY2(m_client->lastError().contains("stream not found"),
             qPrintable(m_client->lastError()));
    qDebug() << "[PASS] test_signaling_zlm_error_code:" << m_client->lastError();
}

void TestWebRtcClient::test_signaling_bad_answer_sdp() {
    m_mock->mode = MockWhepServer::Mode::BadSdp;
    QSignalSpy errSpy(m_client, &WebRtcClient::errorOccurred);
    m_client->start(config());

    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Failed, 10000);
    QCOMPARE(errSpy.count(), 1);
    QVERIFY(!m_client->lastError().isEmpty());
    qDebug() << "[PASS] test_signaling_bad_answer_sdp:" << m_client->lastError();
}

// ─────────── 5/6. RTP 解包 ───────────

namespace {
// 构造 RTP 包: 12 字节头 + payload(rtc::binary = vector<byte>)
rtc::binary buildRtpPacket(uint16_t seq, uint32_t ts, uint32_t ssrc, uint8_t pt, bool marker,
                           const std::vector<uint8_t>& payload) {
    rtc::binary pkt(12 + payload.size());
    auto* p = reinterpret_cast<uint8_t*>(pkt.data());
    p[0] = 0x80; // V=2
    p[1] = static_cast<uint8_t>((marker ? 0x80 : 0x00) | (pt & 0x7F));
    p[2] = static_cast<uint8_t>(seq >> 8);
    p[3] = static_cast<uint8_t>(seq & 0xFF);
    p[4] = static_cast<uint8_t>(ts >> 24);
    p[5] = static_cast<uint8_t>(ts >> 16);
    p[6] = static_cast<uint8_t>(ts >> 8);
    p[7] = static_cast<uint8_t>(ts & 0xFF);
    p[8] = static_cast<uint8_t>(ssrc >> 24);
    p[9] = static_cast<uint8_t>(ssrc >> 16);
    p[10] = static_cast<uint8_t>(ssrc >> 8);
    p[11] = static_cast<uint8_t>(ssrc & 0xFF);
    std::memcpy(p + 12, payload.data(), payload.size());
    return pkt;
}
} // namespace

void TestWebRtcClient::test_depacketizer_fua_reassembly() {
    auto depack = std::make_shared<rtc::H264RtpDepacketizer>();

    const uint8_t kPt = 102, kNalHeader = 0x65; // IDR
    const uint32_t kTs = 90000, kSsrc = 0x11223344;
    const std::vector<uint8_t> payload(2000, 0xAB);

    // FU-A 两段: indicator=0x7C(NRI=3|28), header: 0x85=S+type5 / 0x45=E+type5
    std::vector<uint8_t> fu1 = {0x7C, 0x85};
    fu1.insert(fu1.end(), payload.begin(), payload.begin() + 1000);
    std::vector<uint8_t> fu2 = {0x7C, 0x45};
    fu2.insert(fu2.end(), payload.begin() + 1000, payload.end());

    rtc::message_vector msgs;
    msgs.push_back(rtc::make_message(buildRtpPacket(1, kTs, kSsrc, kPt, false, fu1),
                                     rtc::Message::Binary));
    msgs.push_back(rtc::make_message(buildRtpPacket(2, kTs, kSsrc, kPt, true, fu2),
                                     rtc::Message::Binary));

    rtc::message_callback send = [](rtc::message_ptr) {};
    // incoming() 在 VideoRtpDepacketizer 中为 private, 公开入口是 incomingChain
    depack->incomingChain(msgs, send);

    QCOMPARE(msgs.size(), size_t(1)); // 重组成 1 帧
    const auto& frame = *msgs[0];
    QCOMPARE(frame.size(), size_t(4 + 1 + 2000)); // 起始码 + NAL 头 + 负载
    auto byte_at = [&frame](size_t i) { return static_cast<uint8_t>(frame[i]); };
    QCOMPARE(byte_at(0), uint8_t(0x00));
    QCOMPARE(byte_at(1), uint8_t(0x00));
    QCOMPARE(byte_at(2), uint8_t(0x00));
    QCOMPARE(byte_at(3), uint8_t(0x01));
    QCOMPARE(byte_at(4), kNalHeader);
    for (size_t i = 0; i < payload.size(); ++i) {
        if (byte_at(5 + i) != payload[i]) {
            QFAIL(qPrintable(QStringLiteral("负载字节不一致 @%1").arg(i)));
        }
    }
    qDebug() << "[PASS] test_depacketizer_fua_reassembly: frame_bytes=" << int(frame.size());
}

void TestWebRtcClient::test_depacketizer_single_nal_passthrough() {
    auto depack = std::make_shared<rtc::H264RtpDepacketizer>();

    const uint8_t kPt = 102, kNalHeader = 0x41; // 非 IDR 片
    std::vector<uint8_t> payload = {kNalHeader};
    payload.resize(101, 0xCD);

    rtc::message_vector msgs;
    msgs.push_back(rtc::make_message(buildRtpPacket(10, 12345, 1, kPt, true, payload),
                                     rtc::Message::Binary));

    rtc::message_callback send = [](rtc::message_ptr) {};
    depack->incomingChain(msgs, send);

    QCOMPARE(msgs.size(), size_t(1));
    const auto& frame = *msgs[0];
    QCOMPARE(frame.size(), size_t(4 + payload.size()));
    QCOMPARE(static_cast<uint8_t>(frame[3]), uint8_t(0x01));
    QCOMPARE(static_cast<uint8_t>(frame[4]), kNalHeader);
    qDebug() << "[PASS] test_depacketizer_single_nal_passthrough";
}

// ─────────── 7/8. H264 解码 ───────────

void TestWebRtcClient::test_decoder_decodes_annexb_file() {
    const QByteArray bytes = load_h264_sample();
    QVERIFY2(bytes.size() > 10000, "h264_90f.h264 缺失(用 tests/data/avcc_to_annexb.py 生成)");

    auto* sink = new WebRtcFrameSink(QSize(1280, 720));
    H264Decoder decoder;
    decoder.setFrameSink(sink);
    QVERIFY(decoder.open());

    // 扫描 4 字节起始码切 NAL, 逐个送入(解码器内部按 AU 聚合输出)
    const auto* d = reinterpret_cast<const uint8_t*>(bytes.constData());
    const int n = bytes.size();
    std::vector<std::pair<int, int>> nals;
    for (int p = 0; p + 3 < n; ++p) {
        if (d[p] == 0 && d[p + 1] == 0 && d[p + 2] == 0 && d[p + 3] == 1) {
            if (!nals.empty()) nals.back().second = p;
            nals.push_back({p, n});
            p += 3;
        }
    }
    QVERIFY(nals.size() >= 85);

    int fed = 0;
    for (const auto& [start, end] : nals) {
        decoder.decodeAnnexB(d + start, static_cast<size_t>(end - start),
                             1000 + static_cast<uint64_t>(fed));
        ++fed;
    }

    const auto ds = decoder.stats();
    QCOMPARE(static_cast<int>(ds.packets_in), fed);
    QVERIFY2(ds.frames_out >= 80, qPrintable(QStringLiteral("frames_out=%1").arg(ds.frames_out)));
    QCOMPARE(ds.sink_pushes, ds.frames_out);

    const auto ss = sink->stats();
    QCOMPARE(ss.total_produced, ds.frames_out);
    QVERIFY(decoder.lastFrameSize().width() > 0);
    QVERIFY(decoder.lastFrameSize().height() > 0);

    qDebug() << "[PASS] test_decoder_decodes_annexb_file: nals=" << fed
             << "frames_out=" << ds.frames_out << "size=" << decoder.lastFrameSize();

    delete sink;
}

void TestWebRtcClient::test_decoder_error_injection_recovers() {
    auto* sink = new WebRtcFrameSink(QSize(1280, 720));
    H264Decoder decoder;
    decoder.setFrameSink(sink);
    QVERIFY(decoder.open());

    // 坏输入(无起始码的垃圾): 不得崩溃, 不产出帧
    std::vector<uint8_t> junk(512, 0x12);
    const int r = decoder.decodeAnnexB(junk.data(), junk.size(), 0);
    QVERIFY2(r <= 0, qPrintable(QStringLiteral("junk produced=%1").arg(r)));
    QCOMPARE(decoder.stats().frames_out, uint64_t(0));

    // 恢复: 送合法样本 → 正常解码
    const QByteArray bytes = load_h264_sample();
    QVERIFY(bytes.size() > 10000);
    const auto* d = reinterpret_cast<const uint8_t*>(bytes.constData());
    const int n = bytes.size();
    std::vector<std::pair<int, int>> nals;
    for (int p = 0; p + 3 < n; ++p) {
        if (d[p] == 0 && d[p + 1] == 0 && d[p + 2] == 0 && d[p + 3] == 1) {
            if (!nals.empty()) nals.back().second = p;
            nals.push_back({p, n});
            p += 3;
        }
    }
    for (const auto& [start, end] : nals)
        decoder.decodeAnnexB(d + start, static_cast<size_t>(end - start), 2000);

    QVERIFY2(decoder.stats().frames_out >= 80,
             qPrintable(QStringLiteral("recover frames_out=%1").arg(decoder.stats().frames_out)));
    qDebug() << "[PASS] test_decoder_error_injection_recovers: frames_out="
             << decoder.stats().frames_out;

    delete sink;
}

// ─────────── 9. 停止/重启 ───────────

void TestWebRtcClient::test_stop_restart() {
    m_client->start(config());
    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Connecting, 10000);

    m_client->stop();
    QCOMPARE(m_client->state(), WebRtcClient::State::Idle);

    const int first_count = m_mock->request_count;
    m_client->start(config());
    QTRY_VERIFY_WITH_TIMEOUT(m_mock->request_count > first_count, 10000);
    QTRY_VERIFY_WITH_TIMEOUT(
        m_client->state() == WebRtcClient::State::Connecting, 10000);

    m_client->stop();
    QCOMPARE(m_client->state(), WebRtcClient::State::Idle);
    qDebug() << "[PASS] test_stop_restart: requests=" << m_mock->request_count;
}

QTEST_MAIN(TestWebRtcClient)
#include "test_webrtc_client.moc"

#endif // SHIELDBOX_ENABLE_WEBRTC_CLIENT
