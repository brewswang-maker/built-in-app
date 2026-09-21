#!/bin/bash
# =============================================================================
# [G2 2026-09-20] 真机 ZLM 首帧延迟复测(隧道设备, 4 路真实流)
#
# 流集合(≥4 路):
#   - gb_34020000001320002001 / gb_34020000001320002002 (设备在网摄像头)
#   - h264probe / h264probe2 (20x 文件流拷贝推送, 每路 ~72s 窗口)
# 测量: 真机模式(bench --base-url) HLS playlist / FLV header 首字节延迟,
#   每(流×协议) 3 样本 = 24 样本; 落盘 /home/linaro/bench_real.json。
# 用法(设备): bash /home/linaro/g2_real_bench.sh
# 退出: bench 退出码(0=PASS p95<2000ms)
# =============================================================================
set -u
FF=/opt/sophon/sophon-ffmpeg-latest/bin/ffmpeg
SRC=/home/linaro/h264probe_20x.h264
SECRET=InL0XIf4gxTfI2xeaC5fQIhRQwU0GSEU

kill_probes() {
  for p in $(pgrep -x ffmpeg); do
    cmd=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null || true)
    case "$cmd" in *h264probe*) kill "$p" 2>/dev/null;; esac
  done
}
trap kill_probes EXIT INT TERM

echo "[g2] ==== G2 real bench $(date '+%F %T') ===="
kill_probes; sleep 1

# ── 1. 推 2 路文件流(72s 窗口) ──
nohup $FF -hide_banner -re -r 25 -f h264 -i "$SRC" -c copy \
  -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:554/rtp/h264probe \
  > /tmp/g2_pub1.log 2>&1 &
nohup $FF -hide_banner -re -r 25 -f h264 -i "$SRC" -c copy \
  -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:554/rtp/h264probe2 \
  > /tmp/g2_pub2.log 2>&1 &
sleep 6

# ── 2. 流在线确认 ──
echo "[g2] online streams:"
curl -s "http://127.0.0.1:9080/index/api/getMediaList?secret=$SECRET&app=rtp" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(sorted({i['stream'] for i in d.get('data',[])}))"

# ── 3. HLS/FLV 预热(促 ZLM 生成 m3u8 与首个切片) ──
for s in gb_34020000001320002001 gb_34020000001320002002 h264probe h264probe2; do
  curl -s -o /dev/null --max-time 5 "http://127.0.0.1:9080/rtp/$s/hls.m3u8"
done
sleep 2

# ── 4. 真机复测 ──
cd /home/linaro
python3 first_frame_latency_bench.py \
  --base-url http://127.0.0.1:9080 \
  --stream-ids gb_34020000001320002001,gb_34020000001320002002,h264probe,h264probe2 \
  --protocols hls,flv --repeat 3 --concurrency 8 \
  --output /home/linaro/bench_real.json --verbose
RC=$?
echo "[g2] bench rc=$RC  $(date '+%F %T')"
echo "[g2] ==== G2 done ===="
exit $RC
