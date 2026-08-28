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
  --version-name 1.2.3
  --version-code 123
)

expect_success --platform android --build-type release "${common[@]}"
expect_success --platform android --build-type debug "${common[@]}"
expect_success --platform android --build-type aab "${common[@]}"
expect_success --platform ios --build-type release "${common[@]}"
expect_success --platform ios --build-type debug "${common[@]}"

expect_failure --platform desktop --build-type release "${common[@]}"
expect_failure --platform ios --build-type aab "${common[@]}"
expect_failure --platform android --build-type profile "${common[@]}"
expect_failure --platform android --build-type release --branch ../main --version-name 1.2.3 --version-code 1
expect_failure --platform android --build-type release --branch main --version-name 1.2 --version-code 1
expect_failure --platform android --build-type release --branch main --version-name 1.2.3 --version-code 0
expect_failure --platform android --build-type aab --branch main --version-name 1.2.3 --version-code ""

echo "tools/jenkins/local_release.sh 参数校验测试通过"
