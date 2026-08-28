#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  PGYER_API_KEY=... tools/jenkins/upload_pgyer.sh \
    --apk PATH --metadata PATH [--channel-shortcut SHORTCUT]

Uploads one verified Android APK to Pgyer using API 2.0, waits until it is
published, validates the returned package/version, and writes pgyer-upload.json
next to the release metadata file.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

json_value() {
  local path="$1"
  python3 -c '
import json
import sys

value = json.load(sys.stdin)
for part in sys.argv[1].split("."):
    if not isinstance(value, dict) or part not in value:
        raise SystemExit(2)
    value = value[part]
if value is None:
    raise SystemExit(2)
if isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False))
else:
    print(value)
' "$path"
}

apk_path=""
metadata_path=""
channel_shortcut=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) apk_path="${2:-}"; shift 2 ;;
    --metadata) metadata_path="${2:-}"; shift 2 ;;
    --channel-shortcut) channel_shortcut="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "未知参数: $1" ;;
  esac
done

[[ -n "${PGYER_API_KEY:-}" ]] || die "未注入 Jenkins 凭据 pgyer-api-key"
[[ -f "$apk_path" ]] || die "找不到 APK: $apk_path"
[[ "$apk_path" == *.apk ]] || die "蒲公英上传仅接受本流程生成的 APK"
[[ -f "$metadata_path" ]] || die "找不到构建元数据: $metadata_path"
[[ -z "$channel_shortcut" || "$channel_shortcut" =~ ^[A-Za-z0-9]+$ ]] || {
  die "蒲公英渠道短链接格式非法"
}

for tool in curl python3; do
  require_command "$tool"
done

readarray_supported=true
if ! type readarray >/dev/null 2>&1; then
  readarray_supported=false
fi

metadata_values="$(python3 - "$metadata_path" "${apk_path##*/}" <<'PY'
import json
import pathlib
import sys

metadata_path, expected_artifact = sys.argv[1:]
data = json.loads(pathlib.Path(metadata_path).read_text(encoding="utf-8"))
android = data.get("android") or {}
checks = {
    "platform": data.get("platform"),
    "artifact_kind": android.get("artifact_kind"),
    "application_id": android.get("application_id"),
    "version_name": android.get("version_name"),
    "version_code": str(android.get("version_code", "")),
    "artifact": android.get("artifact"),
    "requested_build_type": android.get("requested_build_type"),
    "branch": data.get("branch"),
    "source_commit": data.get("source_commit"),
}
if checks["platform"] != "android" or checks["artifact_kind"] != "apk":
    raise SystemExit("ERROR: 只有经过校验的 Android APK 可以上传蒲公英")
if checks["application_id"] != "com.worldo.ai":
    raise SystemExit(f"ERROR: 非预期包名: {checks['application_id']!r}")
if checks["artifact"] != expected_artifact:
    raise SystemExit("ERROR: APK 文件名与 release-metadata.json 不一致")
if checks["requested_build_type"] not in {"release", "debug"}:
    raise SystemExit("ERROR: 仅支持上传 release/debug APK")
for key in ("version_name", "version_code", "branch", "source_commit"):
    if not checks[key]:
        raise SystemExit(f"ERROR: 构建元数据缺少 {key}")
for key in ("application_id", "version_name", "version_code", "requested_build_type", "branch", "source_commit"):
    print(checks[key])
PY
)" || die "构建元数据校验失败"

if [[ "$readarray_supported" == true ]]; then
  readarray -t metadata_fields <<<"$metadata_values"
else
  metadata_fields=()
  while IFS= read -r value; do
    metadata_fields+=("$value")
  done <<<"$metadata_values"
fi

expected_identifier="${metadata_fields[0]}"
expected_version="${metadata_fields[1]}"
expected_version_code="${metadata_fields[2]}"
requested_build_type="${metadata_fields[3]}"
branch="${metadata_fields[4]}"
source_commit="${metadata_fields[5]}"

token_url="${PGYER_TOKEN_URL:-https://www.pgyer.com/apiv2/app/getCOSToken}"
build_info_url="${PGYER_BUILD_INFO_URL:-https://www.pgyer.com/apiv2/app/buildInfo}"
poll_interval="${PGYER_POLL_INTERVAL_SECONDS:-4}"
max_polls="${PGYER_MAX_POLLS:-30}"
[[ "$poll_interval" =~ ^[0-9]+$ ]] || die "PGYER_POLL_INTERVAL_SECONDS 必须是非负整数"
[[ "$max_polls" =~ ^[1-9][0-9]*$ ]] || die "PGYER_MAX_POLLS 必须是正整数"

update_description="Worldo ${requested_build_type}; branch=${branch}; commit=${source_commit:0:12}"
token_args=(
  --silent --show-error --fail-with-body
  --request POST "$token_url"
  --data-urlencode '_api_key@-'
  --data-urlencode 'buildType=apk'
  --data-urlencode 'oversea=2'
  --data-urlencode 'buildInstallDate=2'
  --data-urlencode "buildUpdateDescription=$update_description"
)
if [[ -n "$channel_shortcut" ]]; then
  token_args+=(--data-urlencode "buildChannelShortcut=$channel_shortcut")
fi

echo "==> 获取蒲公英上传令牌"
token_json="$(printf '%s' "$PGYER_API_KEY" | curl "${token_args[@]}")" || {
  die "蒲公英 getCOSToken 请求失败"
}
token_code="$(printf '%s' "$token_json" | json_value code 2>/dev/null)" || {
  die "蒲公英 getCOSToken 返回了无效 JSON"
}
if [[ "$token_code" != "0" ]]; then
  token_message="$(printf '%s' "$token_json" | json_value message 2>/dev/null || true)"
  die "蒲公英 getCOSToken 失败(code=$token_code): $token_message"
fi

upload_endpoint="$(printf '%s' "$token_json" | json_value data.endpoint)" || die "上传令牌缺少 endpoint"
build_key="$(printf '%s' "$token_json" | json_value data.key)" || die "上传令牌缺少 key"
upload_key="$(printf '%s' "$token_json" | json_value data.params.key)" || die "上传令牌缺少 params.key"
signature="$(printf '%s' "$token_json" | json_value data.params.signature)" || die "上传令牌缺少 signature"
security_token="$(printf '%s' "$token_json" | json_value data.params.x-cos-security-token)" || {
  die "上传令牌缺少 x-cos-security-token"
}

temp_dir="$(mktemp -d)"
cleanup() {
  [[ -n "${temp_dir:-}" && -d "$temp_dir" ]] && rm -rf -- "$temp_dir"
}
trap cleanup EXIT

echo "==> 上传 ${apk_path##*/} 到蒲公英"
upload_status="$(curl \
  --silent --show-error \
  --output "$temp_dir/upload-response.txt" \
  --write-out '%{http_code}' \
  --request POST "$upload_endpoint" \
  --form-string "key=$upload_key" \
  --form-string "signature=$signature" \
  --form-string "x-cos-security-token=$security_token" \
  --form-string "x-cos-meta-file-name=${apk_path##*/}" \
  --form "file=@$apk_path")" || die "蒲公英文件上传请求失败"
if [[ "$upload_status" != "204" ]]; then
  upload_error="$(sed -n '1,20p' "$temp_dir/upload-response.txt")"
  die "蒲公英文件上传失败(HTTP $upload_status): $upload_error"
fi

echo "==> 等待蒲公英发布完成"
build_info_json=""
for ((attempt = 1; attempt <= max_polls; attempt++)); do
  build_info_json="$(printf '%s' "$PGYER_API_KEY" | curl \
    --silent --show-error --fail-with-body \
    --get "$build_info_url" \
    --data-urlencode '_api_key@-' \
    --data-urlencode "buildKey=$build_key")" || die "蒲公英 buildInfo 请求失败"
  build_code="$(printf '%s' "$build_info_json" | json_value code 2>/dev/null)" || {
    die "蒲公英 buildInfo 返回了无效 JSON"
  }
  if [[ "$build_code" == "0" ]]; then
    break
  fi
  build_message="$(printf '%s' "$build_info_json" | json_value message 2>/dev/null || true)"
  if [[ "$build_code" != "1247" ]]; then
    die "蒲公英发布失败(code=$build_code): $build_message"
  fi
  if (( attempt == max_polls )); then
    die "等待蒲公英发布超时（已轮询 $max_polls 次）"
  fi
  sleep "$poll_interval"
done

result_path="$(dirname "$metadata_path")/pgyer-upload.json"
install_url="$(python3 - \
  "$build_info_json" \
  "$result_path" \
  "$expected_identifier" \
  "$expected_version" \
  "$expected_version_code" \
  "$requested_build_type" \
  "$channel_shortcut" <<'PY'
import json
import pathlib
import sys

raw, output_path, expected_identifier, expected_version, expected_code, build_type, channel = sys.argv[1:]
response = json.loads(raw)
data = response.get("data") or {}
actual = {
    "buildIdentifier": str(data.get("buildIdentifier", "")),
    "buildVersion": str(data.get("buildVersion", "")),
    "buildVersionNo": str(data.get("buildVersionNo", "")),
}
expected = {
    "buildIdentifier": expected_identifier,
    "buildVersion": expected_version,
    "buildVersionNo": expected_code,
}
for key, expected_value in expected.items():
    if actual[key] != expected_value:
        raise SystemExit(
            f"ERROR: 蒲公英返回的 {key}={actual[key]!r}，期望 {expected_value!r}"
        )
shortcut = str(data.get("buildShortcutUrl", "")).strip("/")
if not shortcut:
    raise SystemExit("ERROR: 蒲公英返回结果缺少 buildShortcutUrl")
install_url = f"https://www.pgyer.com/{shortcut}"
result = {
    "provider": "pgyer",
    "build_type": build_type,
    "channel_shortcut": channel or None,
    "install_url": install_url,
    "qrcode_url": data.get("buildQRCodeURL"),
    "build_key": data.get("buildKey"),
    "build_identifier": actual["buildIdentifier"],
    "version_name": actual["buildVersion"],
    "version_code": actual["buildVersionNo"],
    "pgyer_build_number": data.get("buildBuildVersion"),
    "published_at": data.get("buildUpdated") or data.get("buildCreated"),
}
pathlib.Path(output_path).write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
print(install_url)
PY
)" || die "蒲公英发布结果校验失败"

echo "蒲公英发布完成: $install_url"
echo "发布信息: $result_path"
