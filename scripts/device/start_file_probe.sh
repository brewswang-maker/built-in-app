#!/bin/bash
# =============================================================================
# [S3-5 2026-09-20] 设备端 H264 文件流拷贝推送(无本地 H264 编码器时的方案)
# 用法(设备上): ./start_file_probe.sh
#   将上传的 /home/linaro/h264probe_10x.h264 (90帧x10, Annex-B, 25fps)
#   以流拷贝方式推入本机 ZLM(rtp/h264probe), 供 WHEP 拉流验证。
#   返回 publisher PID 与流状态。
# =============================================================================
set -u
FF=/opt/sophon/sophon-ffmpeg-latest/bin/ffmpeg
SRC=${SRC:-/home/linaro/h264probe_10x.h264}

pkill -f "rtp/h264probe" 2>/dev/null
pkill -f "$SRC" 2>/dev/null
sleep 1

nohup $FF -hide_banner -re -r 25 -f h264 -i "$SRC" -c copy \
  -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:554/rtp/h264probe \
  > /tmp/h264probe_ffmpeg.log 2>&1 &
PUB_PID=$!
echo "publisher pid=$PUB_PID src=$SRC"
sleep 6
echo "--- log tail ---"
tail -6 /tmp/h264probe_ffmpeg.log
echo "--- mediameta ---"
curl -s "http://127.0.0.1:9080/index/api/getMediaList?secret=InL0XIf4gxTfI2xeaC5fQIhRQwU0GSEU&app=rtp&stream=h264probe" | head -c 1500
echo
