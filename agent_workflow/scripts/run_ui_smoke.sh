#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

platform="android"
install_app=0
flow=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift
      ;;
    --install)
      install_app=1
      ;;
    --flow)
      flow="${2:-}"
      shift
      ;;
    -h|--help)
      cat <<'HELP'
Usage: bash agent_workflow/scripts/run_ui_smoke.sh [--platform android|ios] [--install] [--flow path]

Runs Maestro UI smoke flows and captures a screenshot.
For Android, --install builds and installs the debug APK first.
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
require_cmd maestro

report="$REPORT_DIR/ui-smoke-$platform-$(timestamp).log"
printf 'GenesisApp UI smoke verification\n' | tee "$report"
printf 'Platform: %s\n' "$platform" | tee -a "$report"
printf 'App id: %s\n' "$APP_ID" | tee -a "$report"

case "$platform" in
  android)
    require_cmd adb
    if [ "$install_app" -eq 1 ]; then
      require_cmd flutter
      cd "$APP_DIR"
      run_logged "$report" flutter build apk --debug
      run_logged "$report" adb install -r "$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
      cd "$PROJECT_ROOT"
    fi
    if [ -z "$flow" ]; then
      flow="$MAESTRO_DIR/android"
    fi
    run_logged "$report" maestro test "$flow"
    screenshot="$(bash "$SCRIPT_DIR/capture_android.sh" "$platform-smoke")"
    ;;
  ios)
    require_cmd xcrun
    if [ -z "$flow" ]; then
      flow="$MAESTRO_DIR/ios"
    fi
    run_logged "$report" maestro test "$flow"
    screenshot="$(bash "$SCRIPT_DIR/capture_ios.sh" "$platform-smoke")"
    ;;
  *)
    printf 'Unsupported platform: %s\n' "$platform" >&2
    exit 2
    ;;
esac

printf '\nPASS UI smoke verification\nScreenshot: %s\nReport: %s\n' "$screenshot" "$report" | tee -a "$report"

