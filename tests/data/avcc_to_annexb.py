#!/usr/bin/env python3
# S3-1 [2026-09-20] 将 libdatachannel streamer 样本 (AVCC 4字节长度前缀) 转为 Annex-B, 供内置端解码单测
# 用法: python3 avcc_to_annexb.py <in_dir> <out_file> <max_frames>
import sys, os, struct

in_dir, out_file, max_frames = sys.argv[1], sys.argv[2], int(sys.argv[3])
files = sorted(os.listdir(in_dir), key=lambda n: int(n.split('-')[1].split('.')[0]))[:max_frames]

out = bytearray()
count = 0
for name in files:
    data = open(os.path.join(in_dir, name), 'rb').read()
    off = 0
    while off + 4 <= len(data):
        ln = struct.unpack('>I', data[off:off+4])[0]
        if ln == 0 or off + 4 + ln > len(data):
            break
        out += b'\x00\x00\x00\x01'
        out += data[off+4:off+4+ln]
        off += 4 + ln
    if off != len(data):
        print(f'WARN {name}: parsed {off}/{len(data)} bytes')
    count += 1

open(out_file, 'wb').write(out)

# 校验: 起始码 + NAL 类型统计
import re
starts = [m.start() for m in re.finditer(b'\x00\x00\x00\x01', bytes(out))]
types = {}
for p in starts:
    if p + 4 < len(out):
        t = out[p+4] & 0x1F
        types[t] = types.get(t, 0) + 1
print(f'frames={count} bytes={len(out)} start_codes={len(starts)} nal_types={sorted(types.items())}')
