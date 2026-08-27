#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/jenkins/local_release.sh --platform android|ios|both --branch BRANCH \
    --android-version-name X.Y.Z --android-version-code N \
    --ios-version-name X.Y.Z --ios-build-number N \
    [--repo-dir PATH] [--artifact-dir PATH] [--dry-run]

This script only builds and verifies local artifacts. It never commits, pushes,
tags, or uploads to an application store.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

validate_version_name() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$label 必须是 X.Y.Z 格式，当前值: '$value'"
}

validate_positive_integer() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$label 必须是正整数，当前值: '$value'"
}

validate_branch() {
  local value="$1"
  [[ -n "$value" ]] || die "BRANCH 不能为空"
  [[ "$value" =~ ^[A-Za-z0-9._/-]+$ ]] || die "BRANCH 包含不安全字符: '$value'"
  [[ "$value" != -* && "$value" != *..* && "$value" != /* && "$value" != */ ]] || die "BRANCH 格式非法: '$value'"
}

find_single_file() {
  local pattern="$1"
  local description="$2"
  local search_dir="${pattern%/*}"
  local file_pattern="${pattern##*/}"
  local -a matches=()
  while IFS= read -r match; do
    matches+=("$match")
  done < <(find "$search_dir" -maxdepth 1 -type f -name "$file_pattern" -print 2>/dev/null | sort)
  [[ ${#matches[@]} -eq 1 ]] || die "期望找到 1 个${description}，实际找到 ${#matches[@]} 个"
  printf '%s\n' "${matches[0]}"
}

platform=""
branch=""
android_version_name=""
android_version_code=""
ios_version_name=""
ios_build_number=""
repo_dir=""
artifact_root=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) platform="${2:-}"; shift 2 ;;
    --branch) branch="${2:-}"; shift 2 ;;
    --android-version-name) android_version_name="${2:-}"; shift 2 ;;
    --android-version-code) android_version_code="${2:-}"; shift 2 ;;
    --ios-version-name) ios_version_name="${2:-}"; shift 2 ;;
    --ios-build-number) ios_build_number="${2:-}"; shift 2 ;;
    --repo-dir) repo_dir="${2:-}"; shift 2 ;;
    --artifact-dir) artifact_root="${2:-}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "未知参数: $1" ;;
  esac
done

[[ "$platform" == "android" || "$platform" == "ios" || "$platform" == "both" ]] || die "PLATFORM 必须是 android、ios 或 both"
validate_branch "$branch"

if [[ "$platform" == "android" || "$platform" == "both" ]]; then
  validate_version_name "ANDROID_VERSION_NAME" "$android_version_name"
  validate_positive_integer "ANDROID_VERSION_CODE" "$android_version_code"
fi
if [[ "$platform" == "ios" || "$platform" == "both" ]]; then
  validate_version_name "IOS_VERSION_NAME" "$ios_version_name"
  validate_positive_integer "IOS_BUILD_NUMBER" "$ios_build_number"
fi

if [[ "$dry_run" == true ]]; then
  echo "参数校验通过: platform=$platform branch=$branch"
  exit 0
fi

for tool in git flutter java python3 shasum unzip; do
  require_command "$tool"
done
[[ "$(uname -s)" == "Darwin" ]] || die "Android+iOS 打包机必须运行在 macOS"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="${repo_dir:-$(cd "$script_dir/../.." && pwd)}"
app_dir="$repo_dir/genesis_app"
[[ -d "$repo_dir/.git" ]] || die "repo-dir 不是 Git 仓库: $repo_dir"
[[ -f "$app_dir/pubspec.yaml" ]] || die "找不到 Flutter 工程: $app_dir"

artifact_root="${artifact_root:-$repo_dir/release_artifacts}"
commit_sha="$(git -C "$repo_dir" rev-parse HEAD)"
short_commit="$(git -C "$repo_dir" rev-parse --short=12 HEAD)"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-${short_commit}-${PPID}"
run_dir="$artifact_root/$run_id"

android_artifact=""
android_sha256=""
ios_artifact=""
ios_sha256=""

write_metadata() {
  local android_filename="${android_artifact##*/}"
  local ios_filename="${ios_artifact##*/}"
  python3 - \
    "$run_dir/release-metadata.json" \
    "$platform" \
    "$branch" \
    "$commit_sha" \
    "$build_time" \
    "$android_version_name" \
    "$android_version_code" \
    "$android_filename" \
    "$android_sha256" \
    "$ios_version_name" \
    "$ios_build_number" \
    "$ios_filename" \
    "$ios_sha256" <<'PY'
import json
import pathlib
import sys

(
    output_path,
    platform,
    branch,
    commit_sha,
    build_time,
    android_version_name,
    android_version_code,
    android_artifact,
    android_sha256,
    ios_version_name,
    ios_build_number,
    ios_artifact,
    ios_sha256,
) = sys.argv[1:]

payload = {
    "platform": platform,
    "branch": branch,
    "source_commit": commit_sha,
    "built_at_utc": build_time,
    "git_side_effects": False,
    "store_uploads": False,
    "android": {
        "version_name": android_version_name,
        "version_code": android_version_code,
        "artifact": android_artifact,
        "sha256": android_sha256,
    },
    "ios": {
        "version_name": ios_version_name,
        "build_number": ios_build_number,
        "artifact": ios_artifact,
        "sha256": ios_sha256,
    },
}
pathlib.Path(output_path).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
}

preflight_android() {
  require_command jarsigner
}

preflight_ios() {
  require_command codesign
  require_command security
  require_command xcodebuild
  [[ -x /usr/libexec/PlistBuddy ]] || die "缺少 /usr/libexec/PlistBuddy"
  security find-identity -v -p codesigning | grep -Eq '[1-9][0-9]* valid identities found' || {
    die "登录钥匙串没有有效的 Apple 代码签名身份。请先用当前 macOS 用户在 Xcode 中完成一次自动签名。"
  }
}

build_android() {
  echo "==> Android production Release AAB: $android_version_name+$android_version_code"
  (
    cd "$app_dir"
    flutter build appbundle \
      --flavor production \
      --release \
      --build-name "$android_version_name" \
      --build-number "$android_version_code"
  )

  local source_aab
  source_aab="$(find_single_file "$app_dir/build/app/outputs/bundle/productionRelease/*.aab" " Android AAB")"
  local metadata_file="$app_dir/build/app/intermediates/merged_manifests/productionRelease/processProductionReleaseManifest/output-metadata.json"
  [[ -f "$metadata_file" ]] || die "找不到 Android manifest 构建元数据: $metadata_file"

  python3 - "$metadata_file" "$android_version_name" "$android_version_code" <<'PY'
import json
import sys

path, expected_name, expected_code = sys.argv[1:]
data = json.load(open(path, encoding="utf-8"))
elements = data.get("elements") or []
if len(elements) != 1:
    raise SystemExit(f"ERROR: Android 构建元数据应只有 1 个元素，实际 {len(elements)} 个")
actual_id = data.get("applicationId")
actual_name = str(elements[0].get("versionName"))
actual_code = str(elements[0].get("versionCode"))
if actual_id != "com.worldo.ai":
    raise SystemExit(f"ERROR: applicationId={actual_id!r}，期望 'com.worldo.ai'")
if actual_name != expected_name:
    raise SystemExit(f"ERROR: versionName={actual_name!r}，期望 {expected_name!r}")
if actual_code != expected_code:
    raise SystemExit(f"ERROR: versionCode={actual_code!r}，期望 {expected_code!r}")
print(f"Android 元数据校验通过: {actual_id} {actual_name}+{actual_code}")
PY

  local verify_log="$run_dir/android-jarsigner-verify.txt"
  jarsigner \
    -J-Duser.language=en \
    -J-Duser.country=US \
    -verify \
    -verbose \
    -certs \
    "$source_aab" >"$verify_log" 2>&1 || {
    sed -n '1,160p' "$verify_log" >&2
    die "AAB jarsigner 校验失败"
  }
  grep -Fq "jar verified." "$verify_log" || die "AAB 未通过 jarsigner 验证"
  unzip -Z1 "$source_aab" >"$run_dir/android-aab-entries.txt"
  grep -Eq '^META-INF/[^/]+\.(RSA|DSA|EC)$' "$run_dir/android-aab-entries.txt" || die "AAB 中没有找到签名证书条目"

  android_artifact="$run_dir/Worldo-android-${android_version_name}+${android_version_code}.aab"
  cp "$source_aab" "$android_artifact"
  android_sha256="$(shasum -a 256 "$android_artifact" | awk '{print $1}')"
  printf '%s  %s\n' "$android_sha256" "${android_artifact##*/}" >"$android_artifact.sha256"
  echo "Android AAB 校验完成: $android_artifact"
}

build_ios() {
  echo "==> iOS production Release IPA: $ios_version_name ($ios_build_number)"
  (
    cd "$app_dir"
    flutter build ipa \
      --flavor production \
      --release \
      --build-name "$ios_version_name" \
      --build-number "$ios_build_number" \
      --export-method app-store
  )

  local source_ipa
  source_ipa="$(find_single_file "$app_dir/build/ios/ipa/*.ipa" " iOS IPA")"
  local unpack_dir="$run_dir/ipa-unpacked"
  mkdir -p "$unpack_dir"
  unzip -q "$source_ipa" -d "$unpack_dir"

  local -a apps=("$unpack_dir"/Payload/*.app)
  [[ ${#apps[@]} -eq 1 && -d "${apps[0]}" ]] || die "IPA 中必须恰好有 1 个 Payload/*.app"
  local app_bundle="${apps[0]}"
  local info_plist="$app_bundle/Info.plist"
  local actual_bundle_id actual_version actual_build
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
  actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
  actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
  [[ "$actual_bundle_id" == "com.worldo.ai" ]] || die "Bundle ID=$actual_bundle_id，期望 com.worldo.ai"
  [[ "$actual_version" == "$ios_version_name" ]] || die "iOS version=$actual_version，期望 $ios_version_name"
  [[ "$actual_build" == "$ios_build_number" ]] || die "iOS build=$actual_build，期望 $ios_build_number"
  [[ -f "$app_bundle/embedded.mobileprovision" ]] || die "IPA 缺少 embedded.mobileprovision"
  codesign --verify --deep --strict --verbose=2 "$app_bundle"

  ios_artifact="$run_dir/Worldo-ios-${ios_version_name}+${ios_build_number}.ipa"
  cp "$source_ipa" "$ios_artifact"
  ios_sha256="$(shasum -a 256 "$ios_artifact" | awk '{print $1}')"
  printf '%s  %s\n' "$ios_sha256" "${ios_artifact##*/}" >"$ios_artifact.sha256"
  rm -rf "$unpack_dir"
  echo "iOS IPA 校验完成: $ios_artifact"
}

if [[ "$platform" == "android" || "$platform" == "both" ]]; then
  preflight_android
fi
if [[ "$platform" == "ios" || "$platform" == "both" ]]; then
  preflight_ios
fi

mkdir -p "$run_dir"
cd "$app_dir"
flutter clean
flutter pub get

if [[ "$platform" == "android" || "$platform" == "both" ]]; then
  build_android
fi
if [[ "$platform" == "ios" || "$platform" == "both" ]]; then
  build_ios
fi

write_metadata
echo "==> 完成，产物目录: $run_dir"
echo "本次没有 commit、push、tag 或商店上传。"
