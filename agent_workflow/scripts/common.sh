#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$WORKFLOW_ROOT/.." && pwd)"
APP_DIR="${GENESIS_APP_DIR:-$PROJECT_ROOT/genesis_app}"
APP_ID="${GENESIS_APP_ID:-com.genesis.ai}"
REPORT_DIR="${GENESIS_WORKFLOW_REPORT_DIR:-$WORKFLOW_ROOT/reports}"
SCREENSHOT_DIR="${GENESIS_WORKFLOW_SCREENSHOT_DIR:-$WORKFLOW_ROOT/screenshots}"
MAESTRO_DIR="${GENESIS_WORKFLOW_MAESTRO_DIR:-$WORKFLOW_ROOT/maestro}"

mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"

if [ -d "$HOME/.maestro/bin" ]; then
  export PATH="$PATH:$HOME/.maestro/bin"
fi

export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-true}"

if ! java -version >/dev/null 2>&1; then
  if [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
  elif [ -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

log() {
  printf '[agent-workflow] %s\n' "$*"
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'missing command: %s\n' "$name"
    return 1
  fi
}

ensure_app_dir() {
  if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
    printf 'Flutter app root not found: %s\n' "$APP_DIR" >&2
    exit 2
  fi
}

run_logged() {
  local log_file="$1"
  shift
  log "running: $*"
  {
    printf '\n$ %s\n' "$*"
    "$@"
  } 2>&1 | tee -a "$log_file"
}
