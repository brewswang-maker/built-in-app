#!/bin/bash
# =============================================================================
# [M3-U3 2026-09-20] AXIS 超窗重置真机补测 (run2 中 U3 被外部重启打断后补测)
#
# 设计确定性: 新 rule_id (状态键含规则 id → 全新链状态); e4'(zone_a) 注入后
#   链起点 ≤ 注入+6s (dispatch 积压上限), e5'(zone_b) 于 +34s 注入 →
#   两条评估路径 (dryRun 同步 / dispatch 延迟) 的 gap 均 > 8s → 预期
#   "sequence expired, reset" 且不触发 (响应 m3_matched=False, 无 FIRED).
# 通过判据: ① journal 'sequence expired, reset' ② e5' 响应 m3_matched=False
#   ③ 无 '[FIRED] ... m3-axis-window' ④ cleanup DELETE ok
# 用法(设备): bash /home/linaro/m3_axis_window_test.sh
# =============================================================================
set -u
export PYTHONIOENCODING=utf-8
API=http://127.0.0.1:18080/api/v1
RID=m3-axis-window-20260920
CH=gb_34020000001320002001
ZA=m3_zone_a
ZB=m3_zone_b
GAP=8000
LOG_SINCE=$(date '+%F %T')
echo "[u3] ==== U3 超窗补测 $(date '+%F %T') ===="

ready=0
for i in $(seq 1 45); do
    if curl -s -m 3 "$API/linkage/engines/status" | grep -q '"engine_status"'; then
        ready=1; echo "[u3] service ready (attempt $i)"; break
    fi
    sleep 2
done
[ "$ready" = "1" ] || { echo "[u3][FATAL] service not ready after 90s"; exit 1; }

cleanup() {
    echo "[u3] -- cleanup: delete rule --"
    curl -s -X DELETE "$API/linkage/rules/$RID"; echo
}
trap cleanup EXIT

curl -s -X DELETE "$API/linkage/rules/$RID" >/dev/null 2>&1

echo "[u3] -- create rule (window-test) --"
curl -s -X POST "$API/linkage/rules" -H "Content-Type: application/json" -d "{
  \"id\": \"$RID\",
  \"name\": \"M3-AXIS超窗补测(临时)\",
  \"enabled\": true,
  \"priority\": 50,
  \"cooldown_ms\": 0,
  \"source_cond\": {\"event_types\": [\"climbing\"], \"min_severity\": 1, \"min_confidence\": 0},
  \"spatial_cond\": {\"sequence_json\": \"[{\\\"region_id\\\":\\\"$ZA\\\",\\\"max_gap_ms\\\":$GAP},{\\\"region_id\\\":\\\"$ZB\\\",\\\"max_gap_ms\\\":$GAP}]\"},
  \"actions\": [{\"type\": 200, \"name\": \"WEB_POPUP\", \"enabled\": true}]
}"
echo

inject() {
    curl -s -X POST "$API/linkage/rules/trigger-test" -H "Content-Type: application/json" -d "{
      \"alarm_type\": \"climbing\",
      \"channel_id\": \"$CH\",
      \"zone\": \"$1\",
      \"severity\": 2,
      \"confidence\": 0.9,
      \"skip_snapshot\": true
    }" | python3 -c "
import sys,json
try: d=json.load(sys.stdin).get('data',{})
except Exception: print('[$2] RESPONSE-INVALID (empty/non-JSON)'); sys.exit(0)
det=[r for r in d.get('rule_details',[]) if r.get('rule_id')=='$RID']
m=det[0] if det else {}
print('[$2] triggered=%s rules_matched=%s m3_matched=%s reason=%s' % (
  d.get('triggered'), d.get('rules_matched'), m.get('matched'), m.get('match_reason')))"
}

echo "[u3] == step1: e4'($ZA) 启动链 (期望日志 entered step 1/2) =="
inject "$ZA" "U3-e4"
echo "[u3] -- 34s 等待: dryRun 链起点=now, dispatch 链起点<=now+6s → 双路径超窗 --"
sleep 34
echo "[u3] == step2: e5'($ZB) 期望 expired reset 不触发 =="
inject "$ZB" "U3-e5"

echo "[u3] -- journal [AXIS-SEQ|FIRED] (since $LOG_SINCE) --"
sudo -n journalctl -u smartgateway --since "$LOG_SINCE" --no-pager | grep -E "AXIS-SEQ|FIRED|NO-FIRE" | tail -20

echo "[u3] ==== done $(date '+%F %T') ===="
