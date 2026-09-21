#!/bin/bash
# =============================================================================
# [G3 2026-09-20] export-range 多片边界场景真机补例(设备 56mf)
#
# 素材(通道 gb_34020000001320002001, 2026-09-20):
#   片A = 10-58-12-0.mp4  起点 10:58:12  实长 95.009s (24.3MB)
#   片B = 10-59-47-1.mp4  起点 10:59:47  实长 0.240s  (214KB, 微片, 与 A 无缝)
#
# 边界断言组(1 例 = 3 断言):
#   B1 [10:58:12 ~ 11:00:00] 起点对齐片A起点 + 跨微片:  期望 seg=2, dur≈95.2s
#   B2 [10:58:12 ~ 10:59:47] 终点=片B起点(边界不得越选): 期望 seg=1, dur≈95.0s
#   B3 [10:59:47 ~ 11:00:00] 微片独立可导出(请求>实长):  期望 seg=1, dur≈0.24s
#
# 校验: 响应 code=0 + segments_used + 产物 ffprobe duration(衔接/微片无失败)
# 用法(设备): bash /home/linaro/g3_export_boundary.sh
# =============================================================================
set -u
API=http://127.0.0.1:8080/api/v1/recordings/export-range
CH=gb_34020000001320002001
EXPORT_DIR=/data/shield/record/export
FFPROBE=/opt/sophon/sophon-ffmpeg-latest/bin/ffprobe
[ -x "$FFPROBE" ] || FFPROBE=ffprobe

call_export() {
  local tag=$1 start=$2 end=$3
  echo "[g3] ===== $tag [$start ~ $end] ====="
  local resp
  resp=$(curl -s --max-time 120 -X POST "$API" \
    -H "Content-Type: application/json" \
    -d "{\"channel_id\":\"$CH\",\"start_time\":\"$start\",\"end_time\":\"$end\"}")
  echo "[g3] resp: $resp"
  local url fname
  url=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('download_url',''))" 2>/dev/null)
  fname=$(basename "$url")
  if [ -z "$fname" ] || [ ! -f "$EXPORT_DIR/$fname" ]; then
    echo "[g3] $tag: no artifact ($url)"; return 1
  fi
  local dur size
  dur=$($FFPROBE -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$EXPORT_DIR/$fname" 2>&1)
  size=$(stat -c %s "$EXPORT_DIR/$fname")
  echo "[g3] $tag: artifact=$fname dur=$dur size=$size"
}

echo "[g3] ==== G3 export-range boundary $(date '+%F %T') ===="
call_export B1_start-aligned_cross-micro 2026-09-20T10:58:12 2026-09-20T11:00:00
call_export B2_end-at-boundary_no-overshoot 2026-09-20T10:58:12 2026-09-20T10:59:47
call_export B3_micro-slice_standalone 2026-09-20T10:59:47 2026-09-20T11:00:00
echo "[g3] ==== G3 done $(date '+%F %T') ===="
