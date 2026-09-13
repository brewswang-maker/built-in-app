#pragma once
/**
 * @file AlarmVerdictConsumer.h
 * @brief [SSOT R10 2026-09-12] 内置端单判定源消费器 — 报警弹窗三态降级链
 *
 * 背景 (docs/plans/rule-algo-popup-ssot-refactor-v1.0.md §4.4/§5.1 + §8.1
 * 操作门第 2 点): 判定权收归后端后, alarm.new 主帧携带 linkage_verdict
 * (R1 单判定源); 内置端须与 web 端 useGlobalAlarm (L365-420) 行为对等:
 *   a) verdict 存在 (新后端, verdict_push_enabled=true):
 *      - matched=false            → 整链静默 (不弹窗; 列表照常刷新)
 *      - matched && debounced     → 不弹窗 (后端防抖窗口内复发, 同步本地防抖图)
 *      - matched && !debounced    → 弹窗 (动作/自动关闭秒取 verdict)
 *   b) verdict 缺失 (旧后端 / verdict_push_enabled=false 回退态):
 *      → Fallback, 走现状本地防抖链 (零回归)。
 *
 * 帧富化: 单权威切换 (R9) 后 WEB_POPUP 降档, 内置端失去 linkage_alarm 帧的
 * has_linkage / linkage_actions 信息源; Show 时从 verdict 注入 (仅当帧原本
 * 无这些键, 不覆盖已有语义), 使 main.qml 分流 (severity>=3 || has_linkage)
 * 与 LinkageAlarmPopup 保持现状体验。
 *
 * 双帧去重 (R11): dispatch 线程推送顺序 linkage_alarm (callback 链联动触发)
 * 先于 alarm.new (pushWithRetry); 双写期两帧并存时, linkage_alarm 走兜底链
 * 弹窗后, alarm.new 的 Show 不再看本地防抖 → 同一告警双弹。alarm_id 级去重
 * (isRecentlyPopped/recordPopped/prunePopped) 供 Show/Fallback 弹窗前查询,
 * 弹窗成功即记录, 窗口内同 id 复现 → 跳过 (空 id 不参与)。
 *
 * 契约守门: scripts/ssot/validate_ssot.py CHECK 13。
 * 红线: 告警全部落库/列表可见 (判定只影响弹窗, 不影响列表)。
 */
#include <QHash>
#include <QVariantList>
#include <QVariantMap>

namespace AlarmVerdictConsumer {

/// 弹窗判定决策 (语义对齐 web 端 useGlobalAlarm 三态降级链)
enum class Decision {
    Fallback,           ///< 无 verdict: 现状兜底链 (本地防抖 → 弹窗)
    Suppress,           ///< matched=false: 整链静默, 不弹窗不改防抖图
    SuppressDebounced,  ///< matched && debounced: 后端防抖, 不弹窗但同步防抖图
    Show,               ///< matched && !debounced: 弹窗 (需先 enrichFromVerdict)
};

/// 提取帧内 linkage_verdict (非对象/缺失 → 空 map)
inline QVariantMap verdictOf(const QVariantMap& frame) {
    const QVariant v = frame.value(QStringLiteral("linkage_verdict"));
    if (!v.isValid())
        return {};
    // QJsonObject 经 toVariantMap 后为 QVariantMap; 字符串/数字等畸形形态拒绝
    if (v.metaType().id() != QMetaType::QVariantMap)
        return {};
    return v.toMap();
}

/// 三态决策 — 畸形帧防御口径同 web parseLinkageVerdict (非法形态 → 兜底链)
inline Decision decide(const QVariantMap& frame) {
    const QVariantMap verdict = verdictOf(frame);
    if (verdict.isEmpty())
        return Decision::Fallback;
    const QVariant matched = verdict.value(QStringLiteral("matched"));
    if (matched.metaType().id() != QMetaType::Bool)
        return Decision::Fallback;  // matched 缺失/类型非法 → 视同无判定
    if (!matched.toBool())
        return Decision::Suppress;
    const QVariant debounced = verdict.value(QStringLiteral("debounced"));
    if (debounced.metaType().id() == QMetaType::Bool && debounced.toBool())
        return Decision::SuppressDebounced;
    return Decision::Show;
}

/**
 * Show 时调用 — 从 verdict 注入联动形态字段 (对齐 linkage_alarm 帧):
 *   has_linkage     = matched && actions 非空 (决定 main.qml 分流联动弹窗)
 *   linkage_actions = verdict.actions (LinkageAlarmPopup 动作列表)
 *   auto_close_s    = verdict.auto_close_s (LinkageAlarmPopup 自动关闭秒)
 * 仅当帧原本无该键时注入, 不覆盖已有语义 (兼容双写期 linkage_alarm 帧)。
 */
inline void enrichFromVerdict(QVariantMap& frame) {
    const QVariantMap verdict = verdictOf(frame);
    if (verdict.isEmpty())
        return;
    const QVariantList actions = verdict.value(QStringLiteral("actions")).toList();
    if (!frame.contains(QStringLiteral("has_linkage")))
        frame.insert(QStringLiteral("has_linkage"), !actions.isEmpty());
    if (!frame.contains(QStringLiteral("linkage_actions")))
        frame.insert(QStringLiteral("linkage_actions"), actions);
    if (!frame.contains(QStringLiteral("auto_close_s"))) {
        const QVariant autoClose = verdict.value(QStringLiteral("auto_close_s"));
        if (autoClose.isValid())
            frame.insert(QStringLiteral("auto_close_s"), autoClose);
    }
}

/// 弹窗自动关闭秒: 帧 >0 值优先, 否则 fallback (0/缺失 = 组件默认)
inline int effectiveAutoCloseSeconds(const QVariantMap& frame, int fallbackSec) {
    bool ok = false;
    const int v = frame.value(QStringLiteral("auto_close_s")).toInt(&ok);
    return (ok && v > 0) ? v : fallbackSec;
}

// ── 双帧去重 (R11): linkage_alarm 与 alarm.new 同 alarm_id 双弹防护 ──────────

/// 该 alarm_id 是否在窗口内已弹过 (空 id / 窗口 <=0 → 不参与去重)
inline bool isRecentlyPopped(const QHash<QString, qint64>& recent,
                             const QString& alarmId, qint64 nowMs, qint64 windowMs) {
    if (alarmId.isEmpty() || windowMs <= 0)
        return false;
    const auto it = recent.constFind(alarmId);
    return it != recent.constEnd() && (nowMs - it.value()) < windowMs;
}

/// 弹窗成功时记录 alarm_id (空 id 不记录)
inline void recordPopped(QHash<QString, qint64>& recent,
                         const QString& alarmId, qint64 nowMs) {
    if (!alarmId.isEmpty())
        recent.insert(alarmId, nowMs);
}

/// 惰性清理过期条目 (每次消息入口调用一次, 防长期运行内存增长)
inline void prunePopped(QHash<QString, qint64>& recent, qint64 nowMs, qint64 windowMs) {
    if (windowMs <= 0)
        return;
    for (auto it = recent.begin(); it != recent.end();) {
        if (nowMs - it.value() >= windowMs)
            it = recent.erase(it);
        else
            ++it;
    }
}

}  // namespace AlarmVerdictConsumer
