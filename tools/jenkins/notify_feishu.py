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
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--jenkins-build-number", default="")
    return parser.parse_args()


def generate_signature(timestamp, secret):
    string_to_sign = f"{timestamp}\n{secret}".encode("utf-8")
    digest = hmac.new(string_to_sign, digestmod=hashlib.sha256).digest()
    return base64.b64encode(digest).decode("ascii")


def text_row(text):
    return [{"tag": "text", "text": text}]


def build_payload(args, secret):
    timestamp = int(time.time())
    type_label = args.build_type.capitalize()
    title = f"Worldo {args.platform.capitalize()} {type_label} 构建成功"
    content = [
        text_row(f"文件：{args.artifact_name}"),
        text_row(f"版本：{args.version_name} ({args.version_code})"),
        text_row(f"类型：{args.build_type}"),
        text_row(f"分支：{args.branch}"),
        text_row(f"提交：{args.commit[:12]}"),
    ]
    if args.jenkins_build_number:
        content.append(text_row(f"Jenkins：#{args.jenkins_build_number}"))
    content.append([{"tag": "a", "text": "下载 APK", "href": args.download_url}])

    return {
        "timestamp": str(timestamp),
        "sign": generate_signature(timestamp, secret),
        "msg_type": "post",
        "content": {
            "post": {
                "zh_cn": {
                    "title": title,
                    "content": content,
                }
            }
        },
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
    if not args.download_url.startswith("https://"):
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
