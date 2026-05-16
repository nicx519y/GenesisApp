#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

feature="${1:-}"
if [ -z "$feature" ]; then
  cat <<'HELP'
Usage: bash agent_workflow/scripts/show_checkpoint.sh <feature>
HELP
  exit 2
fi

checkpoint="$(bash "$SCRIPT_DIR/init_checkpoint.sh" "$feature")"
sed -n '1,260p' "$checkpoint"
