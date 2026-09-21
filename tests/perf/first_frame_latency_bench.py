#!/usr/bin/env python3
"""
first_frame_latency_bench.py - P0-2 端到端首帧延迟压测脚本

测量 SmartGateWay 流媒体首帧延迟的关键路径:
  T0  客户端发起 GET /api/v1/zlm/streams (查询流 URL)
  T1  收到 streams 列表响应 (P50/P95/P99)
  T2  客户端发起协议握手 (HLS 拉 playlist / FLV 拉 header / RTSP describe)
  T3  收到首个有效字节 (HLS 200 + m3u8 / FLV 200 + FLV header / RTSP 200 OK)

输出:
  - P50/P95/P99 延迟 (ms)
  - 协议降级触发率 (%)
  - 吞吐量 (req/s)

约束:
  - 64 路 1080P 并发基线: 总 P95 延迟 < 2000ms
  - 跨端一致性: 同时验证 web/built-in 端调用的协议优先级

用法:
  python3 first_frame_latency_bench.py --mock-port 18080 --concurrency 16 --protocols hls,flv
  python3 first_frame_latency_bench.py --mock-port 18080 --concurrency 64 --output bench.json

  # [G2 2026-09-20] 真机 ZLM 直连模式(隧道复测): 无 SmartGateWay REST
  # (/api/v1/zlm/streams)时跳过 mock healthz/streams API, 仅测协议握手首字节
  # (HLS playlist / FLV header)延迟, 与 mock 模式 T2→T3 同口径
  python3 first_frame_latency_bench.py --base-url http://127.0.0.1:9080 \
      --stream-ids gb_xxx1,gb_xxx2,h264probe --protocols hls,flv \
      --repeat 2 --output bench_real.json
"""

from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field, asdict
from typing import Optional


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------
@dataclass
class Sample:
    protocol: str
    stream_id: str
    api_latency_ms: float
    handshake_latency_ms: float
    total_latency_ms: float
    fallback_triggered: bool
    status_code: int
    error: Optional[str] = None


@dataclass
class BenchResult:
    concurrency: int
    num_streams: int
    protocols: list
    mode: str = "mock"  # [G2] mock | zlm-direct(真机直连)
    samples: list = field(default_factory=list)
    started_at: float = field(default_factory=time.perf_counter)
    finished_at: Optional[float] = None
    elapsed_s: float = 0.0

    def percentiles(self) -> dict:
        if not self.samples:
            return {}
        totals = [s.total_latency_ms for s in self.samples if s.error is None]
        api_only = [s.api_latency_ms for s in self.samples if s.error is None]
        hs_only = [s.handshake_latency_ms for s in self.samples if s.error is None]
        return {
            "count_total": len(self.samples),
            "count_ok": len(totals),
            "count_fallback": sum(1 for s in self.samples if s.fallback_triggered),
            "count_error": sum(1 for s in self.samples if s.error is not None),
            "api_ms": _percentiles(api_only),
            "handshake_ms": _percentiles(hs_only),
            "total_ms": _percentiles(totals),
            "fallback_rate": (
                sum(1 for s in self.samples if s.fallback_triggered) / len(self.samples)
                if self.samples else 0.0
            ),
        }


def _percentiles(values: list) -> dict:
    if not values:
        return {"p50": 0, "p95": 0, "p99": 0, "min": 0, "max": 0, "mean": 0}
    s = sorted(values)
    return {
        "p50": _percentile(s, 0.50),
        "p95": _percentile(s, 0.95),
        "p99": _percentile(s, 0.99),
        "min": min(s),
        "max": max(s),
        "mean": statistics.mean(s),
    }


def _percentile(sorted_values: list, q: float) -> float:
    if not sorted_values:
        return 0.0
    k = (len(sorted_values) - 1) * q
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return sorted_values[int(k)]
    return sorted_values[f] * (c - k) + sorted_values[c] * (k - f)


# ---------------------------------------------------------------------------
# HTTP helpers (no external deps)
# ---------------------------------------------------------------------------
def http_get_timed(url: str, timeout: float = 5.0) -> tuple:
    """Returns (status, elapsed_ms, body_bytes, error)."""
    start = time.perf_counter()
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read(64)  # only need first 64 bytes for first-byte timing
            elapsed = (time.perf_counter() - start) * 1000.0
            return (resp.status, elapsed, body, None)
    except urllib.error.HTTPError as e:
        elapsed = (time.perf_counter() - start) * 1000.0
        return (e.code, elapsed, b"", f"http {e.code}")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        elapsed = (time.perf_counter() - start) * 1000.0
        return (0, elapsed, b"", str(e))


# ---------------------------------------------------------------------------
# Bench worker
# ---------------------------------------------------------------------------
def run_one(base_url: str, stream_id: str, protocol: str,
            zlm_mode: bool = False, app: str = "rtp") -> Sample:
    """Run a single stream-acquire-and-handshake cycle."""
    if zlm_mode:
        # [G2 2026-09-20] 真机 ZLM 直连: 无 SmartGateWay REST, 跳过 API 步骤
        # (api_ms=0), 仅测协议握手首字节延迟(与 mock 的 T2→T3 同口径)
        api_status, api_ms, api_err = 200, 0.0, None
    else:
        # Step 1: query streams API
        api_status, api_ms, _, api_err = http_get_timed(f"{base_url}/api/v1/zlm/streams")
        if api_err:
            return Sample(
                protocol=protocol, stream_id=stream_id,
                api_latency_ms=api_ms, handshake_latency_ms=0.0,
                total_latency_ms=api_ms, fallback_triggered=False,
                status_code=api_status, error=api_err,
            )

    # Step 2: pick URL based on protocol
    #   真机 ZLM 直连路径: /{app}/{stream}/hls.m3u8 与 /{app}/{stream}.live.flv
    if protocol == "hls":
        url = (f"{base_url}/{app}/{stream_id}/hls.m3u8" if zlm_mode
               else f"{base_url}/live/{stream_id}.m3u8")
    elif protocol == "flv":
        url = (f"{base_url}/{app}/{stream_id}.live.flv" if zlm_mode
               else f"{base_url}/live/{stream_id}.flv")
    elif protocol == "rtsp":
        url = f"rtsp://{base_url.split('://', 1)[-1]}/live/{stream_id}"
    elif protocol == "webrtc":
        url = f"{base_url}/rtc/{stream_id}"
    else:
        return Sample(
            protocol=protocol, stream_id=stream_id,
            api_latency_ms=api_ms, handshake_latency_ms=0.0,
            total_latency_ms=api_ms, fallback_triggered=False,
            status_code=0, error=f"unsupported protocol {protocol}",
        )

    # Step 3: handshake / first byte
    hs_status, hs_ms, body, hs_err = http_get_timed(url)

    # Detect fallback: 5xx or connection error -> assume degradation kicks in
    fallback = (hs_status >= 500 or hs_err is not None)

    return Sample(
        protocol=protocol, stream_id=stream_id,
        api_latency_ms=api_ms,
        handshake_latency_ms=hs_ms,
        total_latency_ms=api_ms + hs_ms,
        fallback_triggered=fallback,
        status_code=hs_status,
        error=hs_err,
    )


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def wait_for_mock(base_url: str, timeout_s: float = 5.0) -> bool:
    """Poll /healthz until mock is ready."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        status, _, _, _ = http_get_timed(f"{base_url}/healthz", timeout=1.0)
        if status == 200:
            return True
        time.sleep(0.05)
    return False


def run_bench(base_url: str, concurrency: int, num_streams: int,
              protocols: list, zlm_mode: bool = False, app: str = "rtp",
              stream_ids: Optional[list] = None, repeat: int = 1) -> BenchResult:
    result = BenchResult(
        concurrency=concurrency, num_streams=num_streams, protocols=protocols,
        mode="zlm-direct" if zlm_mode else "mock")

    tasks = []
    if zlm_mode:
        # [G2 2026-09-20] 真机: 流集合显式给定(设备真实流的 app/stream ID),
        # 每 (流 × 协议) 采集 repeat 个样本
        for sid in (stream_ids or []):
            for proto in protocols:
                for _ in range(max(1, repeat)):
                    tasks.append((sid, proto))
    else:
        # Pre-register streams by hitting them once (mimics ZLM pull activation)
        for i in range(num_streams):
            sid = f"ch_{i:04d}"
            http_get_timed(f"{base_url}/live/{sid}.m3u8", timeout=2.0)

        for i in range(num_streams):
            sid = f"ch_{i:04d}"
            proto = protocols[i % len(protocols)]
            tasks.append((sid, proto))

    started = time.perf_counter()
    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = [
            pool.submit(run_one, base_url, sid, proto, zlm_mode, app)
            for sid, proto in tasks
        ]
        for fut in as_completed(futures):
            try:
                result.samples.append(fut.result())
            except Exception as e:  # noqa: BLE001
                sys.stderr.write(f"worker exception: {e}\n")
    result.elapsed_s = time.perf_counter() - started
    result.finished_at = time.time()
    return result


def print_report(result: BenchResult, verbose: bool = False) -> None:
    p = result.percentiles()
    rps = result.num_streams / result.elapsed_s if result.elapsed_s else 0.0
    print()
    print("=" * 70)
    print(f"  P0-2 First-Frame Latency Benchmark Report")
    print("=" * 70)
    print(f"  Concurrency   : {result.concurrency}")
    print(f"  Streams       : {result.num_streams}")
    print(f"  Mode          : {result.mode}")
    print(f"  Protocols     : {','.join(result.protocols)}")
    print(f"  Elapsed       : {result.elapsed_s*1000:.1f} ms ({result.elapsed_s:.3f} s)")
    print(f"  Throughput    : {rps:.1f} req/s")
    print("-" * 70)
    print(f"  Total samples : {p.get('count_total', 0)} "
          f"(ok={p.get('count_ok', 0)}, "
          f"fallback={p.get('count_fallback', 0)}, "
          f"error={p.get('count_error', 0)})")
    print(f"  Fallback rate : {p.get('fallback_rate', 0)*100:.1f}%")
    print("-" * 70)
    print("  API latency   : "
          f"p50={p['api_ms']['p50']:.1f}ms  "
          f"p95={p['api_ms']['p95']:.1f}ms  "
          f"p99={p['api_ms']['p99']:.1f}ms")
    print("  Handshake     : "
          f"p50={p['handshake_ms']['p50']:.1f}ms  "
          f"p95={p['handshake_ms']['p95']:.1f}ms  "
          f"p99={p['handshake_ms']['p99']:.1f}ms")
    print("  TOTAL         : "
          f"p50={p['total_ms']['p50']:.1f}ms  "
          f"p95={p['total_ms']['p95']:.1f}ms  "
          f"p99={p['total_ms']['p99']:.1f}ms  "
          f"max={p['total_ms']['max']:.1f}ms")
    print("=" * 70)

    # Pass/fail gate
    P95_BUDGET_MS = 2000.0  # 64路 1080P 预算
    p95_total = p['total_ms']['p95']
    verdict = "PASS" if p95_total < P95_BUDGET_MS else "FAIL"
    print(f"  GATE p95<{P95_BUDGET_MS:.0f}ms : {verdict} (actual={p95_total:.1f}ms)")
    print("=" * 70)

    if verbose and result.samples:
        print("\nFirst 5 samples:")
        for s in result.samples[:5]:
            print(f"  {s.stream_id} proto={s.protocol:7s} "
                  f"api={s.api_latency_ms:6.1f}ms "
                  f"hs={s.handshake_latency_ms:6.1f}ms "
                  f"total={s.total_latency_ms:6.1f}ms "
                  f"status={s.status_code} "
                  f"fb={'Y' if s.fallback_triggered else 'N'} "
                  f"err={s.error or '-'}")


def parse_args(argv):
    p = argparse.ArgumentParser(description="P0-2 first-frame latency benchmark")
    p.add_argument("--mock-host", default="127.0.0.1")
    p.add_argument("--mock-port", type=int, default=18080)
    p.add_argument("--concurrency", type=int, default=16)
    p.add_argument("--num-streams", type=int, default=None,
                   help="Default = concurrency")
    p.add_argument("--protocols", default="hls,flv",
                   help="Comma-separated: hls,flv,rtsp,webrtc")
    p.add_argument("--output", default=None, help="Write JSON report to file")
    # [G2 2026-09-20] 真机 ZLM 直连模式(隧道复测)
    p.add_argument("--base-url", default=None,
                   help="[G2] 真机 ZLM 模式: 完整基址(如 http://127.0.0.1:9080); "
                        "启用后跳过 mock healthz/streams API, 需配 --stream-ids")
    p.add_argument("--stream-ids", default=None,
                   help="[G2] 真机模式流 ID 列表(逗号分隔, 如 gb_xxx1,h264probe)")
    p.add_argument("--app", default="rtp", help="[G2] 真机模式 ZLM app 名")
    p.add_argument("--repeat", type=int, default=1,
                   help="[G2] 真机模式每(流,协议)重复采样次数")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--wait-mock", type=float, default=5.0,
                   help="Seconds to wait for mock to be ready")
    return p.parse_args(argv)


def main(argv) -> int:
    args = parse_args(argv)
    if args.num_streams is None:
        args.num_streams = args.concurrency

    protocols = [p.strip() for p in args.protocols.split(",") if p.strip()]

    if args.base_url:
        # [G2 2026-09-20] 真机 ZLM 直连模式: 无 mock 依赖(隧道指向设备 9080)
        if not args.stream_ids:
            print("ERROR: --base-url 模式需 --stream-ids 指定真机流", file=sys.stderr)
            return 2
        stream_ids = [s.strip() for s in args.stream_ids.split(",") if s.strip()]
        if not stream_ids:
            print("ERROR: --stream-ids 为空", file=sys.stderr)
            return 2
        base_url = args.base_url.rstrip("/")
        result = run_bench(base_url, args.concurrency, len(stream_ids),
                           protocols, zlm_mode=True, app=args.app,
                           stream_ids=stream_ids, repeat=args.repeat)
    else:
        base_url = f"http://{args.mock_host}:{args.mock_port}"

        if not wait_for_mock(base_url, args.wait_mock):
            print(f"ERROR: mock server not reachable at {base_url}/healthz",
                  file=sys.stderr)
            return 2

        result = run_bench(base_url, args.concurrency, args.num_streams, protocols)
    print_report(result, verbose=args.verbose)

    if args.output:
        report = {
            "mode": result.mode,
            "concurrency": result.concurrency,
            "num_streams": result.num_streams,
            "protocols": result.protocols,
            "elapsed_s": result.elapsed_s,
            "percentiles": result.percentiles(),
            "samples": [asdict(s) for s in result.samples],
        }
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        print(f"\nReport written to {args.output}")

    p95_total = result.percentiles()["total_ms"]["p95"]
    return 0 if p95_total < 2000.0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
