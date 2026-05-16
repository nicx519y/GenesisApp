#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

base_ref="${1:-HEAD}"
map_file="$WORKFLOW_ROOT/module_cases/module-map.yaml"

if [ ! -f "$map_file" ]; then
  printf 'Missing module map: %s\n' "$map_file" >&2
  exit 2
fi

cd "$PROJECT_ROOT"

changed_files="$(
  {
    git diff --name-only "$base_ref" -- .
    git ls-files --others --exclude-standard
  } | sort -u
)"

if [ -z "$changed_files" ]; then
  exit 0
fi

awk '
  /^[[:space:]]{2}[a-zA-Z0-9_-]+:/ {
    module=$1
    sub(/:$/, "", module)
    next
  }
  /^[[:space:]]{6}-[[:space:]]+/ && module != "" {
    line=$0
    sub(/^[[:space:]]*-[[:space:]]+/, "", line)
    print module "\t" line
  }
' "$map_file" | while IFS="$(printf '\t')" read -r module prefix; do
  printf '%s\n' "$changed_files" | while IFS= read -r file; do
    case "$file" in
      "$prefix"* )
        printf '%s\n' "$module"
        ;;
    esac
  done
done | sort -u
