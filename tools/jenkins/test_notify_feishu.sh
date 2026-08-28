#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
notifier="$script_dir/notify_feishu.py"
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

python3 - "$temp_dir/port" "$temp_dir/request.json" <<'PY' &
import base64
import hashlib
import hmac
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port_file = pathlib.Path(sys.argv[1])
request_file = pathlib.Path(sys.argv[2])
secret = "test-signing-secret"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        return

    def do_POST(self):
        if self.path != "/hook/test":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        payload = json.loads(body)
        timestamp = payload["timestamp"]
        expected_sign = base64.b64encode(
            hmac.new(
                f"{timestamp}\n{secret}".encode(),
                digestmod=hashlib.sha256,
            ).digest()
        ).decode()
        assert payload["sign"] == expected_sign
        assert payload["msg_type"] == "post"
        post = payload["content"]["post"]["zh_cn"]
        serialized = json.dumps(post, ensure_ascii=False)
        assert "Worldo" in post["title"]
        assert "Worldo-arm64-v8a-1.2.3-123-release.apk" in serialized
        assert "https://download.worldo.example/apk/build/mock/Worldo-arm64-v8a-1.2.3-123-release.apk" in serialized
        request_file.write_bytes(body)
        response = json.dumps({"code": 0, "msg": "success"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

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
  FEISHU_WEBHOOK_URL="http://127.0.0.1:$port/hook/test" \
  FEISHU_SIGNING_SECRET='test-signing-secret' \
  "$notifier" \
    --artifact-name 'Worldo-arm64-v8a-1.2.3-123-release.apk' \
    --platform android \
    --build-type release \
    --version-name 1.2.3 \
    --version-code 123 \
    --branch main \
    --commit 1234567890abcdef \
    --jenkins-build-number 9 \
    --download-url 'https://download.worldo.example/apk/build/mock/Worldo-arm64-v8a-1.2.3-123-release.apk'
)"

grep -Fq '飞书通知发送成功: Worldo-arm64-v8a-1.2.3-123-release.apk' <<<"$output"
[[ -s "$temp_dir/request.json" ]]
if grep -Fq 'test-signing-secret' "$temp_dir/request.json"; then
  echo "ERROR: 飞书签名密钥不应写入请求正文" >&2
  exit 1
fi

echo "tools/jenkins/notify_feishu.py 模拟通知测试通过"
