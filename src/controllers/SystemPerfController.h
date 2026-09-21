/**
 * @file SystemPerfController.h
 * @brief [P2-C 2026-09-21] 端侧性能预算采样控制器
 *
 * 周期采样网关主进程 (smartgateway) 三项预算指标, 5s 节流:
 *   - CPU%  : /proc/stat 差值 (与 top 同源, 满足 TC-SYS-02 ±10% 判据)
 *   - RSS   : /proc/<pid>/status VmRSS (KB → MB)
 *   - TPU%  : bm-smi 输出解析 (x86 主机/驱动缺失时 = -1, UI 显示 "--")
 *
 * 判据对应: TC-SYS-02 (面板数值与 top/bm-smi 手工抽样一致 ±10%);
 * 配套 24h 采样落盘脚本: scripts/rss_sample.sh (cron, 独立链路)。
 */
#pragma once

#include <QObject>
#include <QTimer>
#include <QProcess>

class SystemPerfController : public QObject {
    Q_OBJECT
    // 采样值: 未就绪/进程不在时 cpu/rss = -1, tpu = -1 (UI 显 "--")
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY perfUpdated)
    Q_PROPERTY(double rssMb READ rssMb NOTIFY perfUpdated)
    Q_PROPERTY(double tpuPercent READ tpuPercent NOTIFY perfUpdated)
    Q_PROPERTY(bool gatewayFound READ gatewayFound NOTIFY perfUpdated)
    // 预算阈值 (超限 UI 变色; 常量口径: 设备常见 4GB 内存 → RSS 预算 75%)
    Q_PROPERTY(int cpuThresholdPercent READ cpuThresholdPercent CONSTANT)
    Q_PROPERTY(int rssThresholdMb READ rssThresholdMb CONSTANT)
    Q_PROPERTY(int tpuThresholdPercent READ tpuThresholdPercent CONSTANT)
    Q_PROPERTY(bool sampling READ sampling NOTIFY samplingChanged)

public:
    explicit SystemPerfController(QObject* parent = nullptr);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

    double cpuPercent() const { return m_cpuPercent; }
    double rssMb() const { return m_rssMb; }
    double tpuPercent() const { return m_tpuPercent; }
    bool gatewayFound() const { return m_gatewayPid > 0; }
    bool sampling() const { return m_timer.isActive(); }
    int cpuThresholdPercent() const { return kCpuThreshold; }
    int rssThresholdMb() const { return kRssThresholdMb; }
    int tpuThresholdPercent() const { return kTpuThreshold; }

signals:
    void perfUpdated();
    void samplingChanged();

private slots:
    void sampleOnce();
    void onBmSmiFinished(int exitCode, QProcess::ExitStatus status);

private:
    static constexpr int kSampleIntervalMs = 5000;
    static constexpr int kCpuThreshold = 80;
    static constexpr int kRssThresholdMb = 3072;   // 4GB 设备 × 75%
    static constexpr int kTpuThreshold = 85;

    // /proc 遍历查找 smartgateway 主进程 pid (无 QProcess 开销)
    static qint64 findGatewayPid();
    // CPU: /proc/stat 差值 (busy = total - idle - iowait)
    bool readCpuJiffies(quint64& total, quint64& busy);
    // RSS: /proc/<pid>/status VmRSS (kB)
    bool readRssKb(qint64 pid, double& rssMb);

    QTimer m_timer;
    QProcess m_bmSmi;                 // TPU 利用率采样 (异步, 结果槽内解析)
    bool m_bmSmiInFlight = false;     // 防重入 (上轮未完成跳过本轮)
    bool m_bmSmiAvailable = true;     // 首次执行 ENOENT 后置 false (x86 主机)
    qint64 m_gatewayPid = -1;
    quint64 m_prevTotal = 0, m_prevBusy = 0;
    bool m_hasPrev = false;
    double m_cpuPercent = -1.0;
    double m_rssMb = -1.0;
    double m_tpuPercent = -1.0;
};
