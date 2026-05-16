#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

feature="${1:-}"

if [ -z "$feature" ]; then
  cat <<'HELP'
Usage: bash agent_workflow/scripts/init_checkpoint.sh <feature>

Creates agent_workflow/progress/<feature>/checkpoint.md when missing.
HELP
  exit 2
fi

safe_feature="$(printf '%s' "$feature" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
if [ -z "$safe_feature" ]; then
  printf 'Invalid feature: %s\n' "$feature" >&2
  exit 2
fi

dir="$WORKFLOW_ROOT/progress/$safe_feature"
file="$dir/checkpoint.md"
template="$WORKFLOW_ROOT/templates/checkpoint.md"

mkdir -p "$dir"

if [ -f "$file" ]; then
  printf '%s\n' "$file"
  exit 0
fi

if [ ! -f "$template" ]; then
  printf 'Missing template: %s\n' "$template" >&2
  exit 1
fi

sed "s/<feature>/$safe_feature/g" "$template" > "$file"
printf -- '- %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" >> "$file"

printf '%s\n' "$file"

