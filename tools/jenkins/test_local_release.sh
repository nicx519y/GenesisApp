#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
release_script="$script_dir/local_release.sh"

expect_success() {
  "$release_script" "$@" --dry-run >/dev/null
}

expect_failure() {
  if "$release_script" "$@" --dry-run >/dev/null 2>&1; then
    echo "ERROR: 以下参数本应失败: $*" >&2
    exit 1
  fi
}

common=(
  --branch main
  --android-version-name 1.2.3
  --android-version-code 123
  --ios-version-name 1.2.3
  --ios-build-number 123
)

expect_success --platform android "${common[@]}"
expect_success --platform ios "${common[@]}"
expect_success --platform both "${common[@]}"

expect_failure --platform desktop "${common[@]}"
expect_failure --platform android --branch ../main --android-version-name 1.2.3 --android-version-code 1
expect_failure --platform android --branch main --android-version-name 1.2 --android-version-code 1
expect_failure --platform android --branch main --android-version-name 1.2.3 --android-version-code 0
expect_failure --platform ios --branch main --ios-version-name 1.2.3 --ios-build-number ""

echo "tools/jenkins/local_release.sh 参数校验测试通过"
