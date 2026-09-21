#!/bin/bash
# =============================================================================
# [G1 2026-09-20] 降级链真机故障注入实验(iptables DROP 网络层断流)
#
# 设计: 探针(offscreen+软渲染, --qml --chain)连本机 ZLM WHEP;
#   t=+10s 在 OUTPUT 链 DROP 掉 ZLM(sport 8000)→客户端方向的 UDP 大包
#   (SRTP 视频包 >=300B), 客户端→ZLM 方向(RTCP/PLI/STUN)与 STUN consent
#   响应(<300B)均放行 —— 视频断流但 ICE consent 不超时;
#   t=+35s 撤销 DROP, 观察 IDR 恢复 → RECOVERED + chain reset。
#   注: 仅按 sport 全丢会在 30s 后触发 libjuice CONSENT_TIMEOUT(RFC 7675)
#   判死 PeerConnection(首版实测 ICE/DTLS Failed), 故改按包长过滤。
#   保险: trap EXIT 强制撤销 DROP(防 SSH 中断残留规则)。
#
# 素材: /home/linaro/h264probe_20x.h264 (20x90 帧 Annex-B, 25fps, ~72s)
# 用法(设备): bash /home/linaro/g1_fault_inject.sh
# 退出: 0=实验完成(证据待分析)  非0=准备失败
# =============================================================================
set -u
FF_PROBE=/home/linaro/webrtc_render_probe
PROBE_LOG=/tmp/g1_probe.log
DROP_RULE="-p udp --sport 8000 -m length --length 300:65535 -j DROP"

dump_drop() { sudo -n iptables -L OUTPUT -n --line-numbers | grep -E 'DROP|num' || true; }
drop_remove() { sudo -n iptables -D OUTPUT $DROP_RULE 2>/dev/null || true; }

cleanup() {
  drop_remove
  echo "[g1] cleanup: DROP removed at $(date '+%H:%M:%S')"
}
trap cleanup EXIT INT TERM

echo "[g1] ==== G1 start $(date '+%F %T') ===="

# ── 0. 幂等清理 ──
# 残留 DROP 规则(上次异常退出)
drop_remove
# 旧推流进程(pgrep -x + /proc 过滤, 避免 pkill -f 自匹配 SSH)
for p in $(pgrep -x ffmpeg); do
  cmd=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null || true)
  case "$cmd" in *h264probe*) echo "[g1] kill stale publisher pid=$p"; kill "$p" 2>/dev/null;; esac
done
sleep 1

# ── 1. 起流(20x 文件, 实时速率 ~72s) ──
echo "[g1] starting publisher (20x)..."
SRC=/home/linaro/h264probe_20x.h264 bash /home/linaro/start_file_probe.sh || {
  echo "[g1] publisher start FAILED"; exit 1; }
if ! pgrep -x ffmpeg >/dev/null; then echo "[g1] no ffmpeg after start"; exit 1; fi

# ── 2. 起探针(55s, 后台) ──
cd /home/linaro
export LD_LIBRARY_PATH=/data/shieldbox/qt6-runtime/lib:/opt/sophon/sophon-ffmpeg-latest/lib
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
setsid "$FF_PROBE" \
  'webrtc://127.0.0.1:9080/index/api/webrtc?app=rtp&stream=h264probe' \
  /home/linaro/g1_final.png 55 --qml --chain > "$PROBE_LOG" 2>&1 &
PROBE_PID=$!
echo "[g1] probe pid=$PROBE_PID log=$PROBE_LOG"

# ── 3. 故障时间轴 ──
sleep 10
if ! kill -0 "$PROBE_PID" 2>/dev/null; then echo "[g1] probe died early"; exit 1; fi
sudo -n iptables -I OUTPUT 1 $DROP_RULE
echo "[g1] t=+10s DROP inserted $(date '+%H:%M:%S')"
dump_drop

sleep 25
drop_remove
echo "[g1] t=+35s DROP removed $(date '+%H:%M:%S')"
dump_drop

# ── 4. 等探针结束(55s 总时长 + 收尾) ──
wait "$PROBE_PID"
PRC=$?
echo "[g1] probe exit=$PRC"

echo "[g1] ==== chain/STALL evidence ===="
grep -E 'STALL|RECOVERED|advance|reset|active=|PROBE_RESULT|FIRST_FRAME|streamFailed|requestKeyframe' "$PROBE_LOG" || echo "(no chain lines!)"
echo "[g1] ==== G1 done $(date '+%F %T') ===="
exit 0
