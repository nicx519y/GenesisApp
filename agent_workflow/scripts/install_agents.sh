#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

target="$PROJECT_ROOT/.codex/agents"
mkdir -p "$target"

for file in "$WORKFLOW_ROOT"/agents/*.toml; do
  cp "$file" "$target/$(basename "$file")"
  log "installed $(basename "$file") -> $target"
done

log "done"

