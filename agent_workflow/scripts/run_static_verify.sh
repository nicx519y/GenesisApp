#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

build_apk=0
build_ios=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --build-apk)
      build_apk=1
      ;;
    --build-ios)
      build_ios=1
      ;;
    -h|--help)
      cat <<'HELP'
Usage: bash agent_workflow/scripts/run_static_verify.sh [--build-apk] [--build-ios]

Runs flutter analyze and flutter test in genesis_app/.
Optional flags add native build gates.
HELP
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

ensure_app_dir
require_cmd flutter

report="$REPORT_DIR/static-verify-$(timestamp).log"
printf 'GenesisApp static verification\n' | tee "$report"
printf 'App dir: %s\n' "$APP_DIR" | tee -a "$report"

cd "$APP_DIR"
run_logged "$report" flutter pub get
run_logged "$report" flutter analyze
run_logged "$report" flutter test

if [ "$build_apk" -eq 1 ]; then
  run_logged "$report" flutter build apk --debug
fi

if [ "$build_ios" -eq 1 ]; then
  run_logged "$report" flutter build ios --simulator --no-codesign
fi

printf '\nPASS static verification\nReport: %s\n' "$report" | tee -a "$report"

