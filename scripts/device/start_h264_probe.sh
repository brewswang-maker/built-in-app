#!/bin/bash
# =============================================================================
# [S3-5 2026-09-20] 设备端 H264 测试流启动脚本(webrtc_render_probe 用)
# 用法(设备上): ./start_h264_probe.sh [v4l2|bm]
#   默认 v4l2 (h264_v4l2m2m); bm = h264_bm 硬编。
#   向本机 ZLM(554) 推流 rtp/h264probe, 供 WHEP 拉流验证。
# =============================================================================
set -u
ENC=${1:-v4l2}
FF=/opt/sophon/sophon-ffmpeg-latest/bin/ffmpeg
URL=rtsp://127.0.0.1:554/rtp/h264probe

pkill -f "rtp/h264probe" 2>/dev/null
pkill -f testsrc2 2>/dev/null
sleep 1

if [ "$ENC" = "bm" ]; then
  CENC="h264_bm"
else
  CENC="h264_v4l2m2m"
fi

nohup $FF -hide_banner -re -f lavfi -i testsrc2=size=1280x720:rate=25 \
  -vf format=nv12 -c:v $CENC -g 50 -b:v 2000k \
  -f rtsp -rtsp_transport tcp "$URL" > /tmp/h264probe_ffmpeg.log 2>&1 &

echo "started encoder=$CENC pid=$!"
sleep 7
echo "--- log tail ---"
tail -10 /tmp/h264probe_ffmpeg.log
echo "--- mediameta ---"
curl -s "http://127.0.0.1:9080/index/api/getMediaList?secret=InL0XIf4gxTfI2xeaC5fQIhRQwU0GSEU&app=rtp&stream=h264probe" | head -c 1200
echo
