#pragma once
// =============================================================================
// [S3-2 2026-09-20] WebRtcClient — WHEP 信令 + RTP 解包 + H264 解码 → FrameSink
//
// V4-V1 S1T6 子任务 3 (S3-2)。接替 WebRtcRenderer 骨架中的"真实 SDP/ICE/H264
// 由 libdatachannel + FFmpeg 完成"占位(WebRtcRenderer.h:33)。
//
// 信令契约(ZLM 直连, 与设备实测一致):
//   请求: POST http://<host>:9080/index/api/webrtc?app=<app>&stream=<id>&type=play
//         Content-Type: application/sdp, body = 本地 SDP offer(裸文本)
//         ZLMediaKit/server/WebApi.cpp:2185 起实现 — body 即 allArgs.args
//   响应: JSON {code:0, sdp:"<answer>", id:"...", type:"answer"}
//         失败: JSON {code:<非0>, msg:"..."} (HTTP 仍 200, 以 code 判定)
//   兼容: 若响应体非 JSON(裸 SDP), 直接视为 answer(他厂 WHEP 变体)
//
// RTP 路由: libdatachannel 按 SSRC 路由入站 RTP; ZLM answer 必含 a=ssrc
//   (WebRtcTransport.cpp:1021 video ssrc = TrackVideo(0) + RTP_SSRC_OFFSET(1) = 1),
//   故无需额外处理。
//
// 线程模型:
//   - 创建/start/stop: GUI 线程
//   - PeerConnection 回调(onStateChange): libdatachannel 内部线程
//     → 信令 HTTP 经 QMetaObject::invokeMethod 切回 GUI 线程
//     → 收流解码就在回调线程执行(低延迟), 帧经 FrameSink SPSC 直达渲染线程
//   - offerer 模式: 本地 addTrack 的 track 不触发 onTrack(libdatachannel 仅对
//     远端引入的媒体段自动建 track 时回调), 由 applyAnswer 手动挂链;
//     解包输出带 FrameInfo → 只能经 onFrame 接收(非 onMessage)
//   - 代际计数 m_generation: stop() 后旧回调全部失效, 防竞态
//
// 默认 OFF 构建(无 SHIELDBOX_ENABLE_WEBRTC_CLIENT)时本类不存在。
// =============================================================================

#include <QObject>
#include <QString>
#include <QSize>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>

#include "WebRtcFrameSink.h"

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT

class H264Decoder;

namespace rtc {
class PeerConnection;
class Track;
} // namespace rtc

class QNetworkAccessManager;
class QNetworkReply;

class WebRtcClient : public QObject {
    Q_OBJECT
public:
    enum class State {
        Idle,       // 未启动/已停止
        Gathering,  // 本地 ICE 收集(offer 生成中)
        Signalling, // offer 已发出, 等待 answer
        Connecting, // answer 已应用, ICE/DTLS 建立中
        Connected,  // 连接就绪, 收流中
        Failed      // 不可恢复失败(错误详情在 lastError())
    };
    Q_ENUM(State)

    struct Config {
        QString signaling_host = QStringLiteral("127.0.0.1");
        quint16 signaling_port = 9080;   // ZLM HTTP API(设备 56mf 实测端口)
        QString app = QStringLiteral("rtp");
        QString stream;                  // 流 ID, 如 "gb_34020000001320002001"
        int gather_timeout_ms = 5000;    // ICE 收集超时
        int signaling_timeout_ms = 8000; // 信令 HTTP 超时
        QString ice_server;              // 可选 STUN/TURN URL(留空=仅 host 候选)
    };

    struct Stats {
        uint64_t access_units = 0;   // 解包输出访问单元(RTP 帧)数
        uint64_t frames_decoded = 0; // 解码成功帧数
        uint64_t frames_pushed = 0;  // 推入 FrameSink 帧数
        uint64_t decode_errors = 0;  // 解码错误累计
        bool first_frame = false;    // 是否已收到首帧
    };

    explicit WebRtcClient(QObject* parent = nullptr);
    ~WebRtcClient() override;

    /// FrameSink 生命周期由调用方(WebRtcRendererItem)保证, 必须长于本对象
    void setFrameSink(WebRtcFrameSink* sink);

    /// 启动: 建 PeerConnection → 收集 ICE → 发 offer → 应用 answer → 收流解码
    void start(const Config& config);

    /// 停止并复位(幂等; 可再次 start)
    void stop();

    State state() const { return m_state.load(std::memory_order_relaxed); }
    QString lastError() const;
    Stats stats() const;

    /// 向对端请求关键帧(PLI; 解码连续错误后自动触发, 亦可供上层手动调用)
    bool requestKeyframe();

    /// 当前信令 URL(日志/测试用)
    QString signalingUrl() const;

signals:
    void stateChanged(WebRtcClient::State state);
    void firstFrameDecoded();                     // 首帧送达 sink(端到端可播证据)
    void decodeError(uint64_t consecutive_errors); // 连续解码错误(降级链输入)
    void errorOccurred(const QString& message);   // 终态失败(伴随 state=Failed)

private:
    void setState(State s);
    void fail(const QString& message);
    void sendOfferHttp(const QString& offer_sdp, uint64_t gen);
    void handleSignalingReply(uint64_t gen);
    void applyAnswer(const QString& answer_sdp, uint64_t gen);
    void attachTrack(const std::shared_ptr<rtc::Track>& track, uint64_t gen);
    void onFrameData(const uint8_t* data, size_t size, uint64_t gen);

    // 代际计数: start/stop 递增, 使所有旧回调失效
    std::atomic<uint64_t> m_generation{0};
    std::atomic<State> m_state{State::Idle};
    mutable std::mutex m_error_mutex;
    QString m_last_error;

    // 解码路径与 stop() 的 decoder 生命周期互斥(防 stop 释放中回调在使用)
    std::mutex m_decode_mutex;

    Config m_config;
    WebRtcFrameSink* m_sink = nullptr;
    std::unique_ptr<H264Decoder> m_decoder;
    std::shared_ptr<rtc::PeerConnection> m_pc;
    std::shared_ptr<rtc::Track> m_track;

    QNetworkAccessManager* m_nam = nullptr; // GUI 线程持有
    QNetworkReply* m_reply = nullptr;

    std::atomic<uint64_t> m_access_units{0};
    std::atomic<uint64_t> m_msg_count{0};   // [S3-5] onMessage 诊断计数(首包/周期日志)
    // [S3-5] offerer 模式: 本地 addTrack 的 track 不会触发 onTrack(libdatachannel
    // 仅对远端引入的媒体段自动建 track 时回调), 由 applyAnswer 手动挂链;
    // 本标记保证双向路径只挂一次
    std::atomic<bool> m_track_attached{false};
    std::atomic<bool> m_first_frame{false};
    std::atomic<uint64_t> m_consecutive_errors{0};
    std::atomic<uint64_t> m_last_keyframe_request_ms{0};
};

#else // !SHIELDBOX_ENABLE_WEBRTC_CLIENT

// 默认 OFF 构建: 提供最小占位, 便于上层条件引用时给出编译期明确提示
class WebRtcClient;

#endif // SHIELDBOX_ENABLE_WEBRTC_CLIENT
