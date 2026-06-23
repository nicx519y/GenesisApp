#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DEVICE_ID="10AD4Y0NLN003XN"
DEFAULT_PROXY_PORT="9090"
DEFAULT_PACKAGE_NAME="com.worldo.ai"
DEFAULT_INSTALL_TIMEOUT_SECONDS="120"

usage() {
  cat <<'USAGE'
Usage:
  scripts/start_packet_capture.sh [-d <device-id>] [--proxy-port <port>] [--package <package-name>] [--quick] [--global-proxy]
  scripts/start_packet_capture.sh --clear-global-proxy

What it does:
  1. Keeps the phone global proxy disabled by default so Wi-Fi/VPN still works.
  2. Restores adb reverse: phone 127.0.0.1:<port> -> Mac 127.0.0.1:<port>.
  3. Builds and installs the debug app with GENESIS_DEBUG_PROXY=127.0.0.1:<port>.
  4. Launches the app.

Options:
  --quick   Restore adb reverse and relaunch the app. Do not rebuild/reinstall.
  --global-proxy
            Set Android global proxy to 127.0.0.1:<port>. This keeps capture active
            after killing/relaunching the app while USB adb reverse is alive.
  --clear-global-proxy
            Clear Android global proxy and exit.

Environment overrides:
  GENESIS_DEVICE_ID
  GENESIS_PROXY_PORT
  GENESIS_PACKAGE_NAME
  GENESIS_INSTALL_TIMEOUT_SECONDS
USAGE
}

device_id="${GENESIS_DEVICE_ID:-$DEFAULT_DEVICE_ID}"
proxy_port="${GENESIS_PROXY_PORT:-$DEFAULT_PROXY_PORT}"
package_name="${GENESIS_PACKAGE_NAME:-$DEFAULT_PACKAGE_NAME}"
install_timeout_seconds="${GENESIS_INSTALL_TIMEOUT_SECONDS:-$DEFAULT_INSTALL_TIMEOUT_SECONDS}"
quick=0
global_proxy=0
clear_global_proxy=0

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--device)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for $1" >&2
        exit 2
      fi
      device_id="$2"
      shift 2
      ;;
    --proxy-port)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --proxy-port" >&2
        exit 2
      fi
      proxy_port="$2"
      shift 2
      ;;
    --package)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --package" >&2
        exit 2
      fi
      package_name="$2"
      shift 2
      ;;
    --quick)
      quick=1
      shift
      ;;
    --global-proxy)
      global_proxy=1
      shift
      ;;
    --clear-global-proxy)
      clear_global_proxy=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/genesis_app"
apk_path="$app_dir/build/app/outputs/flutter-apk/app-debug.apk"
proxy_define="GENESIS_DEBUG_PROXY=127.0.0.1:${proxy_port}"

echo "Device: ${device_id}"
echo "Proxy:  127.0.0.1:${proxy_port}"

adb -s "$device_id" get-state >/dev/null

clear_phone_global_proxy() {
  adb -s "$device_id" shell settings put global http_proxy :0
  adb -s "$device_id" shell settings delete global global_http_proxy_host >/dev/null 2>&1 || true
  adb -s "$device_id" shell settings delete global global_http_proxy_port >/dev/null 2>&1 || true
}

if ((clear_global_proxy)); then
  echo "Clearing phone global proxy..."
  clear_phone_global_proxy
  echo "Phone global proxy cleared."
  exit 0
fi

if ((global_proxy)); then
  echo "Setting phone global proxy to 127.0.0.1:${proxy_port}..."
  adb -s "$device_id" shell settings put global http_proxy "127.0.0.1:${proxy_port}"
else
  echo "Clearing phone global proxy..."
  clear_phone_global_proxy
fi

echo "Restoring adb reverse..."
adb -s "$device_id" reverse "tcp:${proxy_port}" "tcp:${proxy_port}"
adb -s "$device_id" reverse --list | grep "tcp:${proxy_port} tcp:${proxy_port}"

if ((quick)); then
  echo "Relaunching ${package_name}..."
  adb -s "$device_id" shell am force-stop "$package_name" >/dev/null 2>&1 || true
  adb -s "$device_id" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null
  echo "Quick mode complete. Trigger an app request and check Proxyman."
  exit 0
fi

echo "Building debug APK with ${proxy_define}..."
cd "$app_dir"
flutter build apk --debug --dart-define "$proxy_define"

echo "Installing debug APK..."
adb -s "$device_id" install -r "$apk_path" &
install_pid=$!
elapsed=0
while kill -0 "$install_pid" >/dev/null 2>&1; do
  if ((elapsed >= install_timeout_seconds)); then
    echo "Install timed out after ${install_timeout_seconds}s; keeping adb reverse and launching current app." >&2
    kill "$install_pid" >/dev/null 2>&1 || true
    wait "$install_pid" >/dev/null 2>&1 || true
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

if kill -0 "$install_pid" >/dev/null 2>&1; then
  wait "$install_pid"
else
  wait "$install_pid" || true
fi

echo "Launching ${package_name}..."
adb -s "$device_id" shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 >/dev/null

echo "Packet capture setup complete. Trigger an app request and check Proxyman."
