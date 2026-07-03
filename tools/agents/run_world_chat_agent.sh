#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/../.." && pwd)"

CLI="$repo_dir/tools/agent_cli/ctl"
count="${GENESIS_WORLD_CHAT_COUNT:-20}"
location_count="${GENESIS_WORLD_CHAT_LOCATION_COUNT:-1}"
reply_timeout_seconds="${GENESIS_WORLD_CHAT_REPLY_TIMEOUT_SECONDS:-120}"
wid=""
location_id=""
seed_message=""
ping_retries="${GENESIS_AGENT_CLI_PING_RETRIES:-10}"
ping_interval_seconds="${GENESIS_AGENT_CLI_PING_INTERVAL_SECONDS:-2}"

log() {
  printf '[tools/agents] %s\n' "$*"
}

usage() {
  cat <<'EOF'
Usage:
  bash tools/agents/run_world_chat_agent.sh [options]

Legacy batch wrapper:
  This sends --count messages through the App-generated automation path.
  The Codex agent uses agent world-chat-open/world-chat-send instead so each
  message can be generated from the latest CLI-returned context.

Options:
  --wid <wid>                         Enter a specific world.
  --location-id <location_id>          Enter a specific location in that world.
  --count <n>                          Number of messages to send. Default: 20.
  --location-count <n>                 Number of locations to visit in one world. Default: 1.
  --reply-timeout-seconds <seconds>    Per-turn reply timeout. Default: 120.
  --seed-message <text>                First message. Default: app-generated.
  --no-wait                            Do not wait for the agent CLI port.

Defaults:
  Without --wid, the app picks a random eligible launched/joined world.
  Without --location-id, the app picks a random leaf location.

Prerequisite:
  Start the app + dashboard first:
    ./scripts/start_agent_cli_dashboard.sh
EOF
}

wait_for_cli=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wid|--world-id)
      wid="${2:-}"
      shift 2
      ;;
    --location-id)
      location_id="${2:-}"
      shift 2
      ;;
    --count|--messages)
      count="${2:-}"
      shift 2
      ;;
    --location-count|--locations)
      location_count="${2:-}"
      shift 2
      ;;
    --reply-timeout-seconds)
      reply_timeout_seconds="${2:-}"
      shift 2
      ;;
    --seed-message)
      seed_message="${2:-}"
      shift 2
      ;;
    --no-wait)
      wait_for_cli=false
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$CLI" ]]; then
  echo "Missing executable CLI: $CLI" >&2
  exit 2
fi

if ! [[ "$count" =~ ^[0-9]+$ ]] || (( count <= 0 )); then
  echo "--count must be a positive integer." >&2
  exit 2
fi

if ! [[ "$location_count" =~ ^[0-9]+$ ]] || (( location_count <= 0 )); then
  echo "--location-count must be a positive integer." >&2
  exit 2
fi

if ! [[ "$reply_timeout_seconds" =~ ^[0-9]+$ ]] || (( reply_timeout_seconds <= 0 )); then
  echo "--reply-timeout-seconds must be a positive integer." >&2
  exit 2
fi

if [[ "$wait_for_cli" == "true" ]]; then
  ready=false
  for ((attempt = 1; attempt <= ping_retries; attempt += 1)); do
    if "$CLI" app ping >/dev/null 2>&1; then
      ready=true
      break
    fi
    if (( attempt < ping_retries )); then
      sleep "$ping_interval_seconds"
    fi
  done
  if [[ "$ready" != "true" ]]; then
    echo "Agent CLI is not reachable." >&2
    echo "Start it first with: ./scripts/start_agent_cli_dashboard.sh" >&2
    exit 1
  fi
fi

args=(agent world-chat --count "$count" --location-count "$location_count" --reply-timeout-seconds "$reply_timeout_seconds")
if [[ -n "$wid" ]]; then
  args+=(--wid "$wid")
fi
if [[ -n "$location_id" ]]; then
  args+=(--location-id "$location_id")
fi
if [[ -n "$seed_message" ]]; then
  args+=(--seed-message "$seed_message")
fi

log "running world chat agent via CLI"
log "wid=${wid:-random} location_id=${location_id:-random} count=$count location_count=$location_count"
exec "$CLI" "${args[@]}"
