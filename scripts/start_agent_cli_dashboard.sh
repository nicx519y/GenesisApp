#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
app_dir="$repo_dir/genesis_app"
entrypoint="$repo_dir/tools/agent_cli/run-with-dashboard"

usage() {
  cat <<'EOF'
Usage:
  scripts/start_agent_cli_dashboard.sh
  scripts/start_agent_cli_dashboard.sh -d <device-id>
  scripts/start_agent_cli_dashboard.sh --profile
  scripts/start_agent_cli_dashboard.sh --release

Starts tools/agent_cli and tools/location_chat_debug_dashboard together.
All Flutter arguments are forwarded to tools/agent_cli/run-with-dashboard, so
Flutter build-mode flags such as --profile and --release are supported.

When no -d/--device-id is passed and the script is running in an interactive
terminal, it lists connected Flutter devices and lets you choose one.

Environment:
  GENESIS_SELECT_DEVICE=false  Disable the interactive device picker.
EOF
}

has_device_arg() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "-d" || "$arg" == "--device-id" || "$arg" == --device-id=* ]]; then
      return 0
    fi
  done
  return 1
}

load_devices() {
  (
    cd "$app_dir"
    flutter devices --machine
  ) | python3 -c '
import json
import sys

try:
    devices = json.load(sys.stdin)
except Exception as error:
    print(f"Failed to parse flutter devices output: {error}", file=sys.stderr)
    sys.exit(1)

for device in devices:
    if not device.get("isSupported", True):
        continue
    device_id = str(device.get("id", "")).strip()
    if not device_id:
        continue
    name = str(device.get("name", "")).strip()
    platform = str(device.get("targetPlatform", "")).strip()
    sdk = str(device.get("sdk", "")).strip()
    print("\t".join([device_id, name, platform, sdk]))
'
}

select_device_args() {
  if has_device_arg "$@"; then
    return 0
  fi
  if [[ "${GENESIS_SELECT_DEVICE:-true}" == "false" || ! -t 0 ]]; then
    return 0
  fi
  if ! command -v flutter >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  local rows
  if ! rows="$(load_devices)"; then
    return 0
  fi
  if [[ -z "$rows" ]]; then
    echo "No supported Flutter devices found; letting flutter choose." >&2
    return 0
  fi

  local ids=()
  local labels=()
  local id name platform sdk label
  while IFS=$'\t' read -r id name platform sdk; do
    [[ -n "$id" ]] || continue
    label="$name"
    [[ -n "$platform" ]] && label="$label, $platform"
    [[ -n "$sdk" ]] && label="$label, $sdk"
    ids+=("$id")
    labels+=("$label")
  done <<<"$rows"

  if [[ "${#ids[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "Select Flutter device:" >&2
  local index
  for index in "${!ids[@]}"; do
    printf '  %d) %s [%s]\n' "$((index + 1))" "${labels[$index]}" "${ids[$index]}" >&2
  done
  echo "  0) Let flutter choose" >&2

  local choice
  while true; do
    printf 'Device [1-%d, 0]: ' "${#ids[@]}" >&2
    read -r choice
    choice="${choice:-1}"
    if [[ "$choice" == "0" ]]; then
      return 0
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ids[@]} )); then
      printf '%s\n' "-d"
      printf '%s\n' "${ids[$((choice - 1))]}"
      return 0
    fi
    echo "Invalid selection: $choice" >&2
  done
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ ! -x "$entrypoint" ]]; then
  echo "Missing executable entrypoint: $entrypoint" >&2
  exit 1
fi

device_args=()
while IFS= read -r arg; do
  device_args+=("$arg")
done < <(select_device_args "$@")

exec "$entrypoint" "${device_args[@]}" "$@"
