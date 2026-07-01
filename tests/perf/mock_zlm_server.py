#!/usr/bin/env python3
"""
mock_zlm_server.py - P0-2 首帧延迟压测专用 ZLM Mock Server
"""

from __future__ import annotations
import argparse
import json
import os
import random
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

DEFAULT_LATENCY_MS = {
    "hls": 120, "flv": 80, "rtsp": 50, "webrtc": 30, "api": 15,
}

_REGISTERED_STREAMS: set = set()


def resolve_latency(protocol: str) -> float:
    env_key = f"MOCK_LATENCY_{protocol.upper()}_MS"
    base_ms = float(os.environ.get(env_key, DEFAULT_LATENCY_MS.get(protocol, 50)))
    jitter = 1.0 + (random.random() - 0.5) * 0.4
    return base_ms * jitter / 1000.0


def mark_stream_active(stream_id: str) -> None:
    _REGISTERED_STREAMS.add(stream_id)


class ZLMMockHandler(BaseHTTPRequestHandler):
    server_version = "ZLMock/1.0"

    def log_message(self, fmt, *args):
        if os.environ.get("MOCK_VERBOSE") == "1":
            super().log_message(fmt, *args)

    def _write_latency(self, protocol):
        d = resolve_latency(protocol)
        if d > 0:
            time.sleep(d)

    def _send_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _send_bytes(self, code, content_type, body, extra_headers=None):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        for k, v in (extra_headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _send_503(self, protocol):
        self._write_latency(protocol)
        self._send_json(503, {"code": -1, "msg": f"mock: {protocol} unavailable"})

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path
        if path == "/api/v1/zlm/streams":
            return self._handle_streams_list()
        if path.startswith("/live/") and path.endswith(".m3u8"):
            return self._handle_hls_playlist(path[len("/live/"):-len(".m3u8")])
        if path.startswith("/live/") and path.endswith(".ts"):
            return self._handle_hls_segment()
        if path.startswith("/live/") and path.endswith(".flv"):
            return self._handle_flv_stream(path[len("/live/"):-len(".flv")])
        if path.startswith("/rtc/"):
            return self._handle_webrtc_offer()
        if path == "/healthz":
            return self._send_json(200, {"ok": True, "ts": time.time()})
        return self._send_json(404, {"code": -1, "msg": f"mock: not found {path}"})

    def _handle_streams_list(self):
        self._write_latency("api")
        host = self.headers.get("Host", "localhost")
        streams = []
        for sid in sorted(_REGISTERED_STREAMS):
            streams.append({
                "stream_id": sid,
                "rtsp_url": f"rtsp://{host}/live/{sid}",
                "flv_url": f"http://{host}/live/{sid}.flv",
                "hls_url": f"http://{host}/live/{sid}.m3u8",
                "webrtc_url": f"webrtc://{host}/rtc/{sid}",
            })
        self._send_json(200, {"code": 0, "msg": "ok", "data": {"streams": streams}})

    def _handle_hls_playlist(self, stream_id):
        if random.random() < 0.05:
            return self._send_503("hls")
        mark_stream_active(stream_id)
        self._write_latency("hls")
        body = (
            "#EXTM3U\n"
            "#EXT-X-VERSION:3\n"
            "#EXT-X-TARGETDURATION:2\n"
            "#EXT-X-MEDIA-SEQUENCE:0\n"
            f"#EXTINF:2.0,\n/live/{stream_id}.ts\n"
            "#EXT-X-ENDLIST\n"
        ).encode("utf-8")
        self._send_bytes(200, "application/vnd.apple.mpegurl", body)

    def _handle_hls_segment(self):
        self._write_latency("hls")
        ts_packet = b"\x47" + b"\x00" * 187
        self._send_bytes(200, "video/mp2t", ts_packet)

    def _handle_flv_stream(self, stream_id):
        mark_stream_active(stream_id)
        self._write_latency("flv")
        flv_header = b"FLV\x01\x05\x00\x00\x00\x09\x00\x00\x00\x00"
        self._send_bytes(200, "video/x-flv", flv_header)

    def _handle_webrtc_offer(self):
        mark_stream_active(self.path[len("/rtc/"):])
        self._write_latency("webrtc")
        sdp = (
            "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\n"
            "s=ZLMock\r\nt=0 0\r\n"
        ).encode("utf-8")
        self._send_bytes(200, "application/sdp", sdp,
                         extra_headers={"Location": self.path})


def parse_args(argv):
    p = argparse.ArgumentParser(
        description="P0-2 ZLM Mock Server for first-frame latency benchmark")
    p.add_argument("--port", type=int, default=18080)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--hls-ms", type=float, default=None)
    p.add_argument("--flv-ms", type=float, default=None)
    p.add_argument("--rtsp-ms", type=float, default=None)
    p.add_argument("--webrtc-ms", type=float, default=None)
    p.add_argument("--api-ms", type=float, default=None)
    p.add_argument("--seed", type=int, default=None)
    return p.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if args.seed is not None:
        random.seed(args.seed)
    overrides = {
        "hls": args.hls_ms, "flv": args.flv_ms, "rtsp": args.rtsp_ms,
        "webrtc": args.webrtc_ms, "api": args.api_ms,
    }
    for proto, ms in overrides.items():
        if ms is not None:
            os.environ[f"MOCK_LATENCY_{proto.upper()}_MS"] = str(ms)
            DEFAULT_LATENCY_MS[proto] = ms
    httpd = ThreadingHTTPServer((args.host, args.port), ZLMMockHandler)
    print(f"[mock_zlm] listening on http://{args.host}:{args.port}", flush=True)
    print(f"[mock_zlm] latencies (ms): {DEFAULT_LATENCY_MS}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[mock_zlm] shutting down", flush=True)
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
