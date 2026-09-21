// =============================================================================
// [S3-2 2026-09-20] H264Decoder 实现 — FFmpeg 软解 H264 → RGB24 → FrameSink
//
// FFmpeg 版本: sophon-ffmpeg 2.2.0 (FFmpeg 6.0 派生, libavcodec.so.60)
//   - x86      : /opt/sophon/sophon-ffmpeg-latest
//   - aarch64  : box-sdk/sysroot-v22/opt/sophon/sophon-ffmpeg_2.2.0
//   (include 路径由 CMakeLists 的 SHIELDBOX_FFMPEG_PREFIX 提供)
// =============================================================================

#ifdef SHIELDBOX_ENABLE_WEBRTC_CLIENT

#include "H264Decoder.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

#include <QSize>
#include <QString>

#include <cstring>

H264Decoder::H264Decoder() = default;

H264Decoder::~H264Decoder() {
    close();
    if (m_rgb_buffer) {
        av_freep(&m_rgb_buffer);
        m_rgb_capacity = 0;
    }
}

bool H264Decoder::open() {
    if (m_codec_ctx) return true;

    // 显式选软解器 "h264": Sophon FFmpeg 把 Bitmain 硬解 wrapper (h264_bm) 注册为
    // H264 默认解码器, avcodec_find_decoder() 会命中它 → 无 /dev/soph_vc_dec 时 open 失败。
    // 本通路目标就是软解(S1T6 按实改判), 故按名优先 "h264", 无则回退常规查找。
    const AVCodec* codec = avcodec_find_decoder_by_name("h264");
    if (!codec) codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (!codec) {
        m_decode_errors.fetch_add(1, std::memory_order_relaxed);
        return false;
    }

    m_codec_ctx = avcodec_alloc_context3(codec);
    if (!m_codec_ctx) {
        m_decode_errors.fetch_add(1, std::memory_order_relaxed);
        return false;
    }

    // 低延迟确定性: 单线程解码, GB28181 码流无 B 帧 → 1 包进 1 帧出
    m_codec_ctx->thread_count = 1;
    // 容忍坏包(网络抖动丢包/回环丢弃): 不因单帧损坏中止整条流
    m_codec_ctx->err_recognition = 0;

    int ret = avcodec_open2(m_codec_ctx, codec, nullptr);
    if (ret < 0) {
        avcodec_free_context(&m_codec_ctx);
        m_decode_errors.fetch_add(1, std::memory_order_relaxed);
        return false;
    }

    m_frame = av_frame_alloc();
    m_packet = av_packet_alloc();
    if (!m_frame || !m_packet) {
        close();
        return false;
    }
    return true;
}

void H264Decoder::close() {
    if (m_sws) {
        sws_freeContext(m_sws);
        m_sws = nullptr;
    }
    if (m_frame) av_frame_free(&m_frame);
    if (m_packet) av_packet_free(&m_packet);
    if (m_codec_ctx) avcodec_free_context(&m_codec_ctx);
}

void H264Decoder::flush() {
    if (m_codec_ctx) avcodec_flush_buffers(m_codec_ctx);
    m_consecutive_errors.store(0, std::memory_order_relaxed);
}

int H264Decoder::decodeAnnexB(const uint8_t* data, size_t size, uint64_t timestamp_ms) {
    if (!data || size == 0) return -1;
    if (!m_codec_ctx && !open()) return -1;

    // 输入包拷贝(avcodec 需要完整的 AVPacket; 每帧一次拷贝, 帧率低时开销可忽略)
    av_packet_unref(m_packet);
    int ret = av_new_packet(m_packet, static_cast<int>(size));
    if (ret < 0) {
        m_decode_errors.fetch_add(1, std::memory_order_relaxed);
        m_consecutive_errors.fetch_add(1, std::memory_order_relaxed);
        return -1;
    }
    std::memcpy(m_packet->data, data, size);
    m_packets_in.fetch_add(1, std::memory_order_relaxed);

    ret = avcodec_send_packet(m_codec_ctx, m_packet);
    if (ret < 0) {
        // 坏包(损坏 NAL/参考帧缺失) → 计数, 不中止
        m_decode_errors.fetch_add(1, std::memory_order_relaxed);
        m_consecutive_errors.fetch_add(1, std::memory_order_relaxed);
        return -1;
    }

    int produced = 0;
    while (true) {
        ret = avcodec_receive_frame(m_codec_ctx, m_frame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) {
            m_decode_errors.fetch_add(1, std::memory_order_relaxed);
            m_consecutive_errors.fetch_add(1, std::memory_order_relaxed);
            break;
        }
        m_frames_out.fetch_add(1, std::memory_order_relaxed);
        ++produced;
        deliverFrame(m_frame, timestamp_ms);
        av_frame_unref(m_frame);
        m_consecutive_errors.store(0, std::memory_order_relaxed);
    }
    return produced;
}

int H264Decoder::deliverFrame(const AVFrame* frame, uint64_t timestamp_ms) {
    const int w = frame->width;
    const int h = frame->height;
    if (w <= 0 || h <= 0) return -1;

    // sws 上下文(YUV 尺寸/格式变更时自动重建)
    m_sws = sws_getCachedContext(m_sws, w, h, static_cast<AVPixelFormat>(frame->format),
                                 w, h, AV_PIX_FMT_RGB24, SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!m_sws) return -1;

    const size_t stride = static_cast<size_t>(w) * 3;
    const size_t needed = stride * static_cast<size_t>(h);
    if (needed > m_rgb_capacity) {
        if (m_rgb_buffer) av_freep(&m_rgb_buffer);
        m_rgb_buffer = static_cast<uint8_t*>(av_malloc(needed));
        if (!m_rgb_buffer) {
            m_rgb_capacity = 0;
            return -1;
        }
        m_rgb_capacity = needed;
    }

    uint8_t* dst[4] = { m_rgb_buffer, nullptr, nullptr, nullptr };
    int dst_stride[4] = { static_cast<int>(stride), 0, 0, 0 };
    sws_scale(m_sws, frame->data, frame->linesize, 0, h, dst, dst_stride);

    m_last_width.store(w, std::memory_order_relaxed);
    m_last_height.store(h, std::memory_order_relaxed);

    if (m_sink) {
        int64_t dropped = m_sink->pushFrame(m_rgb_buffer, static_cast<uint32_t>(w),
                                            static_cast<uint32_t>(h), static_cast<uint32_t>(stride),
                                            WebRtcFrameSink::PixelFormat::RGB888, timestamp_ms);
        if (dropped >= 0) m_sink_pushes.fetch_add(1, std::memory_order_relaxed);
    }
    return 0;
}

H264Decoder::Stats H264Decoder::stats() const {
    Stats s;
    s.packets_in = m_packets_in.load(std::memory_order_relaxed);
    s.frames_out = m_frames_out.load(std::memory_order_relaxed);
    s.sink_pushes = m_sink_pushes.load(std::memory_order_relaxed);
    s.decode_errors = m_decode_errors.load(std::memory_order_relaxed);
    s.consecutive_errors = m_consecutive_errors.load(std::memory_order_relaxed);
    return s;
}

QSize H264Decoder::lastFrameSize() const {
    return QSize(m_last_width.load(std::memory_order_relaxed),
                 m_last_height.load(std::memory_order_relaxed));
}

QString H264Decoder::lastError() const {
    if (!m_codec_ctx) return QStringLiteral("H264 decoder not open");
    return QString();
}

#endif // SHIELDBOX_ENABLE_WEBRTC_CLIENT
