#!/bin/bash
# =============================================================================
# [M3 2026-09-20] AXIS 时序规则(顺序穿越链)真机多事件触发实测 (设备 56mf)
#
# 链路: POST /api/v1/linkage/rules (创建 climbing 类型临时时序规则 A->B gap 8s)
#   → POST /api/v1/linkage/rules/trigger-test x5 (带 zone 多事件注入; 缺省
#     via_dispatcher=false 直连 reportAlarm → BoxService 回调 → LinkageEngine
#     真实触发链, region_id=alarm.zone 透传; skip_snapshot 免抓图)
#   → 证据: journalctl [AXIS-SEQ] 日志 + engines/status total_triggers 增量
#     + GET /linkage/action-log?rule_id= (动作执行记录)
#   → DELETE /api/v1/linkage/rules/:id (清理, trap 兜底)
#
# 三用例:
#   U1 正向: e1(zone_a) 启动链 → 2s → e2(zone_b) 链完成 → 应触发 (complete+FIRED)
#   U2 反向: e3(zone_b) 链未启动不推进 → e4(zone_a) 启动链但不完成 → 均不触发
#   U3 超窗: e4 链启动后等待 > 双路径超窗阈值 (>8s 且覆盖 dispatch 积压 max 6s)
#     → e5(zone_b) → expired reset, 不触发
#
# [run1 迭代 v2 2026-09-20] run1 发现: AlarmService 落库队列积压 (queue_ms 达 6057ms)
#   使 dispatch 侧真实 trigger 评估较注入时刻迟 ~6s → 链起点后移, 原 U3 的
#   sleep 12 仅覆盖 dryRun 路径超窗, dispatch 路径 gap≈6s 未超窗 → 意外 complete.
#   v2: e4 后显式两段等待 (15s 排空 dispatch + 18s 双路径超窗), 并给 U1 后加
#   15s drain 确保 e2 的 FIRED 来自其自身链 (避免跨用例拼接).
#
# 通过判据(硬):
#   ① journal 出现 "sequence complete (2 steps" (U1) 与 "sequence expired, reset" (U3)
#   ② engines/status total_triggers 增量 >= 1
#   ③ action-log?rule_id=$RID 有 WEB_POPUP 动作记录
# 类型选择: climbing — 设备已知类型; 唯一 climbing 规则"周界攀爬翻越"已禁用,
#   本临时规则自身 enabled 提供订阅(过 isAlarmTypeSubscribed 闸门), 零额外副作用.
# 用法(设备): bash /home/linaro/m3_axis_trigger.sh
# =============================================================================
set -u
export PYTHONIOENCODING=utf-8
API=http://127.0.0.1:18080/api/v1
RID=m3-axis-e2e-20260920
CH=gb_34020000001320002001
ZA=m3_zone_a
ZB=m3_zone_b
GAP=8000

LOG_SINCE=$(date '+%F %T')
echo "[m3] ==== M3 AXIS 时序真机多事件触发 $(date '+%F %T') ===="

status_num() {  # $1=字段名 取 engines/status 数值 (失败时输出空并提示)
    curl -s -m 5 "$API/linkage/engines/status" | python3 -c \
        "import sys,json
try: print(json.load(sys.stdin)['data']['$1'])
except Exception: print('')" 2>/dev/null
}

inject() {  # $1=zone $2=tag ; 输出单行摘要
    curl -s -X POST "$API/linkage/rules/trigger-test" -H "Content-Type: application/json" -d "{
      \"alarm_type\": \"climbing\",
      \"channel_id\": \"$CH\",
      \"zone\": \"$1\",
      \"severity\": 2,
      \"confidence\": 0.9,
      \"skip_snapshot\": true
    }" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin).get('data',{})
except Exception:
    print('[$2] RESPONSE-INVALID (empty/non-JSON)'); sys.exit(0)
det=[r for r in d.get('rule_details',[]) if r.get('rule_id')=='$RID']
m=det[0] if det else {}
print('[$2] triggered=%s rules_matched=%s m3_matched=%s reason=%s' % (
  d.get('triggered'), d.get('rules_matched'), m.get('matched'), m.get('match_reason')))"
}

cleanup() {
    echo "[m3] -- cleanup: delete rule --"
    curl -s -X DELETE "$API/linkage/rules/$RID"; echo
}
trap cleanup EXIT

echo "[m3] -- wait service ready --"
# 设备曾出现测试窗口内 systemd 重启服务 (2026-09-20 12:16 实测) → 请求全空.
# 就绪判据: engines/status 返回合法 JSON (最多等 90s)
ready=0
for i in $(seq 1 45); do
    if curl -s -m 3 "$API/linkage/engines/status" | grep -q '"engine_status"'; then
        ready=1; echo "[m3] service ready (attempt $i)"; break
    fi
    sleep 2
done
if [ "$ready" != "1" ]; then
    echo "[m3][FATAL] service not ready after 90s — abort"; exit 1
fi

echo "[m3] -- baseline --"
TR0=$(status_num total_triggers)
echo "[m3] total_triggers(before)=$TR0"
curl -s -X DELETE "$API/linkage/rules/$RID" >/dev/null 2>&1   # 幂等清残留

echo "[m3] -- create temporal rule (climbing / A->B / gap ${GAP}ms) --"
curl -s -X POST "$API/linkage/rules" -H "Content-Type: application/json" -d "{
  \"id\": \"$RID\",
  \"name\": \"M3-AXIS时序真机触发(临时)\",
  \"enabled\": true,
  \"priority\": 50,
  \"cooldown_ms\": 0,
  \"source_cond\": {\"event_types\": [\"climbing\"], \"min_severity\": 1, \"min_confidence\": 0},
  \"spatial_cond\": {\"sequence_json\": \"[{\\\"region_id\\\":\\\"$ZA\\\",\\\"max_gap_ms\\\":$GAP},{\\\"region_id\\\":\\\"$ZB\\\",\\\"max_gap_ms\\\":$GAP}]\"},
  \"actions\": [{\"type\": 200, \"name\": \"WEB_POPUP\", \"enabled\": true}]
}"
echo

echo "[m3] == U1 正向: e1($ZA) -> e2($ZB) 应完成链并触发 =="
inject "$ZA" "U1-e1"
sleep 2
inject "$ZB" "U1-e2"
# 快速自诊断: 首步日志若缺席 (闸门/类型问题) 立即提示
if ! sudo -n journalctl -u smartgateway --since "$LOG_SINCE" --no-pager 2>/dev/null | grep -q "AXIS-SEQ"; then
    echo "[m3][WARN] 未见 [AXIS-SEQ] 日志 — 疑似闸门/类型拦截, 后续日志统一分析"
fi
# drain: 排空 U1 的 dispatch 积压 (run1 实测最大 ~6s), 确保 e2 的 FIRED
# 归属其自身链 (dryRun complete → dispatch 短路 true → 动作执行)
echo "[m3] -- drain 15s (flush U1 dispatch backlog) --"
sleep 15

echo "[m3] == U2 反向: e3($ZB) 不启动链 -> e4($ZA) 启动但不完成 =="
inject "$ZB" "U2-e3"
sleep 1
inject "$ZA" "U2-e4"

echo "[m3] == U3 超窗: 先 15s 排空 e3/e4 dispatch, 再 18s 双路径超窗 -> e5($ZB) =="
# e4 注入 T; dryRun 链起点≈T, dispatch 链起点≤T+6s; e5 于 T+34s →
# 两路径 gap 均 >8s → 预期 expired reset (无 complete/FIRED)
sleep 15
sleep 18
inject "$ZB" "U3-e5"

echo "[m3] -- counters --"
TR1=$(status_num total_triggers)
if [ -n "$TR0" ] && [ -n "$TR1" ]; then
    echo "[m3] total_triggers(after)=$TR1 delta=$((TR1-TR0))  (期望=1, 仅 U1 完成链)"
else
    echo "[m3] total_triggers(after)=$TR1 delta=N/A (counter query failed)"
fi

echo "[m3] -- action-log (rule_id=$RID) --"
curl -s "$API/linkage/action-log?rule_id=$RID&page_size=10"; echo

echo "[m3] -- journal [AXIS-SEQ] (since $LOG_SINCE) --"
sudo -n journalctl -u smartgateway --since "$LOG_SINCE" --no-pager | grep -E "AXIS-SEQ|$RID" | tail -30

echo "[m3] ==== M3 done $(date '+%F %T') ===="
