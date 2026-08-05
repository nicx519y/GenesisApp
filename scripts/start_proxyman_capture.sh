#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PROXY_PORT="9090"

usage() {
  cat <<'USAGE'
Usage:
  scripts/start_proxyman_capture.sh [capture options]

Examples:
  scripts/start_proxyman_capture.sh
  scripts/start_proxyman_capture.sh --quick
  scripts/start_proxyman_capture.sh -d <device-id> --proxy-port 9090
  scripts/start_proxyman_capture.sh --clear-global-proxy

This wrapper:
  1. Selects the only connected Android device when -d is omitted.
  2. Checks that Proxyman is listening on the selected port.
  3. Delegates build/install/launch to scripts/start_packet_capture.sh.

The default path uses USB adb reverse and injects:
  GENESIS_DEBUG_PROXY=127.0.0.1:<port>
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
capture_script="$repo_root/scripts/start_packet_capture.sh"
device_id="${GENESIS_DEVICE_ID:-}"
proxy_port="${GENESIS_PROXY_PORT:-$DEFAULT_PROXY_PORT}"
skip_listener_check=0
args=("$@")

for ((index = 0; index < ${#args[@]}; index++)); do
  case "${args[$index]}" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--device)
      index=$((index + 1))
      if ((index >= ${#args[@]})); then
        echo "Missing value for ${args[$((index - 1))]}" >&2
        exit 2
      fi
      device_id="${args[$index]}"
      ;;
    --proxy-port)
      index=$((index + 1))
      if ((index >= ${#args[@]})); then
        echo "Missing value for --proxy-port" >&2
        exit 2
      fi
      proxy_port="${args[$index]}"
      ;;
    --clear-global-proxy)
      skip_listener_check=1
      ;;
  esac
done

if [[ ! -x "$capture_script" ]]; then
  echo "Capture script is missing or not executable: $capture_script" >&2
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb was not found. Install Android platform-tools first." >&2
  exit 1
fi

if [[ -z "$device_id" ]]; then
  device_ids=()
  while IFS= read -r connected_device; do
    [[ -n "$connected_device" ]] && device_ids+=("$connected_device")
  done < <(adb devices | awk 'NR > 1 && $2 == "device" {print $1}')

  if ((${#device_ids[@]} == 0)); then
    echo "No online Android device found. Connect a device with USB debugging enabled." >&2
    exit 1
  fi

  if ((${#device_ids[@]} > 1)); then
    echo "More than one Android device is online:" >&2
    printf '  %s\n' "${device_ids[@]}" >&2
    echo "Select one with: $0 -d <device-id>" >&2
    exit 1
  fi

  device_id="${device_ids[0]}"
fi

if [[ ! "$proxy_port" =~ ^[0-9]+$ ]] || ((proxy_port < 1 || proxy_port > 65535)); then
  echo "Invalid proxy port: $proxy_port" >&2
  exit 2
fi

if ((skip_listener_check == 0)); then
  if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof was not found; cannot verify the Proxyman listener on port $proxy_port." >&2
    exit 1
  fi

  listener="$(lsof -nP -iTCP:"$proxy_port" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$listener" ]]; then
    echo "Nothing is listening on port $proxy_port." >&2
    echo "Start Proxyman and set its proxy port to $proxy_port, then retry." >&2
    exit 1
  fi

  if ! grep -qi 'Proxyman' <<<"$listener"; then
    echo "Port $proxy_port is in use, but the listener does not appear to be Proxyman:" >&2
    printf '%s\n' "$listener" >&2
    exit 1
  fi
fi

echo "Android device: $device_id"
if ((skip_listener_check == 0)); then
  echo "Proxyman port:  $proxy_port"
fi

export GENESIS_DEVICE_ID="$device_id"
export GENESIS_PROXY_PORT="$proxy_port"
exec "$capture_script" "$@"
