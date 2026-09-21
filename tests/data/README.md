# 测试数据 (内置端)

[S3-1 2026-09-20]

| 文件 | 说明 |
|------|------|
| `h264_90f.h264` | H264 Annex-B 码流 (90 帧, 692KB), 供 WebRtcClient/H264Decoder 解码单测。含 SPS/PPS/IDR ×1 + P 帧 ×89 |
| `avcc_to_annexb.py` | 格式转换脚本 (AVCC 4 字节长度前缀 → Annex-B 起始码), 依赖 Python 标准库 |

## h264_90f.h264 来源与再生成

来源: libdatachannel v0.24.5 `examples/streamer/samples/h264/` 前 90 帧
(见 `../../3rdparty/libdatachannel/VENDORED.md`), 原始为 AVCC 长度前缀格式, 转换命令:

```bash
python3 avcc_to_annexb.py <libdatachannel>/examples/streamer/samples/h264 h264_90f.h264 90
```

注意: 上游 vendored 树中的 samples 已裁剪, 再生成需从上游 tarball 取回对应目录。
