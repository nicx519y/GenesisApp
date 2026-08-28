#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
uploader="$script_dir/upload_pgyer.sh"
temp_dir="$(mktemp -d)"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  [[ -d "$temp_dir" ]] && rm -rf -- "$temp_dir"
}
trap cleanup EXIT

printf 'fake-apk-content' >"$temp_dir/Worldo-arm64-v8a-1.2.3-123-release.apk"
cat >"$temp_dir/release-metadata.json" <<'JSON'
{
  "platform": "android",
  "branch": "main",
  "source_commit": "1234567890abcdef",
  "android": {
    "artifact_kind": "apk",
    "application_id": "com.worldo.ai",
    "version_name": "1.2.3",
    "version_code": "123",
    "requested_build_type": "release",
    "artifact": "Worldo-arm64-v8a-1.2.3-123-release.apk"
  }
}
JSON

python3 - "$temp_dir/port" <<'PY' &
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

port_file = pathlib.Path(sys.argv[1])

class Handler(BaseHTTPRequestHandler):
    polls = 0

    def log_message(self, *_args):
        return

    def json_response(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path == "/token":
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode()
            params = parse_qs(body)
            assert params["_api_key"] == ["test-secret-key"]
            assert params["buildType"] == ["apk"]
            endpoint = f"http://127.0.0.1:{self.server.server_port}/upload"
            self.json_response({
                "code": 0,
                "message": "",
                "data": {
                    "endpoint": endpoint,
                    "key": "mock-build-key",
                    "params": {
                        "key": "mock-upload-key",
                        "signature": "mock-signature",
                        "x-cos-security-token": "mock-security-token"
                    }
                }
            })
            return
        if self.path == "/upload":
            content_type = self.headers.get("Content-Type", "")
            assert content_type.startswith("multipart/form-data")
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            for expected in (
                b'name="key"',
                b"mock-upload-key",
                b'name="signature"',
                b"mock-signature",
                b'name="x-cos-security-token"',
                b"mock-security-token",
                b'filename="Worldo-arm64-v8a-1.2.3-123-release.apk"',
                b"fake-apk-content",
            ):
                assert expected in body
            self.send_response(204)
            self.end_headers()
            return
        self.send_error(404)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/build":
            self.send_error(404)
            return
        params = parse_qs(parsed.query)
        assert params["_api_key"] == ["test-secret-key"]
        assert params["buildKey"] == ["mock-build-key"]
        Handler.polls += 1
        if Handler.polls == 1:
            self.json_response({"code": 1247, "message": "应用正在发布中"})
            return
        self.json_response({
            "code": 0,
            "message": "",
            "data": {
                "buildKey": "published-build-key",
                "buildType": 2,
                "buildIdentifier": "com.worldo.ai",
                "buildVersion": "1.2.3",
                "buildVersionNo": "123",
                "buildBuildVersion": 7,
                "buildShortcutUrl": "mock123",
                "buildQRCodeURL": "https://www.pgyer.com/app/qrcode/mock123",
                "buildUpdated": "2026-08-28 12:00:00"
            }
        })

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
port_file.write_text(str(server.server_port), encoding="utf-8")
server.serve_forever()
PY
server_pid=$!

for _ in {1..50}; do
  [[ -s "$temp_dir/port" ]] && break
  sleep 0.02
done
[[ -s "$temp_dir/port" ]] || { echo "ERROR: mock server 未启动" >&2; exit 1; }
port="$(<"$temp_dir/port")"

output="$(
  PGYER_API_KEY='test-secret-key' \
  PGYER_TOKEN_URL="http://127.0.0.1:$port/token" \
  PGYER_BUILD_INFO_URL="http://127.0.0.1:$port/build" \
  PGYER_POLL_INTERVAL_SECONDS=0 \
  "$uploader" \
    --apk "$temp_dir/Worldo-arm64-v8a-1.2.3-123-release.apk" \
    --metadata "$temp_dir/release-metadata.json"
)"

grep -Fq '蒲公英发布完成: https://www.pgyer.com/mock123' <<<"$output"
grep -Fq '"install_url": "https://www.pgyer.com/mock123"' "$temp_dir/pgyer-upload.json"
grep -Fq '"build_identifier": "com.worldo.ai"' "$temp_dir/pgyer-upload.json"
if grep -R -Fq 'test-secret-key' "$temp_dir/pgyer-upload.json" "$temp_dir/release-metadata.json"; then
  echo "ERROR: API Key 不应写入构建产物" >&2
  exit 1
fi

echo "tools/jenkins/upload_pgyer.sh 模拟上传测试通过"
