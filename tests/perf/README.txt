================================================================================
P0-2 First-Frame Latency Benchmark - 运行说明
================================================================================

目的:
  测量 SmartGateWay 流媒体首帧延迟,作为 P0-1 WebRTC/降级链改造后的回归基准。
  64路 1080P 并发预算: P95 < 2000ms (验收门)。

架构 (两层基准):
  ┌──────────────────────────────────────────────────────────────┐
  │ L1 同步组件基准 (C++ Qt Test)                                  │
  │   tests/test_first_frame_latency.cpp                         │
  │   测量: JSON 解析, 链规范化, 协议选择, 探测超时, 64路批量     │
  │   验收: ctest -V 或 ./build/test_first_frame_latency         │
  ├──────────────────────────────────────────────────────────────┤
  │ L2 端到端压测 (Python + mock ZLM)                              │
  │   mock_zlm_server.py          — 模拟 ZLM 4 协议响应延迟        │
  │   first_frame_latency_bench.py — 端到端 P50/P95/P99 测量       │
  │   run_bench.sh                — 一键运行脚本                  │
  │   验收: ./run_bench.sh 64 hls,flv,webrtc                      │
  └──────────────────────────────────────────────────────────────┘

文件清单:
  mock_zlm_server.py            ZLM mock server (Python stdlib)
  first_frame_latency_bench.py  端到端压测驱动 (Python stdlib)
  run_bench.sh                  一键运行脚本
  README.txt                    本文件
  bench_report.json             压测报告 (运行后生成)
  logs/mock_zlm.log             mock server 日志

================================================================================
快速开始
================================================================================

1) C++ 单元基准 (耗时 < 1秒):
   cd clients/built-in-app/build
   ctest --output-on-failure
   # 或
   ./test_first_frame_latency
   # 或
   ./test_webrtc_stream_provider

   期望输出:
     Totals: 8 passed, 0 failed, 0 skipped, 0 blacklisted, <500ms
     100% tests passed, 0 tests failed out of 2

2) 端到端压测 (16路 ~1秒, 64路 ~1秒):
   cd clients/built-in-app/tests/perf
   ./run_bench.sh                       # 默认 16路 + hls,flv
   ./run_bench.sh 64 hls,flv,webrtc     # 64路 + 3协议
   ./run_bench.sh 16 hls --keep-mock    # 保留 mock (调试用)

   期望输出 (64路):
     Elapsed       : ~250 ms
     Throughput    : ~250 req/s
     TOTAL p95     : < 2000ms
     GATE          : PASS

3) 手动分步 (调试用):
   # 终端 1: 启动 mock
   python3 mock_zlm_server.py --port 18080 --seed 42

   # 终端 2: 运行压测
   python3 first_frame_latency_bench.py \
       --mock-port 18080 \
       --concurrency 64 \
       --protocols hls,flv,webrtc \
       --output bench_report.json \
       --verbose

================================================================================
参数说明
================================================================================

mock_zlm_server.py:
  --port PORT          监听端口 (默认 18080)
  --host HOST          监听地址 (默认 127.0.0.1)
  --hls-ms MS          HLS 模拟首字节延迟 (默认 120ms)
  --flv-ms MS          FLV 模拟首字节延迟 (默认 80ms)
  --rtsp-ms MS         RTSP 模拟首字节延迟 (默认 50ms)
  --webrtc-ms MS       WebRTC 模拟首字节延迟 (默认 30ms)
  --api-ms MS          /api/v1/zlm/streams 模拟延迟 (默认 15ms)
  --seed N             随机种子 (用于可复现 jitter)

first_frame_latency_bench.py:
  --mock-host HOST     mock server 主机 (默认 127.0.0.1)
  --mock-port PORT     mock server 端口 (默认 18080)
  --concurrency N      线程池并发数 (默认 16)
  --num-streams N      总流数 (默认 = concurrency)
  --protocols LIST     逗号分隔协议列表: hls,flv,rtsp,webrtc
  --output FILE        写 JSON 报告到文件
  --verbose            打印前 5 个 sample 详情
  --wait-mock SECONDS  等待 mock 就绪的最长时间 (默认 5)

================================================================================
测量指标说明
================================================================================

api_latency_ms:    GET /api/v1/zlm/streams 响应延迟
handshake_latency_ms: 协议握手 (HLS playlist / FLV header / WebRTC SDP) 延迟
total_latency_ms:  api + handshake 总和 (= 首帧端到端时间)
fallback_triggered: 5xx 或网络错误, 客户端应触发降级切换
status_code:       协议响应状态码

GATE p95 < 2000ms: 64路 1080P 并发的预算

================================================================================
v3.1 计划关系
================================================================================

本基准是 SmartGateWay_全栈优化方案与执行计划_v3.1.md 中:
  P0-0 暗伤止血 — 性能基线建立
  P1-1 性能飞跃 — 64路 1080P 性能保障

的可执行验收工具。后续 P1-1 (以文搜图), P1-2 (AAC), P1-3 (Qt 视频辅助)
等改造完成后, 应重跑本基准, 确认 P95 未劣化。

修改记录:
  2026-06-30  v1.0  初始实现 (P0-2 阶段)
