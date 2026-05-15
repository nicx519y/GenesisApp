#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

name="${1:-android-ui}"
require_cmd adb

out="$SCREENSHOT_DIR/$(timestamp)-$name.png"
adb exec-out screencap -p > "$out"

if [ ! -s "$out" ]; then
  printf 'Screenshot failed or empty: %s\n' "$out" >&2
  exit 1
fi

printf '%s\n' "$out"

