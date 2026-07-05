#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PORT="${PORT:-17318}"
ADB="${ADB:-adb}"
SKIP_NPM_INSTALL="${SKIP_NPM_INSTALL:-false}"
SKIP_ADB_FORWARD="${SKIP_ADB_FORWARD:-false}"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required but was not found in PATH." >&2
  exit 1
fi

if [ "$SKIP_NPM_INSTALL" != "true" ]; then
  echo "Installing dashboard dependencies..."
  npm install
fi

if [ "$SKIP_ADB_FORWARD" != "true" ]; then
  if ! command -v "$ADB" >/dev/null 2>&1; then
    echo "adb is required but was not found in PATH." >&2
    echo "Set SKIP_ADB_FORWARD=true to start the dashboard without USB forwarding." >&2
    exit 1
  fi

  echo "Forwarding Android agent_control port tcp:17317 -> tcp:17317..."
  "$ADB" forward tcp:17317 tcp:17317
fi

echo "Starting dashboard at http://127.0.0.1:${PORT}/"
exec npm start
