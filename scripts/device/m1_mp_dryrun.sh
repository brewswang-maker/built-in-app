#!/bin/bash
# =============================================================================
# [M1 2026-09-20] MP 类动作(400-402) dry-run 预检真机实测(设备 56mf)
#
# 链路: POST /api/v1/linkage/rules (创建含 3 个 MP 动作的临时规则)
#   → POST /api/v1/linkage/rules/dry-run (命中 + 对照 两用例)
#   → DELETE /api/v1/linkage/rules/:id (清理)
# 断言: 命中用例 matched=true 且 simulated_actions 含 3 个 MP 动作名;
#   对照用例 matched=false (alarm_type 不匹配); 全程无真实动作执行(dry-run 语义)。
# 用法(设备): bash /home/linaro/m1_mp_dryrun.sh
# =============================================================================
set -u
API=http://127.0.0.1:18080/api/v1
RID=m1-mp-dryrun-test-20260920

echo "[m1] ==== M1 MP dry-run $(date '+%F %T') ===="

# 0. 清残留(幂等, 上次异常退出时)
curl -s -X DELETE "$API/linkage/rules/$RID" > /dev/null 2>&1

# 1. 创建含 3 个 MP 动作的临时规则
echo "[m1] -- create rule (MP_SUBSCRIBE_MSG/MP_SHOW_IMAGE/MP_SHOW_LIVE) --"
curl -s -X POST "$API/linkage/rules" -H "Content-Type: application/json" -d '{
  "id": "m1-mp-dryrun-test-20260920",
  "name": "M1-MP动作dry-run预检(临时)",
  "enabled": true,
  "priority": 50,
  "cooldown_ms": 0,
  "source_cond": {"event_types": ["intrusion"], "min_severity": 1, "min_confidence": 0.0},
  "actions": [
    {"type": 400, "name": "小程序订阅消息", "enabled": true, "params": {"template_id": "m1_test_tpl_v1"}},
    {"type": 401, "name": "小程序事件图片", "enabled": true},
    {"type": 402, "name": "小程序实时视频", "enabled": true}
  ]
}'
echo

# 2. dry-run 命中用例 (intrusion)
echo "[m1] -- dry-run HIT (alarm_type=intrusion) --"
curl -s -X POST "$API/linkage/rules/dry-run" -H "Content-Type: application/json" -d '{
  "alarm_type": "intrusion",
  "channel_id": "gb_34020000001320002001",
  "rule_id": "m1-mp-dryrun-test-20260920",
  "confidence": 0.9, "severity": 2
}'
echo

# 3. dry-run 对照 (abandoned 不匹配)
echo "[m1] -- dry-run MISS (alarm_type=abandoned) --"
curl -s -X POST "$API/linkage/rules/dry-run" -H "Content-Type: application/json" -d '{
  "alarm_type": "abandoned",
  "channel_id": "gb_34020000001320002001",
  "rule_id": "m1-mp-dryrun-test-20260920",
  "confidence": 0.9, "severity": 2
}'
echo

# 4. 清理临时规则
echo "[m1] -- delete rule (cleanup) --"
curl -s -X DELETE "$API/linkage/rules/$RID"
echo
echo "[m1] ==== M1 done $(date '+%F %T') ===="
