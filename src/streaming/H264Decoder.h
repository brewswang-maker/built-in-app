#pragma once
// =============================================================================
// [S3-2 2026-09-20] H264Decoder — FFmpeg 软解 H264 → WebRtcFrameSink
//
// V4-V1 S1T6 子任务 3: WebRtcClient 收到解包后的 Annex-B 访问单元(访问单元=一帧),
// 经本类 avcodec_send_packet/receive_frame 解码, sws_scale YUV→RGB24,
// 通过 WebRtcFrameSink::pushFrame 交给渲染线程(SPSC 双缓冲)。
//
// 设计要点:
//   - **单线程解码**(thread_count=1): 低延迟 + 确定性 1 包 1 帧(GB28181 基本无 B 帧)
//   - **软解**: 56mf 设备 GL 不可用(S1T6 原 FBO+硬解假设已按实改判), CV186AH
//     无 FFmpeg hwaccel 通路, 走 CPU 解码
//   - **容错**: 网络抖动导致的坏包只计数不中断; 连续错误达阈值由上层
//     (WebRtcClient) 请求 IDR(PLI)
//   - **线程安全边界**: decodeAnnexB 仅在 libdatachannel 回调线程调用;
//     stats()/lastFrameSize() 可被 GUI 线程读取(atomic)
//
// 默认 OFF 构建(无 SHIELDBOX_ENABLE_WEBRTC_CLIENT)时本类不存在。
// =============================================================================

#include <cstdint>
#include <cstddef>
#include <atomic>
#include <QSize>
#include <QString>

#include "WebRtcFrameSink.h"

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT

struct AVCodecContext;
struct AVFrame;
struct AVPacket;
struct SwsContext;

class H264Decoder {
public:
    struct Stats {
        uint64_t packets_in = 0;        // 送入解码器的访问单元数
        uint64_t frames_out = 0;        // 解码成功产出帧数
        uint64_t sink_pushes = 0;       // 成功推入 FrameSink 的帧数
        uint64_t decode_errors = 0;     // avcodec 返回错误累计
        uint64_t consecutive_errors = 0; // 当前连续错误计数(成功解码清零)
    };

    H264Decoder();
    ~H264Decoder();

    H264Decoder(const H264Decoder&) = delete;
    H264Decoder& operator=(const H264Decoder&) = delete;

    /// 查找 H264 解码器并打开(幂等; 失败返回 false 且 lastError() 有值)
    bool open();
    void close();
    bool isOpen() const { return m_codec_ctx != nullptr; }

    /// 解码一个 Annex-B 访问单元(H264RtpDepacketizer StartSequence 输出格式)。
    /// @param data 访问单元起始(含 00 00 00 01 起始码)
    /// @param timestamp_ms 推入 sink 的帧时间戳(时钟由调用方约定)
    /// @return >=0: 本次产出的帧数; <0: 输入无效或解码致命错误
    int decodeAnnexB(const uint8_t* data, size_t size, uint64_t timestamp_ms);

    /// 冲刷解码器(断开/重连时调用, 清空参考帧队列)
    void flush();

    void setFrameSink(WebRtcFrameSink* sink) { m_sink = sink; }
    WebRtcFrameSink* frameSink() const { return m_sink; }

    Stats stats() const;
    QSize lastFrameSize() const;
    QString lastError() const;

private:
    /// sws 转换为 RGB24 并推入 sink; 返回 0 成功
    int deliverFrame(const AVFrame* frame, uint64_t timestamp_ms);

    AVCodecContext* m_codec_ctx = nullptr;
    AVFrame* m_frame = nullptr;       // 解码输出帧(YUV, 复用)
    AVPacket* m_packet = nullptr;     // 输入包(复用)
    SwsContext* m_sws = nullptr;      // YUV→RGB24 转换器(尺寸/格式变更自动重建)
    uint8_t* m_rgb_buffer = nullptr;  // av_malloc 的 RGB 输出缓冲
    size_t m_rgb_capacity = 0;

    WebRtcFrameSink* m_sink = nullptr; // 生命周期由调用方(Renderer)保证

    // 统计(GUI 线程读, 解码线程写)
    std::atomic<uint64_t> m_packets_in{0};
    std::atomic<uint64_t> m_frames_out{0};
    std::atomic<uint64_t> m_sink_pushes{0};
    std::atomic<uint64_t> m_decode_errors{0};
    std::atomic<uint64_t> m_consecutive_errors{0};
    std::atomic<int> m_last_width{0};
    std::atomic<int> m_last_height{0};
};

#endif // SHIELDBOX_ENABLE_WEBRTC_CLIENT
