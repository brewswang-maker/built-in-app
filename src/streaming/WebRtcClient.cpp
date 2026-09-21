// =============================================================================
// [S3-2 2026-09-20] WebRtcClient 实现 — libdatachannel PeerConnection +
//   WHEP 信令(ZLM /index/api/webrtc) + H264RtpDepacketizer + H264Decoder
//
// 信令时序(non-trickle):
//   start() → pc->setLocalDescription() → onGatheringStateChange(Complete)
//   → 取 localDescription() 全文 → POST offer(裸 SDP) → JSON answer
//   → setRemoteDescription(answer) → onTrack → 解包/解码 → sink
// =============================================================================

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT

#include "WebRtcClient.h"

#include "H264Decoder.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

#include "rtc/rtc.hpp"

#include <chrono>
#include <exception>
#include <mutex>

namespace {
// ZLM 默认 H264 baseline 动态 PT(实测 answer 保留客户端 offer 的 PT, 任选不冲突值)
constexpr int kH264PayloadType = 102;
// 连续解码错误阈值: 达到后请求 IDR(PLI), 并上报降级链
constexpr uint64_t kMaxConsecutiveDecodeErrors = 30;
// 自动 PLI 最小间隔(防风暴)
constexpr qint64 kKeyframeRequestMinIntervalMs = 1000;
} // namespace

WebRtcClient::WebRtcClient(QObject* parent) : QObject(parent) {
    // libdatachannel 日志: 默认 warning 及以上(避免逐包日志拖慢设备端);
    // [S3-5 2026-09-20] 诊断: SHIELDBOX_RTC_LOG=info|debug|verbose 提升等级
    static std::once_flag once;
    std::call_once(once, []() {
        const QByteArray env = qgetenv("SHIELDBOX_RTC_LOG").toLower();
        rtc::LogLevel level = rtc::LogLevel::Warning;
        if (env == "info")           level = rtc::LogLevel::Info;
        else if (env == "debug")     level = rtc::LogLevel::Debug;
        else if (env == "verbose")   level = rtc::LogLevel::Verbose;
        else if (env == "none")      level = rtc::LogLevel::None;
        rtc::InitLogger(level);
    });
}

WebRtcClient::~WebRtcClient() {
    stop();
}

void WebRtcClient::setFrameSink(WebRtcFrameSink* sink) {
    m_sink = sink;
    if (m_decoder) m_decoder->setFrameSink(sink);
}

QString WebRtcClient::signalingUrl() const {
    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_config.signaling_host);
    url.setPort(m_config.signaling_port);
    url.setPath(QStringLiteral("/index/api/webrtc"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("app"), m_config.app);
    query.addQueryItem(QStringLiteral("stream"), m_config.stream);
    query.addQueryItem(QStringLiteral("type"), QStringLiteral("play"));
    url.setQuery(query);
    return url.toString();
}

void WebRtcClient::start(const Config& config) {
    if (m_state.load(std::memory_order_relaxed) != State::Idle) stop();

    m_config = config;
    {
        std::lock_guard<std::mutex> lk(m_error_mutex);
        m_last_error.clear();
    }
    m_access_units.store(0, std::memory_order_relaxed);
    m_first_frame.store(false, std::memory_order_relaxed);
    m_consecutive_errors.store(0, std::memory_order_relaxed);
    m_last_keyframe_request_ms.store(0, std::memory_order_relaxed);

    if (!m_nam) m_nam = new QNetworkAccessManager(this);

    if (!m_decoder) m_decoder = std::make_unique<H264Decoder>();
    m_decoder->setFrameSink(m_sink);
    m_decoder->close(); // 断开期间可能残留参考帧, 重新打开
    m_decoder->open();

    const uint64_t gen = ++m_generation;
    setState(State::Gathering);

    try {
        rtc::Configuration rtc_config;
        if (!config.ice_server.isEmpty())
            rtc_config.iceServers.emplace_back(config.ice_server.toStdString());

        m_pc = std::make_shared<rtc::PeerConnection>(rtc_config);

        m_pc->onStateChange([this, gen](rtc::PeerConnection::State state) {
            if (gen != m_generation.load(std::memory_order_relaxed)) return;
            switch (state) {
            case rtc::PeerConnection::State::Connected:
                setState(State::Connected);
                break;
            case rtc::PeerConnection::State::Failed:
                fail(QStringLiteral("PeerConnection 失败(ICE/DTLS 协商不成功)"));
                break;
            default:
                break; // Disconnected/Closed 等瞬态: 由上层超时/重试策略处理
            }
        });

        // non-trickle: 等 ICE 收集完成, 一次性带全部候选发 offer
        m_pc->onGatheringStateChange([this, gen](rtc::PeerConnection::GatheringState state) {
            if (gen != m_generation.load(std::memory_order_relaxed)) return;
            if (state != rtc::PeerConnection::GatheringState::Complete) return;
            if (!m_pc) return;
            auto description = m_pc->localDescription();
            if (!description) {
                fail(QStringLiteral("本地 SDP offer 生成失败"));
                return;
            }
            const QString offer = QString::fromStdString(std::string(description.value()));
            // HTTP 信令必须在 GUI 线程(QNAM 归属线程)执行
            QMetaObject::invokeMethod(
                this,
                [this, gen, offer]() {
                    if (gen != m_generation.load(std::memory_order_relaxed)) return;
                    sendOfferHttp(offer, gen);
                },
                Qt::QueuedConnection);
        });

        m_pc->onTrack([this, gen](std::shared_ptr<rtc::Track> track) { attachTrack(track, gen); });

        rtc::Description::Video media("video", rtc::Description::Direction::RecvOnly);
        media.addH264Codec(kH264PayloadType); // profile-level-id=42e01f (Constrained Baseline 3.1)
        m_track = m_pc->addTrack(media);
        m_pc->setLocalDescription();
    } catch (const std::exception& e) {
        fail(QStringLiteral("PeerConnection 创建失败: %1").arg(QString::fromUtf8(e.what())));
        return;
    }

    QTimer::singleShot(config.gather_timeout_ms, this, [this, gen]() {
        if (gen != m_generation.load(std::memory_order_relaxed)) return;
        if (m_state.load(std::memory_order_relaxed) == State::Gathering)
            fail(QStringLiteral("ICE 收集超时(%1ms)").arg(m_config.gather_timeout_ms));
    });
}

void WebRtcClient::stop() {
    ++m_generation; // 使所有在途回调失效

    if (m_reply) {
        QNetworkReply* reply = m_reply;
        m_reply = nullptr;
        reply->abort();
        reply->deleteLater();
    }
    if (m_pc) {
        try {
            m_pc->close();
        } catch (...) {
        }
        m_pc.reset();
    }
    m_track.reset();
    m_track_attached.store(false, std::memory_order_relaxed);
    {
        // 与解码回调互斥: 确保无在途 decodeAnnexB 后再关闭 decoder
        std::lock_guard<std::mutex> lk(m_decode_mutex);
        if (m_decoder) {
            m_decoder->flush();
            m_decoder->close();
        }
    }
    m_consecutive_errors.store(0, std::memory_order_relaxed);
    setState(State::Idle);
}

bool WebRtcClient::requestKeyframe() {
    if (!m_track) return false;
    try {
        return m_track->requestKeyframe();
    } catch (...) {
        return false;
    }
}

WebRtcClient::Stats WebRtcClient::stats() const {
    Stats s;
    s.access_units = m_access_units.load(std::memory_order_relaxed);
    s.first_frame = m_first_frame.load(std::memory_order_relaxed);
    if (m_decoder) {
        auto ds = m_decoder->stats();
        s.frames_decoded = ds.frames_out;
        s.frames_pushed = ds.sink_pushes;
        s.decode_errors = ds.decode_errors;
    }
    return s;
}

QString WebRtcClient::lastError() const {
    std::lock_guard<std::mutex> lk(m_error_mutex);
    return m_last_error;
}

void WebRtcClient::setState(State s) {
    State old = m_state.exchange(s, std::memory_order_relaxed);
    if (old != s) emit stateChanged(s);
}

void WebRtcClient::fail(const QString& message) {
    {
        std::lock_guard<std::mutex> lk(m_error_mutex);
        m_last_error = message;
    }
    setState(State::Failed);
    emit errorOccurred(message);
}

void WebRtcClient::sendOfferHttp(const QString& offer_sdp, uint64_t gen) {
    if (gen != m_generation.load(std::memory_order_relaxed)) return;
    if (!m_nam) {
        fail(QStringLiteral("QNetworkAccessManager 未初始化"));
        return;
    }

    setState(State::Signalling);

    QNetworkRequest request{QUrl(signalingUrl())};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/sdp"));

    m_reply = m_nam->post(request, offer_sdp.toUtf8());
    connect(m_reply, &QNetworkReply::finished, this, [this, gen]() { handleSignalingReply(gen); });

    QTimer::singleShot(m_config.signaling_timeout_ms, this, [this, gen]() {
        if (gen != m_generation.load(std::memory_order_relaxed)) return;
        if (!m_reply) return; // 已完成
        QNetworkReply* reply = m_reply;
        m_reply = nullptr;
        reply->abort();
        reply->deleteLater();
        fail(QStringLiteral("信令超时(%1ms): %2").arg(m_config.signaling_timeout_ms).arg(signalingUrl()));
    });
}

void WebRtcClient::handleSignalingReply(uint64_t gen) {
    QNetworkReply* reply = m_reply;
    if (!reply) return; // 超时路径已接管
    m_reply = nullptr;
    reply->deleteLater();

    if (gen != m_generation.load(std::memory_order_relaxed)) return;

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();

    if (reply->error() != QNetworkReply::NoError) {
        fail(QStringLiteral("信令 HTTP 错误: %1 (status=%2)")
                 .arg(reply->errorString())
                 .arg(status));
        return;
    }
    if (status != 200) {
        fail(QStringLiteral("信令 HTTP 状态码 %1").arg(status));
        return;
    }

    // ZLM 响应为 JSON; 兼容裸 SDP 的 WHEP 变体
    const QByteArray trimmed = body.trimmed();
    QString answer;
    if (trimmed.startsWith('{')) {
        QJsonParseError perr{};
        const QJsonDocument doc = QJsonDocument::fromJson(trimmed, &perr);
        if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
            fail(QStringLiteral("信令响应 JSON 解析失败: %1").arg(perr.errorString()));
            return;
        }
        const QJsonObject obj = doc.object();
        const int code = obj.value(QStringLiteral("code")).toInt(0);
        if (code != 0) {
            fail(QStringLiteral("ZLM 信令失败 code=%1: %2")
                     .arg(code)
                     .arg(obj.value(QStringLiteral("msg")).toString()));
            return;
        }
        answer = obj.value(QStringLiteral("sdp")).toString();
    } else {
        answer = QString::fromUtf8(trimmed);
    }

    if (answer.trimmed().isEmpty()) {
        fail(QStringLiteral("信令响应缺少 sdp 字段"));
        return;
    }
    // [S3-5 2026-09-20] 诊断: SHIELDBOX_WHEP_DUMP_SDP=1 时打印 answer SDP(前 4000 字符)
    if (!qEnvironmentVariableIsEmpty("SHIELDBOX_WHEP_DUMP_SDP")) {
        qDebug().noquote() << "[WebRtcClient] WHEP answer SDP:\n" << answer.left(4000);
    }
    applyAnswer(answer, gen);
}

void WebRtcClient::applyAnswer(const QString& answer_sdp, uint64_t gen) {
    if (gen != m_generation.load(std::memory_order_relaxed)) return;
    if (!m_pc) {
        fail(QStringLiteral("应用 answer 时 PeerConnection 已释放"));
        return;
    }
    try {
        rtc::Description answer(answer_sdp.toStdString(), "answer");
        m_pc->setRemoteDescription(answer);
        // [S3-5 2026-09-20] 关键修复: offerer 模式下本地 addTrack 的 track 不会触发
        // onTrack(libdatachannel 仅对远端引入的媒体段自动建 track 时回调), 必须手动
        // 挂解包链; 若 onTrack 意外双触发, attachTrack 内部幂等守卫消化
        if (m_track) attachTrack(m_track, gen);
        setState(State::Connecting);
    } catch (const std::exception& e) {
        fail(QStringLiteral("answer SDP 无效: %1").arg(QString::fromUtf8(e.what())));
    }
}

void WebRtcClient::attachTrack(const std::shared_ptr<rtc::Track>& track, uint64_t gen) {
    if (gen != m_generation.load(std::memory_order_relaxed)) return;
    // [S3-5] 幂等: applyAnswer(本地 track) 与 onTrack(远端 track) 双路径只挂一次
    if (m_track_attached.exchange(true)) return;

    m_track = track;

    // [S3-5 2026-09-20] 诊断: onTrack 触发 + 远端视频 track 的 payload types/SSRC 路由信息
    {
        const std::string mid = track->mid();
        QString pts;
        if (m_pc) {
            const auto rdesc = m_pc->remoteDescription();
            if (rdesc.has_value()) {
                for (int i = 0; i < rdesc->mediaCount(); ++i) {
                    const auto entry = rdesc->media(i);
                    const auto* mp = std::get_if<const rtc::Description::Media*>(&entry);
                    if (!mp || !*mp) continue;
                    const auto* media = *mp;
                    if (QString::fromStdString(media->mid()) == QString::fromStdString(mid)) {
                        for (int pt : media->payloadTypes()) pts += QString::number(pt) + " ";
                    }
                }
            }
        }
        qDebug() << "[WebRtcClient] onTrack fired: mid=" << QString::fromStdString(mid)
                 << "remote payloadTypes:" << pts.trimmed();
    }

    // 链: H264RtpDepacketizer(RTP→Annex-B 访问单元) → RtcpReceivingSession
    //   (收发 RTCP; requestKeyframe 由 MediaHandler 默认实现转发到链尾)
    auto depacketizer = std::make_shared<rtc::H264RtpDepacketizer>();
    auto session = std::make_shared<rtc::RtcpReceivingSession>();
    depacketizer->addToChain(session);
    track->setMediaHandler(depacketizer);

    // [S3-5 2026-09-20] 关键: 解包输出的访问单元带 FrameInfo, libdatachannel 的
    //   Track::flushPendingMessages 只把带 FrameInfo 的消息投递给 frameCallback
    //   (即 onFrame), onMessage(messageCallback) 永远收不到 —— 必须用 onFrame
    track->onFrame([this, gen](rtc::binary message, rtc::FrameInfo /*frame*/) {
        // 诊断: 首包 + 每 250 包一条(确认 RTP 解包输出到达)
        const uint64_t n = m_msg_count.fetch_add(1, std::memory_order_relaxed) + 1;
        if (n == 1 || (n % 250) == 0) {
            qDebug() << "[WebRtcClient] access-unit #" << static_cast<qulonglong>(n)
                     << "size=" << static_cast<qulonglong>(message.size());
        }
        onFrameData(reinterpret_cast<const uint8_t*>(message.data()), message.size(), gen);
    });
}

void WebRtcClient::onFrameData(const uint8_t* data, size_t size, uint64_t gen) {
    if (gen != m_generation.load(std::memory_order_relaxed)) return;
    if (!data || size == 0) return;

    // 与 stop() 互斥: 防 stop 关闭 decoder 时本回调仍在解码
    std::lock_guard<std::mutex> lk(m_decode_mutex);
    if (gen != m_generation.load(std::memory_order_relaxed)) return;

    m_access_units.fetch_add(1, std::memory_order_relaxed);

    // 连接就绪可从数据到达判定(部分路径 onStateChange(Connected) 晚于首包)
    if (m_state.load(std::memory_order_relaxed) == State::Connecting) setState(State::Connected);

    if (!m_decoder) return;
    const uint64_t ts = static_cast<uint64_t>(QDateTime::currentMSecsSinceEpoch());
    const int produced = m_decoder->decodeAnnexB(data, size, ts);

    if (produced > 0) {
        m_consecutive_errors.store(0, std::memory_order_relaxed);
        if (!m_first_frame.exchange(true)) emit firstFrameDecoded();
    } else if (produced < 0) {
        const uint64_t consecutive = m_consecutive_errors.fetch_add(1, std::memory_order_relaxed) + 1;
        if (consecutive >= kMaxConsecutiveDecodeErrors) {
            m_consecutive_errors.store(0, std::memory_order_relaxed);
            // 自动 PLI(带最小间隔节流): 请求 IDR 恢复
            const qint64 now_ms = QDateTime::currentMSecsSinceEpoch();
            const uint64_t last = m_last_keyframe_request_ms.load(std::memory_order_relaxed);
            if (last == 0 || now_ms - static_cast<qint64>(last) >= kKeyframeRequestMinIntervalMs) {
                m_last_keyframe_request_ms.store(static_cast<uint64_t>(now_ms), std::memory_order_relaxed);
                requestKeyframe();
            }
            emit decodeError(consecutive);
        }
    }
}

#endif // SHIELDBOX_ENABLE_WEBRTC_CLIENT
