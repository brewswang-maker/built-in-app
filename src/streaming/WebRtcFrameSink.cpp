#include "WebRtcFrameSink.h"

#include <cstring>
#include <algorithm>

namespace {
constexpr size_t kBytesPerPixelRGBA = 4;
constexpr size_t kBytesPerPixelRGB = 3;
}

WebRtcFrameSink::WebRtcFrameSink(QSize expectedSize)
    : m_expected_size(expectedSize) {
    const size_t bytes =
        static_cast<size_t>(expectedSize.width()) * expectedSize.height() *
        kBytesPerPixelRGBA;
    m_buffer_a = std::make_shared<std::vector<uint8_t>>(bytes);
    m_buffer_b = std::make_shared<std::vector<uint8_t>>(bytes);

    m_width.store(static_cast<uint32_t>(expectedSize.width()));
    m_height.store(static_cast<uint32_t>(expectedSize.height()));
    m_stride_bytes.store(static_cast<uint32_t>(expectedSize.width() * kBytesPerPixelRGBA));
}

WebRtcFrameSink::~WebRtcFrameSink() = default;

std::shared_ptr<std::vector<uint8_t>> WebRtcFrameSink::allocateBuffer() const {
    const size_t bytes =
        static_cast<size_t>(m_expected_size.width()) *
        m_expected_size.height() * kBytesPerPixelRGBA;
    return std::make_shared<std::vector<uint8_t>>(bytes);
}

void WebRtcFrameSink::setExpectedSize(QSize s) {
    // m_alloc_mutex 保护 buffer_a/b 重赋值;pushFrame/swapFrameForRender
    // 仅读 buffer 共享指针(shared_ptr 赋值 atomic),不争锁
    std::lock_guard<std::mutex> lk(m_alloc_mutex);
    if (s == m_expected_size) return;
    m_expected_size = s;
    auto new_a = allocateBuffer();
    auto new_b = allocateBuffer();
    bool front_is_a = m_front_is_a.load(std::memory_order_acquire);
    if (front_is_a) {
        m_buffer_a = new_a;
        m_buffer_b = new_b;
    } else {
        m_buffer_a = new_b;
        m_buffer_b = new_a;
    }
    m_width.store(static_cast<uint32_t>(s.width()));
    m_height.store(static_cast<uint32_t>(s.height()));
    m_stride_bytes.store(static_cast<uint32_t>(s.width() * kBytesPerPixelRGBA));
}

int64_t WebRtcFrameSink::writeToNext(const uint8_t* data, uint32_t width,
                                      uint32_t height, uint32_t stride,
                                      PixelFormat fmt, uint64_t timestamp_ms) {
    if (!data) return -1;

    const size_t bpp = (fmt == PixelFormat::RGBA8888) ? kBytesPerPixelRGBA
                                                       : kBytesPerPixelRGB;
    if (stride < width * bpp) return -2;

    bool front_is_a = m_front_is_a.load(std::memory_order_acquire);
    std::shared_ptr<std::vector<uint8_t>> next =
        front_is_a ? m_buffer_b : m_buffer_a;
    if (!next || next->empty()) return -3;

    const uint32_t target_stride =
        static_cast<uint32_t>(m_expected_size.width()) *
        static_cast<uint32_t>(kBytesPerPixelRGBA);
    const uint32_t copy_h = std::min(height, m_height.load());
    const uint32_t copy_w = std::min(width, m_width.load());

    if (fmt == PixelFormat::RGBA8888) {
        for (uint32_t y = 0; y < copy_h; ++y) {
            const uint8_t* src_row = data + y * stride;
            uint8_t* dst_row = next->data() + y * target_stride;
            std::memcpy(dst_row, src_row, copy_w * bpp);
        }
    } else {  // RGB888 → RGBA8888
        for (uint32_t y = 0; y < copy_h; ++y) {
            const uint8_t* src_row = data + y * stride;
            uint8_t* dst_row = next->data() + y * target_stride;
            for (uint32_t x = 0; x < copy_w; ++x) {
                dst_row[x * 4 + 0] = src_row[x * 3 + 0];
                dst_row[x * 4 + 1] = src_row[x * 3 + 1];
                dst_row[x * 4 + 2] = src_row[x * 3 + 2];
                dst_row[x * 4 + 3] = 0xFF;
            }
        }
    }

    // 更新 metadata
    m_timestamp_ms.store(timestamp_ms, std::memory_order_release);
    m_width.store(width, std::memory_order_release);
    m_height.store(height, std::memory_order_release);
    m_stride_bytes.store(stride, std::memory_order_release);

    return 0;
}

int64_t WebRtcFrameSink::pushFrame(const uint8_t* data, uint32_t width,
                                    uint32_t height, uint32_t stride,
                                    PixelFormat fmt, uint64_t timestamp_ms) {
    int64_t ret = writeToNext(data, width, height, stride, fmt, timestamp_ms);
    if (ret < 0) return ret;

    // 检测 cover-dropped:若 consumer 跟不上 producer,会有 gap
    uint64_t last_seq = m_seq.load(std::memory_order_acquire);
    uint64_t consumed = m_total_consumed.load(std::memory_order_acquire);
    if (consumed + 1 < last_seq) {
        // 上次 producer seq 是 last_seq,consumer 只消费到 consumed
        // 我们即将增加 seq 到 last_seq + 1,这次会覆盖 last_seq - consumed - 1 个未消费帧
        m_total_dropped.fetch_add(last_seq - consumed - 1,
                                  std::memory_order_relaxed);
    }

    // 翻 front_is_a:next 变 now,旧 now 变 next
    bool cur = m_front_is_a.load(std::memory_order_acquire);
    m_front_is_a.store(!cur, std::memory_order_release);

    // seq + 1
    m_seq.fetch_add(1, std::memory_order_acq_rel);
    m_total_produced.fetch_add(1, std::memory_order_relaxed);
    return 0;
}

bool WebRtcFrameSink::swapFrameForRender(QImage& out_image) {
    uint64_t cur_seq = m_seq.load(std::memory_order_acquire);
    // 防死循环:仅当 producer 自上次消费后有新帧才返回 true
    uint64_t last_consumed = m_last_consumed_seq.load(std::memory_order_acquire);
    if (cur_seq == 0 || cur_seq == last_consumed) return false;

    bool front_is_a = m_front_is_a.load(std::memory_order_acquire);
    std::shared_ptr<std::vector<uint8_t>> now_buf =
        front_is_a ? m_buffer_a : m_buffer_b;
    if (!now_buf || now_buf->empty()) return false;

    const uint32_t w = m_width.load(std::memory_order_acquire);
    const uint32_t h = m_height.load(std::memory_order_acquire);
    if (out_image.width() != static_cast<int>(w) ||
        out_image.height() != static_cast<int>(h) ||
        out_image.format() != QImage::Format_RGBA8888) {
        out_image = QImage(static_cast<int>(w), static_cast<int>(h),
                           QImage::Format_RGBA8888);
    }

    const uint32_t src_stride = m_stride_bytes.load(std::memory_order_acquire);
    const uint32_t dst_stride =
        static_cast<uint32_t>(out_image.bytesPerLine());
    const uint32_t copy_h = std::min(h, static_cast<uint32_t>(out_image.height()));
    const uint32_t copy_w_bytes =
        std::min({src_stride, dst_stride,
                   static_cast<uint32_t>(out_image.width() * 4)});
    for (uint32_t y = 0; y < copy_h; ++y) {
        std::memcpy(out_image.scanLine(y),
                    now_buf->data() + y * src_stride,
                    copy_w_bytes);
    }

    m_last_consumed_seq.store(cur_seq, std::memory_order_release);
    m_total_consumed.fetch_add(1, std::memory_order_relaxed);
    return true;
}

WebRtcFrameSink::Stats WebRtcFrameSink::stats() const {
    Stats s;
    s.total_produced = m_total_produced.load(std::memory_order_relaxed);
    s.total_consumed = m_total_consumed.load(std::memory_order_relaxed);
    s.total_dropped = m_total_dropped.load(std::memory_order_relaxed);
    return s;
}
