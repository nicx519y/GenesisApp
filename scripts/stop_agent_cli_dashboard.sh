#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
dashboard_dir="$repo_dir/tools/location_chat_debug_dashboard"

dashboard_port="${GENESIS_DASHBOARD_PORT:-${PORT:-17318}}"
agent_port="${GENESIS_AGENT_CONTROL_PORT:-17317}"
adb_bin="${ADB:-adb}"
force="${FORCE:-false}"

usage() {
  cat <<'EOF'
Usage:
  scripts/stop_agent_cli_dashboard.sh

Stops the local location chat debug dashboard and removes the adb forward used
by the agent CLI dashboard flow.

Environment:
  GENESIS_DASHBOARD_PORT      Dashboard port. Default: 17318.
  GENESIS_AGENT_CONTROL_PORT  Agent control port. Default: 17317.
  ADB                         adb binary path. Default: adb.
  FORCE=true                  Kill whatever is listening on the dashboard port.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

dashboard_pids() {
  lsof -nP -t -iTCP:"$dashboard_port" -sTCP:LISTEN 2>/dev/null || true
}

pid_cwd() {
  lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
}

is_dashboard_pid() {
  local pid="$1"
  local cwd
  cwd="$(pid_cwd "$pid")"
  [[ "$cwd" == "$dashboard_dir" ]]
}

stopped_any=false

while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  if [[ "$force" == "true" ]] || is_dashboard_pid "$pid"; then
    echo "Stopping dashboard process $pid on port $dashboard_port..."
    kill "$pid" >/dev/null 2>&1 || true
    stopped_any=true
  else
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    echo "Skipping non-dashboard process $pid on port $dashboard_port: $command" >&2
    echo "Set FORCE=true to stop it anyway." >&2
  fi
done < <(dashboard_pids)

if [[ "$stopped_any" == "true" ]]; then
  sleep 0.5
fi

if [[ -z "$(dashboard_pids)" ]]; then
  echo "Dashboard port $dashboard_port is clear."
else
  echo "Dashboard port $dashboard_port is still in use." >&2
fi

if command -v "$adb_bin" >/dev/null 2>&1; then
  "$adb_bin" forward --remove "tcp:$agent_port" >/dev/null 2>&1 || true
  echo "Removed adb forward tcp:$agent_port if it existed."
else
  echo "adb not found; skipped adb forward cleanup."
fi
