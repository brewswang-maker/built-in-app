// tests/test_alarm_verdict_consumer.cpp
//
// AlarmVerdictConsumer 单测 — [SSOT R10 2026-09-12] 内置端单判定源消费
// (docs/plans/rule-algo-popup-ssot-refactor-v1.0.md §5.1 + §8.1 操作门第 2 点)
//
// 覆盖矩阵 (11 用例):
//   ① 无 verdict            → Fallback (现状兜底链, 零回归)
//   ② 畸形 verdict          → Fallback (字符串/数组/matched 非 bool, 同 web parseLinkageVerdict)
//   ③ matched=false         → Suppress (整链静默)
//   ④ matched && debounced  → SuppressDebounced (后端防抖)
//   ⑤ matched && !debounced → Show
//   ⑥ Show 富化             → has_linkage/linkage_actions/auto_close_s 注入
//   ⑦ 富化不覆盖已有键      → 双写期 linkage_alarm 帧语义保留
//   ⑧ actions 空            → has_linkage 显式 false (普通弹窗分流)
//   ⑨ 有效自动关闭秒        → >0 优先, 0/缺失回落 fallback
//   ⑩ 双帧去重判定 (R11)    → 窗口命中/过期/他 id/空 id/窗口 0
//   ⑪ 去重图清理 (R11)      → 仅清过期条目, 窗口 0 不清理
//
// 验收标准:
//   ctest -R test_alarm_verdict_consumer -V → PASSED
//   ./test_alarm_verdict_consumer           → exit 0

#include "utils/AlarmVerdictConsumer.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QtTest>

using AlarmVerdictConsumer::Decision;

namespace {

/// 构造与后端 alarm.new 帧同构的 QVariantMap (经 QJsonObject::toVariantMap,
/// 与 AlarmController::onWsTextMessage 实际解析路径一致)
QVariantMap makeFrame(const QJsonObject& verdict, bool withVerdict = true,
                      const QJsonObject& existing = {}) {
    QJsonObject frame;
    frame["type"] = "alarm.new";
    frame["alarm_id"] = "a-1001";
    frame["alarm_type"] = "intrusion";
    frame["severity"] = 4;
    frame["channel_id"] = "34020000001320000101";
    if (withVerdict)
        frame["linkage_verdict"] = verdict;
    for (auto it = existing.begin(); it != existing.end(); ++it)
        frame[it.key()] = it.value();
    return frame.toVariantMap();
}

QJsonObject baseVerdict(bool matched, bool debounced) {
    QJsonObject v;
    v["matched"] = matched;
    v["debounced"] = debounced;
    v["rule_id"] = "rule_ssot_r10";
    v["rule_name"] = "R10 契约规则";
    v["priority"] = 80;
    v["auto_close_s"] = 30;
    QJsonArray actions;
    QJsonObject act;
    act["type"] = 200;
    act["name"] = "Web弹窗";
    act["enabled"] = true;
    actions.append(act);
    v["actions"] = actions;
    return v;
}

}  // namespace

class TestAlarmVerdictConsumer : public QObject {
    Q_OBJECT

private slots:
    // ① 无 verdict → Fallback (旧后端 / verdict_push_enabled=false 回退态)
    void noVerdictIsFallback() {
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame({}, false)),
                 Decision::Fallback);
        // 显式 null 值同样视同缺失
        QVariantMap frame = makeFrame({}, false);
        frame["linkage_verdict"] = QVariant();  // Null 形态
        QCOMPARE(AlarmVerdictConsumer::decide(frame), Decision::Fallback);
    }

    // ② 畸形 verdict → Fallback (防御口径同 web parseLinkageVerdict)
    void malformedVerdictIsFallback() {
        QVariantMap frame = makeFrame({}, false);
        frame["linkage_verdict"] = QStringLiteral("oops");  // 字符串
        QCOMPARE(AlarmVerdictConsumer::decide(frame), Decision::Fallback);

        // matched 非 bool (字符串 "true") → 视同无判定
        QJsonObject bad = baseVerdict(true, false);
        bad["matched"] = "true";
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(bad)), Decision::Fallback);

        // matched 缺失 → Fallback
        QJsonObject missing = baseVerdict(true, false);
        missing.remove("matched");
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(missing)),
                 Decision::Fallback);
    }

    // ③ matched=false → Suppress (弹窗总闸关闭, 列表仍由上层照常刷新)
    void unmatchedSuppresses() {
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(baseVerdict(false, false))),
                 Decision::Suppress);
    }

    // ④ matched && debounced → SuppressDebounced (后端防抖窗口内复发)
    void debouncedSuppresses() {
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(baseVerdict(true, true))),
                 Decision::SuppressDebounced);
    }

    // ⑤ matched && !debounced → Show; debounced 缺失按 false (同 web falsy)
    void matchedShows() {
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(baseVerdict(true, false))),
                 Decision::Show);
        QJsonObject noDeb = baseVerdict(true, false);
        noDeb.remove("debounced");
        QCOMPARE(AlarmVerdictConsumer::decide(makeFrame(noDeb)), Decision::Show);
    }

    // ⑥ Show 富化: has_linkage/linkage_actions/auto_close_s 注入 (对齐 linkage_alarm 帧)
    void matchedShowsAndEnriches() {
        QVariantMap frame = makeFrame(baseVerdict(true, false));
        QVERIFY(!frame.contains("has_linkage"));  // alarm.new 主帧原无此键
        AlarmVerdictConsumer::enrichFromVerdict(frame);
        QCOMPARE(frame.value("has_linkage").toBool(), true);
        QCOMPARE(frame.value("linkage_actions").toList().size(), 1);
        QCOMPARE(frame.value("auto_close_s").toInt(), 30);
    }

    // ⑦ 富化不覆盖已有键 (双写期 linkage_alarm 帧语义保留; auto_close_s=0 不改写)
    void enrichDoesNotOverrideExisting() {
        QJsonObject existing;
        existing["has_linkage"] = true;
        existing["linkage_actions"] = QJsonArray();  // 已有键 (空数组) 不覆盖
        existing["auto_close_s"] = 0;
        QVariantMap frame = makeFrame(baseVerdict(true, false), true, existing);
        AlarmVerdictConsumer::enrichFromVerdict(frame);
        QCOMPARE(frame.value("has_linkage").toBool(), true);
        QVERIFY(frame.value("linkage_actions").toList().isEmpty());  // 保持已有空数组
        QCOMPARE(frame.value("auto_close_s").toInt(), 0);           // 保持已有 0
    }

    // ⑧ actions 为空时 has_linkage 显式 false (main.qml 分流走普通弹窗)
    void emptyActionsNoLinkageFlag() {
        QJsonObject v = baseVerdict(true, false);
        v["actions"] = QJsonArray();
        QVariantMap frame = makeFrame(v);
        QCOMPARE(AlarmVerdictConsumer::decide(frame), Decision::Show);
        AlarmVerdictConsumer::enrichFromVerdict(frame);
        QCOMPARE(frame.value("has_linkage").toBool(), false);
    }

    // ⑨ 有效自动关闭秒: >0 优先, 0/缺失/非数字回落 fallback
    void effectiveAutoCloseSeconds() {
        QJsonObject existing;
        existing["auto_close_s"] = 45;
        QCOMPARE(AlarmVerdictConsumer::effectiveAutoCloseSeconds(
                     makeFrame({}, false, existing), 60),
                 45);
        QJsonObject zero;
        zero["auto_close_s"] = 0;
        QCOMPARE(AlarmVerdictConsumer::effectiveAutoCloseSeconds(
                     makeFrame({}, false, zero), 60),
                 60);
        QCOMPARE(AlarmVerdictConsumer::effectiveAutoCloseSeconds(
                     makeFrame({}, false), 15),
                 15);
    }

    // ⑩ 双帧去重判定: 窗口命中/过期/他 id/空 id/窗口 0 (R11)
    void popupDedupWithinWindow() {
        QHash<QString, qint64> recent;
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, "a-1001", 2000, 30000),
                 false);
        AlarmVerdictConsumer::recordPopped(recent, "a-1001", 1000);
        // 窗口内 (29999 < 30000) → 命中; 达窗 (>= 30000) → 未命中
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, "a-1001", 30999, 30000),
                 true);
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, "a-1001", 31000, 30000),
                 false);
        // 他 id 不误伤; 空 id 不参与 (不记录/不命中); 窗口 <=0 不参与
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, "a-2002", 2000, 30000),
                 false);
        AlarmVerdictConsumer::recordPopped(recent, QString(), 1000);
        QCOMPARE(recent.contains(QString()), false);
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, QString(), 2000, 30000),
                 false);
        QCOMPARE(AlarmVerdictConsumer::isRecentlyPopped(recent, "a-1001", 1001, 0),
                 false);
    }

    // ⑪ prunePopped: 仅清过期条目, 窗口内保留; 窗口 0 不清理 (R11)
    void pruneDropsOnlyExpired() {
        QHash<QString, qint64> recent;
        AlarmVerdictConsumer::recordPopped(recent, "old", 1000);
        AlarmVerdictConsumer::recordPopped(recent, "new", 50000);
        AlarmVerdictConsumer::prunePopped(recent, 31000, 30000);
        QCOMPARE(recent.contains("old"), false);  // 30000 >= 30000 → 清
        QCOMPARE(recent.contains("new"), true);   // 窗口内保留
        AlarmVerdictConsumer::prunePopped(recent, 31000, 0);  // 窗口 0 → 不清理
        QCOMPARE(recent.contains("new"), true);
    }
};

QTEST_MAIN(TestAlarmVerdictConsumer)
#include "test_alarm_verdict_consumer.moc"
