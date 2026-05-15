#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

name="${1:-ios-ui}"
require_cmd xcrun

out="$SCREENSHOT_DIR/$(timestamp)-$name.png"
xcrun simctl io booted screenshot "$out"

if [ ! -s "$out" ]; then
  printf 'Screenshot failed or empty: %s\n' "$out" >&2
  exit 1
fi

printf '%s\n' "$out"

