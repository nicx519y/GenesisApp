#!/usr/bin/env python3
import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.request


def parse_args():
    parser = argparse.ArgumentParser(description="Send a Worldo build notification to Feishu")
    parser.add_argument("--artifact-name", required=True)
    parser.add_argument("--platform", required=True, choices=("android", "ios"))
    parser.add_argument("--build-type", required=True)
    parser.add_argument(
        "--status",
        choices=("success", "build_failed", "pgyer_failed"),
        default="success",
    )
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--download-url", default="")
    return parser.parse_args()


def generate_signature(timestamp, secret):
    string_to_sign = f"{timestamp}\n{secret}".encode("utf-8")
    digest = hmac.new(string_to_sign, digestmod=hashlib.sha256).digest()
    return base64.b64encode(digest).decode("ascii")


def build_payload(args, secret):
    timestamp = int(time.time())
    platform_label = "Android" if args.platform == "android" else "iOS"
    lines = [
        f"Worldo-{platform_label}",
        f"打包分支：{args.branch}",
        f"版本信息：{args.version_name}+{args.version_code}",
        f"构建类型：{args.build_type}",
    ]
    if args.status == "success":
        lines.append(f"下载链接：{args.download_url}")
    elif args.status == "build_failed":
        lines.append("当前状态：打包失败")
    else:
        lines.append("当前状态：蒲公英上传失败")
    message = "\n".join(lines)

    return {
        "timestamp": str(timestamp),
        "sign": generate_signature(timestamp, secret),
        "msg_type": "text",
        "content": {"text": message},
    }


def response_code(payload):
    if "code" in payload:
        return payload["code"]
    if "StatusCode" in payload:
        return payload["StatusCode"]
    return None


def main():
    args = parse_args()
    webhook_url = os.environ.get("FEISHU_WEBHOOK_URL", "")
    signing_secret = os.environ.get("FEISHU_SIGNING_SECRET", "")
    if not webhook_url:
        raise SystemExit("ERROR: 未注入 Jenkins 凭据 feishu-webhook-url")
    if not signing_secret:
        raise SystemExit("ERROR: 未注入 Jenkins 凭据 feishu-signing-secret")
    if args.status == "success" and not args.download_url.startswith("https://"):
        raise SystemExit("ERROR: 飞书下载链接必须使用 HTTPS")

    body = json.dumps(
        build_payload(args, signing_secret),
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    request = urllib.request.Request(
        webhook_url,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            response_body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(f"ERROR: 飞书 Webhook 请求失败(HTTP {error.code}): {detail}")
    except urllib.error.URLError as error:
        raise SystemExit(f"ERROR: 飞书 Webhook 请求失败: {error.reason}")

    try:
        result = json.loads(response_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise SystemExit("ERROR: 飞书 Webhook 返回了无效 JSON")
    code = response_code(result)
    if str(code) != "0":
        message = result.get("msg") or result.get("StatusMessage") or "unknown error"
        raise SystemExit(f"ERROR: 飞书消息发送失败(code={code}): {message}")

    print(f"飞书通知发送成功: {args.artifact_name}")


if __name__ == "__main__":
    main()
