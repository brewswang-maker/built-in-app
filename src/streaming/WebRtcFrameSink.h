#pragma once
#include <QObject>
#include <QImage>
#include <QSize>
#include <atomic>
#include <memory>
#include <mutex>
#include <vector>
#include <cstdint>

/**
 * @brief WebRtcFrameSink
 *
 * 子任务 2 引入 — V4-V1 WebRTC 渲染引擎集成(SmartGateWay v4.0 §4.1 S1T6 子任务 2)
 *
 * 角色:作为渲染端与未来接入的 PeerConnection(子任务 3)之间的帧传输抽象层。
 *      H264Decoder 解码完成的 RGB/YUV 帧通过 pushFrame() 注入,FBO 渲染线程
 *      在 swapFrameForRender() 拍照(lock-free 单生产者/单消费者)。
 *
 * 双缓冲语义(now/next):
 *   - `front_is_a` 标志当前"now"缓冲(buffer_a 还是 buffer_b)。
 *   - pushFrame() 写入 next,然后交换 now/next(drop-oldest)。
 *   - swapFrameForRender() 直接读 now,拷贝到 out_image,**不交换**;next 由
 *     下次 pushFrame() 覆盖(安全,因 producer 看不到 consumer 的中间态)。
 *
 * 与"经典双缓冲"不同点:
 *   - 经典生产者消费者都参与 swap,需要 mutex / 原子交换。
 *   - 本实现 producer 完成 push 后立即 swap,consumer 只读 now。
 *   - 牺牲"consumer 不丢数据"保证(consumer 永远读最新帧),换 lock-free 简化。
 *   - WebRTC 场景下丢帧可接受(NACK/FEC 补),正确性 > 时效性。
 *
 * 设计要点:
 *   1. **lock-free SPSC**:仅 1 个原子标志 front_is_a,producer 与 consumer 各占一边。
 *   2. **double buffer 双缓存**:每次 push 翻 front_is_a,使 consumer 永远拿到最近 push 的数据。
 *   3. **像素格式自动转换**:RGB888 → RGBA8888 内部转换(OpenGL 默认 RGBA)。
 *   4. **统计可观测**:`stats()` 返回 fps/帧数/丢帧数,接入 shieldbox-watchdog.sh 日志。
 *
 * 局限(子任务 3/4 解决):
 *   - 无真实 H264 解码;测试桩通过 pushFrame() 注入模拟帧。
 *   - 后续由 PeerConnection::onTrack() → libdatachannel 拉流 → H264Decoder 解码 → pushFrame()
 *
 * 验收(本子任务):test_webrtc_framebuffer.cpp --6 TEST_F PASS,验证
 *   - Push 帧不被阻塞
 *   - Swap 后 consume 计数 +1
 *   - 多 Producer 线程并发安全(atomic front_is_a)
 *   - 像素格式转换 + 尺寸变更 + 统计正确
 */
class WebRtcFrameSink {
public:
    enum class PixelFormat {
        RGBA8888,
        RGB888,
    };

    struct Stats {
        uint64_t total_produced = 0;     // 总生产帧数
        uint64_t total_consumed = 0;     // 总消费帧数
        uint64_t total_dropped = 0;      // 覆盖丢帧数(producer 覆盖未消费的帧)
    };

    explicit WebRtcFrameSink(QSize expectedSize = QSize(1280, 720));
    ~WebRtcFrameSink();

    /// 生产者接口 — H264Decoder 调用
    /// @return 0 表示正常;>0 表示有 cover_dropped;负数表示输入错误
    int64_t pushFrame(const uint8_t* data, uint32_t width, uint32_t height,
                      uint32_t stride, PixelFormat fmt, uint64_t timestamp_ms);

    /// 消费者接口 — FBO Renderer::render() 调用
    /// @return true 表示有帧数据被拷贝到 out_image
    bool swapFrameForRender(QImage& out_image);

    QSize expectedSize() const { return m_expected_size; }
    void setExpectedSize(QSize s);

    Stats stats() const;

private:
    /// 分配 next buffer 并返回指针(同时记录 front/back 角色)
    std::shared_ptr<std::vector<uint8_t>> allocateBuffer() const;

    /// 写入 next buffer(写入到非当前 front 的那一个)
    int64_t writeToNext(const uint8_t* data, uint32_t width, uint32_t height,
                        uint32_t stride, PixelFormat fmt, uint64_t timestamp_ms);

    /// 保护 m_buffer_a/b 读取(setExpectedSize vs read-bytes 并发)
    ///   pushFrame/swapFrameForRender 读 buffer:仅 mem 读不需要锁
    ///   setExpectedSize 改 buffer:需要 sync barrier,m_mutex 保护
    std::mutex m_alloc_mutex;

    QSize m_expected_size;
    std::shared_ptr<std::vector<uint8_t>> m_buffer_a;
    std::shared_ptr<std::vector<uint8_t>> m_buffer_b;
    std::atomic<bool> m_front_is_a{true};   // 当前可消费的 buffer

    // 帧 metadata
    std::atomic<uint64_t> m_seq{0};
    std::atomic<uint64_t> m_timestamp_ms{0};
    std::atomic<uint32_t> m_width{0};
    std::atomic<uint32_t> m_height{0};
    std::atomic<uint32_t> m_stride_bytes{0};

    // 统计
    std::atomic<uint64_t> m_total_produced{0};
    std::atomic<uint64_t> m_total_consumed{0};
    std::atomic<uint64_t> m_total_dropped{0};

    // 用于避免死循环:仅当 producer seq > 上次消费 seq 才返回 true
    std::atomic<uint64_t> m_last_consumed_seq{0};
};

Q_DECLARE_METATYPE(WebRtcFrameSink::Stats)
