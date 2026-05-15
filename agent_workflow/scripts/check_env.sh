#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

report="$REPORT_DIR/env-$(timestamp).log"
status=0

check() {
  local label="$1"
  shift
  if "$@" >>"$report" 2>&1; then
    printf 'PASS %s\n' "$label" | tee -a "$report"
  else
    printf 'FAIL %s\n' "$label" | tee -a "$report"
    status=1
  fi
}

printf 'GenesisApp agent workflow environment check\n' | tee "$report"
printf 'Project root: %s\n' "$PROJECT_ROOT" | tee -a "$report"
printf 'Flutter app: %s\n' "$APP_DIR" | tee -a "$report"
printf 'App id: %s\n\n' "$APP_ID" | tee -a "$report"

check "flutter app root" test -f "$APP_DIR/pubspec.yaml"
check "flutter" require_cmd flutter
check "dart" require_cmd dart
check "java 17+ runtime" java -version
check "adb" require_cmd adb
check "xcrun" require_cmd xcrun
check "maestro" require_cmd maestro

if command -v flutter >/dev/null 2>&1; then
  check "flutter doctor summary" flutter doctor -v
fi

if command -v adb >/dev/null 2>&1; then
  check "adb devices" adb devices
fi

if command -v xcrun >/dev/null 2>&1; then
  check "iOS simulator list" xcrun simctl list devices available
fi

printf '\nReport: %s\n' "$report"
exit "$status"
