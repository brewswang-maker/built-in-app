#\!/bin/bash
# [G1 2026-09-20] 10fps 等效推流: itsscale 2.5 将 25fps 源时间戳拉伸;
# 端侧软解 ~11fps, 10fps 源无解码积压, 断流可在 3 秒内被 STALL 检测捕获
exec /opt/sophon/sophon-ffmpeg-latest/bin/ffmpeg -itsscale 2.5 -re -f h264 \
  -i /home/linaro/h264probe_10x.h264 -c copy -f rtsp -rtsp_transport tcp \
  rtsp://127.0.0.1:554/rtp/h264probe
