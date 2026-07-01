#!/bin/bash
# run_bench.sh - P0-2 首帧延迟压测一键运行脚本
#
# 用法:
#   ./run_bench.sh                       # 默认 16 路 + hls,flv 协议
#   ./run_bench.sh 64 hls,flv,webrtc     # 64 路 + 3 协议
#   ./run_bench.sh 16 hls --keep-mock    # 压测后保留 mock server
#
# 输出:
#   终端 - 实时压测报告
#   bench_report.json - JSON 详细数据 (含每条 sample)

set -e

CONCURRENCY="${1:-16}"
PROTOCOLS="${2:-hls,flv}"
KEEP_MOCK="${3:-}"

PERF_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${PERF_DIR}/logs"
REPORT_FILE="${PERF_DIR}/bench_report.json"
MOCK_PORT=18080
MOCK_PID=""

mkdir -p "${LOG_DIR}"

cleanup() {
    if [ -n "${MOCK_PID}" ] && kill -0 "${MOCK_PID}" 2>/dev/null; then
        if [ "${KEEP_MOCK}" != "--keep-mock" ]; then
            echo "[run_bench] stopping mock server (pid=${MOCK_PID})"
            kill "${MOCK_PID}" 2>/dev/null || true
            wait "${MOCK_PID}" 2>/dev/null || true
        else
            echo "[run_bench] keeping mock server alive (pid=${MOCK_PID})"
        fi
    fi
}
trap cleanup EXIT INT TERM

echo "=========================================================="
echo "  P0-2 First-Frame Latency Benchmark"
echo "  Concurrency : ${CONCURRENCY}"
echo "  Protocols   : ${PROTOCOLS}"
echo "  Mock port   : ${MOCK_PORT}"
echo "=========================================================="
echo

# 1. 启动 mock server
echo "[1/3] starting mock ZLM server ..."
python3 "${PERF_DIR}/mock_zlm_server.py" \
    --port "${MOCK_PORT}" --seed 42 \
    > "${LOG_DIR}/mock_zlm.log" 2>&1 &
MOCK_PID=$!
echo "  mock_pid=${MOCK_PID}"

# 等待 mock 就绪
for i in $(seq 1 50); do
    if curl -sf -m 1 "http://127.0.0.1:${MOCK_PORT}/healthz" >/dev/null 2>&1; then
        echo "  mock ready (after ${i} * 100ms)"
        break
    fi
    sleep 0.1
done

if ! curl -sf -m 1 "http://127.0.0.1:${MOCK_PORT}/healthz" >/dev/null 2>&1; then
    echo "ERROR: mock server not reachable"
    cat "${LOG_DIR}/mock_zlm.log"
    exit 2
fi

# 2. 运行压测
echo
echo "[2/3] running benchmark ..."
python3 "${PERF_DIR}/first_frame_latency_bench.py" \
    --mock-port "${MOCK_PORT}" \
    --concurrency "${CONCURRENCY}" \
    --protocols "${PROTOCOLS}" \
    --output "${REPORT_FILE}" \
    --verbose

BENCH_EXIT=$?

# 3. 输出验收门
echo
echo "[3/3] verdict"
if [ ${BENCH_EXIT} -eq 0 ]; then
    echo "  GATE: PASS (p95 < 2000ms)"
else
    echo "  GATE: FAIL (p95 >= 2000ms)"
fi
echo "  report: ${REPORT_FILE}"
echo "  mock log: ${LOG_DIR}/mock_zlm.log"

exit ${BENCH_EXIT}
