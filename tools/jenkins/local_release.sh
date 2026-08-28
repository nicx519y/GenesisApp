#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/jenkins/local_release.sh --platform android|ios \
    --build-type release|debug|aab --branch BRANCH \
    --version-name X.Y.Z --version-code N \
    [--repo-dir PATH] [--artifact-dir PATH] [--dry-run]

Android release/debug generate a production-flavor APK containing only arm64-v8a.
Android aab generates a signed production Release app bundle for Google Play.
iOS release/debug generate a signed production-flavor IPA; iOS does not support aab.
This script never commits, pushes, tags, or uploads to an application store.
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
  local value="$1"
  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION_NAME 必须是 X.Y.Z 格式，当前值: '$value'"
}

validate_positive_integer() {
  local value="$1"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "VERSION_CODE 必须是正整数，当前值: '$value'"
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

resolve_android_build_tool() {
  local tool_name="$1"
  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return
  fi

  local properties_file="$app_dir/android/local.properties"
  local sdk_dir=""
  if [[ -f "$properties_file" ]]; then
    sdk_dir="$(sed -n 's/^sdk\.dir=//p' "$properties_file" | head -n 1)"
  fi
  [[ -n "$sdk_dir" && -d "$sdk_dir/build-tools" ]] || die "无法从 android/local.properties 找到 Android SDK build-tools"

  local resolved=""
  resolved="$(find "$sdk_dir/build-tools" -mindepth 2 -maxdepth 2 -type f -name "$tool_name" -print | sort | tail -n 1)"
  [[ -n "$resolved" && -x "$resolved" ]] || die "Android SDK 中缺少 $tool_name"
  printf '%s\n' "$resolved"
}

platform=""
build_type=""
branch=""
version_name=""
version_code=""
repo_dir=""
artifact_root=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) platform="${2:-}"; shift 2 ;;
    --build-type) build_type="${2:-}"; shift 2 ;;
    --branch) branch="${2:-}"; shift 2 ;;
    --version-name) version_name="${2:-}"; shift 2 ;;
    --version-code) version_code="${2:-}"; shift 2 ;;
    --repo-dir) repo_dir="${2:-}"; shift 2 ;;
    --artifact-dir) artifact_root="${2:-}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "未知参数: $1" ;;
  esac
done

[[ "$platform" == "android" || "$platform" == "ios" ]] || {
  die "PLATFORM 必须是 android 或 ios"
}
[[ "$build_type" == "release" || "$build_type" == "debug" || "$build_type" == "aab" ]] || {
  die "BUILD_TYPE 必须是 release、debug 或 aab"
}
if [[ "$platform" == "ios" && "$build_type" == "aab" ]]; then
  die "iOS 不支持 aab；请选择 release 或 debug"
fi
validate_branch "$branch"
validate_version_name "$version_name"
validate_positive_integer "$version_code"

if [[ "$dry_run" == true ]]; then
  echo "参数校验通过: platform=$platform build_type=$build_type branch=$branch version=$version_name+$version_code"
  exit 0
fi

for tool in git flutter python3 shasum unzip; do
  require_command "$tool"
done
[[ "$(uname -s)" == "Darwin" ]] || die "Android/iOS 打包机必须运行在 macOS"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="${repo_dir:-$(cd "$script_dir/../.." && pwd)}"
app_dir="$repo_dir/genesis_app"
[[ -d "$repo_dir/.git" ]] || die "repo-dir 不是 Git 仓库: $repo_dir"
[[ -f "$app_dir/pubspec.yaml" ]] || die "找不到 Flutter 工程: $app_dir"

if [[ "$platform" == "android" ]]; then
  require_command java
else
  for tool in codesign lipo security xcodebuild; do
    require_command "$tool"
  done
  [[ -x /usr/libexec/PlistBuddy ]] || die "缺少 /usr/libexec/PlistBuddy"
  security find-identity -v -p codesigning | grep -Eq '[1-9][0-9]* valid identities found' || {
    die "登录钥匙串中没有有效的 Apple 代码签名证书；请先为 Jenkins 运行用户安装并解锁签名证书"
  }
fi

artifact_root="${artifact_root:-$repo_dir/outputs}"
commit_sha="$(git -C "$repo_dir" rev-parse HEAD)"
short_commit="$(git -C "$repo_dir" rev-parse --short=12 HEAD)"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-${short_commit}-${PPID}"
run_dir="$artifact_root/$run_id"
mkdir -p "$run_dir"

artifact=""
artifact_sha256=""
artifact_kind="apk"
artifact_architecture="arm64-v8a"
effective_build_type="$build_type"
distribution_method=""

validate_android_metadata() {
  local metadata_file="$1"
  [[ -f "$metadata_file" ]] || die "找不到 Android manifest 构建元数据: $metadata_file"

  python3 - "$metadata_file" "$version_name" "$version_code" <<'PY'
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
}

build_apk() {
  echo "==> Android production ${build_type} APK (arm64-v8a): $version_name+$version_code"
  (
    cd "$app_dir"
    ORG_GRADLE_PROJECT_worldoTargetAbi=arm64-v8a flutter build apk \
      --flavor production \
      "--${build_type}" \
      --target-platform android-arm64 \
      --build-name "$version_name" \
      --build-number "$version_code"
  )

  local source_apk
  source_apk="$(find_single_file "$app_dir/build/app/outputs/flutter-apk/app-production-${build_type}.apk" " Android arm64-v8a APK")"
  local variant_suffix="Release"
  [[ "$build_type" == "debug" ]] && variant_suffix="Debug"
  validate_android_metadata "$app_dir/build/app/intermediates/merged_manifests/production${variant_suffix}/processProduction${variant_suffix}Manifest/output-metadata.json"

  local apksigner
  apksigner="$(resolve_android_build_tool apksigner)"
  "$apksigner" verify --verbose --print-certs "$source_apk" >"$run_dir/android-apksigner-verify.txt"

  unzip -Z1 "$source_apk" >"$run_dir/android-apk-entries.txt"
  grep -Eq '^lib/arm64-v8a/' "$run_dir/android-apk-entries.txt" || die "APK 中没有 arm64-v8a 原生库"
  if grep -E '^lib/(armeabi-v7a|x86|x86_64)/' "$run_dir/android-apk-entries.txt" >/dev/null; then
    die "APK 中包含 arm64-v8a 以外的原生架构"
  fi

  artifact="$run_dir/Worldo-arm64-v8a-${version_name}-${version_code}-${build_type}.apk"
  cp "$source_apk" "$artifact"
}

build_aab() {
  artifact_kind="aab"
  artifact_architecture="universal"
  effective_build_type="release"
  echo "==> Android production Release AAB for Google Play: $version_name+$version_code"
  (
    cd "$app_dir"
    flutter build appbundle \
      --flavor production \
      --release \
      --build-name "$version_name" \
      --build-number "$version_code"
  )

  local source_aab
  source_aab="$(find_single_file "$app_dir/build/app/outputs/bundle/productionRelease/*.aab" " Android AAB")"
  validate_android_metadata "$app_dir/build/app/intermediates/merged_manifests/productionRelease/processProductionReleaseManifest/output-metadata.json"

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

  artifact="$run_dir/Worldo-universal-${version_name}-${version_code}-release.aab"
  cp "$source_aab" "$artifact"
}

build_ios_ipa() {
  artifact_kind="ipa"
  artifact_architecture="arm64"
  local export_method="app-store"
  [[ "$build_type" == "debug" ]] && export_method="development"
  distribution_method="$export_method"

  echo "==> iOS production ${build_type} IPA (${export_method}): $version_name+$version_code"
  (
    cd "$app_dir"
    flutter build ipa \
      --flavor production \
      "--${build_type}" \
      --build-name "$version_name" \
      --build-number "$version_code" \
      --export-method "$export_method"
  )

  local source_ipa
  source_ipa="$(find_single_file "$app_dir/build/ios/ipa/*.ipa" " iOS IPA")"
  unzip -Z1 "$source_ipa" >"$run_dir/ios-ipa-entries.txt"

  local unpack_dir="$run_dir/.ipa-verify"
  mkdir -p "$unpack_dir"
  unzip -q "$source_ipa" -d "$unpack_dir"

  local -a app_bundles=("$unpack_dir"/Payload/*.app)
  [[ ${#app_bundles[@]} -eq 1 && -d "${app_bundles[0]}" ]] || {
    die "IPA 中必须恰好包含 1 个 Payload/*.app"
  }

  local app_bundle="${app_bundles[0]}"
  local info_plist="$app_bundle/Info.plist"
  [[ -f "$info_plist" ]] || die "IPA 中缺少 Info.plist"

  local actual_bundle_id actual_version actual_build executable_name executable_path executable_archs
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
  actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
  actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist")"
  executable_path="$app_bundle/$executable_name"

  [[ "$actual_bundle_id" == "com.worldo.ai" ]] || die "iOS Bundle ID=$actual_bundle_id，期望 com.worldo.ai"
  [[ "$actual_version" == "$version_name" ]] || die "iOS version=$actual_version，期望 $version_name"
  [[ "$actual_build" == "$version_code" ]] || die "iOS build=$actual_build，期望 $version_code"
  [[ -f "$app_bundle/embedded.mobileprovision" ]] || die "IPA 缺少 embedded.mobileprovision"
  [[ -f "$executable_path" ]] || die "IPA 缺少主可执行文件: $executable_name"

  executable_archs="$(lipo -archs "$executable_path")"
  [[ " $executable_archs " == *" arm64 "* ]] || die "iOS 主程序不包含 arm64: $executable_archs"
  [[ " $executable_archs " != *" x86_64 "* ]] || die "iOS IPA 不应包含 x86_64: $executable_archs"

  codesign --verify --deep --strict --verbose=2 "$app_bundle" >"$run_dir/ios-codesign-verify.txt" 2>&1 || {
    sed -n '1,160p' "$run_dir/ios-codesign-verify.txt" >&2
    die "iOS App codesign 校验失败"
  }
  codesign -dv --verbose=4 "$app_bundle" >"$run_dir/ios-codesign-details.txt" 2>&1

  artifact="$run_dir/Worldo-arm64-${version_name}-${version_code}-${build_type}.ipa"
  cp "$source_ipa" "$artifact"
  [[ "$unpack_dir" == "$run_dir/.ipa-verify" && -d "$unpack_dir" ]] || {
    die "拒绝清理非预期的 IPA 临时目录: $unpack_dir"
  }
  rm -rf -- "$unpack_dir"

  echo "iOS 元数据校验通过: $actual_bundle_id $actual_version+$actual_build ($executable_archs)"
}

write_metadata() {
  local filename="${artifact##*/}"
  python3 - \
    "$run_dir/release-metadata.json" \
    "$platform" \
    "$branch" \
    "$commit_sha" \
    "$build_time" \
    "$build_type" \
    "$effective_build_type" \
    "$artifact_kind" \
    "$artifact_architecture" \
    "$distribution_method" \
    "$version_name" \
    "$version_code" \
    "$filename" \
    "$artifact_sha256" <<'PY'
import json
import pathlib
import sys

(
    output_path,
    platform,
    branch,
    commit_sha,
    build_time,
    requested_build_type,
    effective_build_type,
    artifact_kind,
    architecture,
    distribution_method,
    version_name,
    version_code,
    artifact,
    sha256,
) = sys.argv[1:]

payload = {
    "platform": platform,
    "branch": branch,
    "source_commit": commit_sha,
    "built_at_utc": build_time,
    "git_side_effects": False,
    "store_uploads": False,
}

artifact_details = {
    "flavor": "production",
    "requested_build_type": requested_build_type,
    "effective_build_type": effective_build_type,
    "artifact_kind": artifact_kind,
    "architecture": architecture,
    "version_name": version_name,
    "artifact": artifact,
    "sha256": sha256,
}

if platform == "android":
    artifact_details.update({
        "application_id": "com.worldo.ai",
        "version_code": version_code,
    })
else:
    artifact_details.update({
        "bundle_id": "com.worldo.ai",
        "build_number": version_code,
        "distribution_method": distribution_method,
    })

payload[platform] = artifact_details
pathlib.Path(output_path).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
}

cd "$app_dir"
flutter clean
flutter pub get

if [[ "$platform" == "ios" ]]; then
  build_ios_ipa
elif [[ "$build_type" == "aab" ]]; then
  require_command jarsigner
  build_aab
else
  build_apk
fi

artifact_sha256="$(shasum -a 256 "$artifact" | awk '{print $1}')"
printf '%s  %s\n' "$artifact_sha256" "${artifact##*/}" >"$artifact.sha256"
write_metadata

echo "${platform} 产物校验完成: $artifact"
