#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DEVICE_ID="1A101FDF6006AX"
DEFAULT_PROXY_PORT="9090"

usage() {
  cat <<'USAGE'
Usage:
  scripts/flutter_run_debug_proxy.sh [device-id] [flutter run args...]
  scripts/flutter_run_debug_proxy.sh -d <device-id> [--proxy-port <port>] [--dry-run] [--] [flutter run args...]

Environment overrides:
  GENESIS_DEVICE_ID    Device id used when -d/device-id is omitted.
  GENESIS_PROXY_HOST   Proxy host override; skips automatic LAN IP lookup.
  GENESIS_PROXY_PORT   Proxy port; defaults to 9090.

Examples:
  scripts/flutter_run_debug_proxy.sh
  scripts/flutter_run_debug_proxy.sh 1A101FDF6006AX
  scripts/flutter_run_debug_proxy.sh -d 1A101FDF6006AX -- --flavor dev
USAGE
}

device_id="${GENESIS_DEVICE_ID:-$DEFAULT_DEVICE_ID}"
proxy_port="${GENESIS_PROXY_PORT:-$DEFAULT_PROXY_PORT}"
dry_run=0
flutter_args=()

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
    --dry-run)
      dry_run=1
      shift
      ;;
    --)
      shift
      flutter_args+=("$@")
      break
      ;;
    -*)
      flutter_args+=("$1")
      shift
      ;;
    *)
      if [[ "$device_id" == "${GENESIS_DEVICE_ID:-$DEFAULT_DEVICE_ID}" ]]; then
        device_id="$1"
      else
        flutter_args+=("$1")
      fi
      shift
      ;;
  esac
done

default_interface() {
  route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
}

ip_for_interface() {
  local interface="$1"
  [[ -n "$interface" ]] || return 1

  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr "$interface" 2>/dev/null && return 0
  fi

  ifconfig "$interface" 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {print $2; exit}'
}

fallback_lan_ip() {
  if command -v networksetup >/dev/null 2>&1; then
    networksetup -getinfo Wi-Fi 2>/dev/null |
      awk -F': ' '/IP address:/ && $2 != "none" {print $2; exit}'
  fi
}

auto_proxy_host() {
  local interface ip
  interface="$(default_interface || true)"
  ip="$(ip_for_interface "$interface" || true)"
  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return 0
  fi

  ip="$(fallback_lan_ip || true)"
  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return 0
  fi

  ifconfig 2>/dev/null |
    awk '
      /^[a-z0-9]+:/{iface=$1; sub(":", "", iface)}
      /inet / && $2 !~ /^127\./ && iface !~ /^(bridge|awdl|llw|utun|lo)/ {print $2; exit}
    '
}

proxy_host="${GENESIS_PROXY_HOST:-$(auto_proxy_host)}"
if [[ -z "$proxy_host" ]]; then
  echo "Unable to determine LAN IP. Set GENESIS_PROXY_HOST manually." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/genesis_app"
proxy_define="GENESIS_DEBUG_PROXY=${proxy_host}:${proxy_port}"
cmd=(flutter run -d "$device_id" "--dart-define=$proxy_define")
if ((${#flutter_args[@]})); then
  cmd+=("${flutter_args[@]}")
fi

printf 'Using GENESIS_DEBUG_PROXY=%s\n' "${proxy_host}:${proxy_port}"
printf 'Running in %s\n' "$app_dir"

if ((dry_run)); then
  printf 'Command:'
  printf ' %q' "${cmd[@]}"
  printf '\n'
  exit 0
fi

cd "$app_dir"
exec "${cmd[@]}"
