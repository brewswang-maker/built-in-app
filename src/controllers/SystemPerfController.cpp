/**
 * @file SystemPerfController.cpp
 * @brief [P2-C 2026-09-21] 端侧性能预算采样实现 (TC-SYS-02)
 *
 * 采样口径与手工抽样工具同源, 保证 ±10% 判据:
 *   - CPU%  : /proc/stat 首行差值, busy = total - idle - iowait (top 同源)
 *   - RSS   : /proc/<pid>/status VmRSS (kB → MB, ps -o rss 同源)
 *   - TPU%  : bm-smi info 输出解析 (异步 QProcess, x86 主机 ENOENT 后停用)
 *
 * 监控对象是网关主进程 smartgateway (非本 App): App 挂了网关还得跑。
 */
#include "SystemPerfController.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QDebug>

namespace {

// bm-smi 各版本输出差异大 (BM1684/BM1684X 表头措辞不同),
// 宽容策略: 在含 TPU/Utilization 字样的行上取第一个百分比数字;
// 解析失败如实返回 false (UI 显示 "--"), 不臆造数值。
bool parseTpuPercent(const QByteArray& out, double& pct) {
    const QStringList lines = QString::fromLocal8Bit(out).split(QLatin1Char('\n'));
    static const QRegularExpression re(QStringLiteral("(\\d+(?:\\.\\d+)?)\\s*%"));
    for (const QString& line : lines) {
        if (!line.contains(QLatin1String("TPU"), Qt::CaseInsensitive) &&
            !line.contains(QLatin1String("Utilization"), Qt::CaseInsensitive)) {
            continue;
        }
        const auto m = re.match(line);
        if (m.hasMatch()) {
            pct = m.captured(1).toDouble();
            return true;
        }
    }
    return false;
}

} // namespace

SystemPerfController::SystemPerfController(QObject* parent)
    : QObject(parent) {
    m_timer.setInterval(kSampleIntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &SystemPerfController::sampleOnce);
    connect(&m_bmSmi, &QProcess::finished,
            this, &SystemPerfController::onBmSmiFinished);
}

void SystemPerfController::start() {
    if (m_timer.isActive()) return;
    m_timer.start();
    sampleOnce();   // 首采立即出数 (首轮 CPU 无基线, 下一轮起有效)
    emit samplingChanged();
}

void SystemPerfController::stop() {
    if (!m_timer.isActive()) return;
    m_timer.stop();
    emit samplingChanged();
}

qint64 SystemPerfController::findGatewayPid() {
    // /proc 遍历比对 comm (无 pgrep 进程开销); 精确匹配避免
    // 误中包含 "smartgateway" 子串的无关进程。
    const QDir proc(QStringLiteral("/proc"));
    const auto entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString& e : entries) {
        bool ok = false;
        const qint64 pid = e.toLongLong(&ok);
        if (!ok || pid <= 0) continue;
        QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
        if (!comm.open(QIODevice::ReadOnly)) continue;
        if (QString::fromLocal8Bit(comm.readAll()).trimmed()
                == QLatin1String("smartgateway")) {
            return pid;
        }
    }
    return -1;
}

bool SystemPerfController::readCpuJiffies(quint64& total, quint64& busy) {
    QFile f(QStringLiteral("/proc/stat"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    const QString first = QString::fromLocal8Bit(f.readLine());
    // 首行格式: "cpu  user nice system idle iowait irq softirq steal ..."
    if (!first.startsWith(QLatin1String("cpu"))) return false;
    const QStringList parts = first.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    quint64 t = 0, idleAll = 0;
    for (int i = 1; i < parts.size(); ++i) {
        const quint64 v = parts[i].toULongLong();
        t += v;
        if (i == 4 || i == 5) idleAll += v;   // idle(4) + iowait(5)
    }
    total = t;
    busy = (t > idleAll) ? (t - idleAll) : 0;
    return true;
}

bool SystemPerfController::readRssKb(qint64 pid, double& rssMb) {
    QFile f(QStringLiteral("/proc/%1/status").arg(pid));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    while (!f.atEnd()) {
        const QString line = QString::fromLocal8Bit(f.readLine());
        if (line.startsWith(QLatin1String("VmRSS:"))) {
            const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                rssMb = parts[1].toDouble() / 1024.0;
                return true;
            }
        }
    }
    return false;
}

void SystemPerfController::sampleOnce() {
    // 1) 定位网关主进程 (每轮重找: 网关可能重启换 pid)
    m_gatewayPid = findGatewayPid();

    // 2) CPU%: 差值口径, 首轮无基线保持 -1 (UI "--", 首采后 5s 出数)
    quint64 total = 0, busy = 0;
    const bool statOk = readCpuJiffies(total, busy);
    if (m_gatewayPid <= 0) {
        m_cpuPercent = -1.0;   // 网关不在, 指标无意义
        m_hasPrev = false;
    } else if (statOk && m_hasPrev && total > m_prevTotal) {
        const quint64 dt = total - m_prevTotal;
        const quint64 db = (busy > m_prevBusy) ? (busy - m_prevBusy) : 0;
        m_cpuPercent = 100.0 * static_cast<double>(db) / static_cast<double>(dt);
    }
    if (statOk) {
        m_prevTotal = total;
        m_prevBusy = busy;
        m_hasPrev = true;
    }

    // 3) RSS (MB)
    double rss = 0.0;
    if (m_gatewayPid > 0 && readRssKb(m_gatewayPid, rss)) {
        m_rssMb = rss;
    } else {
        m_rssMb = -1.0;
    }

    // 4) TPU: bm-smi 异步采样 (防重入; ENOENT → 本会话停用, 常见于 x86 开发机)
    if (m_gatewayPid > 0 && m_bmSmiAvailable && !m_bmSmiInFlight &&
        m_bmSmi.state() == QProcess::NotRunning) {
        m_bmSmiInFlight = true;
        m_bmSmi.start(QStringLiteral("bm-smi"), QStringList{QStringLiteral("info")});
        if (m_bmSmi.error() == QProcess::FailedToStart) {
            m_bmSmiAvailable = false;
            m_bmSmiInFlight = false;
            m_tpuPercent = -1.0;
        }
    }

    emit perfUpdated();
}

void SystemPerfController::onBmSmiFinished(int exitCode, QProcess::ExitStatus status) {
    m_bmSmiInFlight = false;
    double pct = 0.0;
    if (status == QProcess::NormalExit && exitCode == 0 &&
        parseTpuPercent(m_bmSmi.readAllStandardOutput(), pct)) {
        m_tpuPercent = pct;
    } else {
        m_tpuPercent = -1.0;   // 解析失败 → "--" (不臆造)
    }
    emit perfUpdated();
}
