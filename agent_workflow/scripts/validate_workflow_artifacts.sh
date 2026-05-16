#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

feature="${1:-}"
shift || true
modules=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --module)
      modules+=("${2:-}")
      shift
      ;;
    -h|--help)
      cat <<'HELP'
Usage: bash agent_workflow/scripts/validate_workflow_artifacts.sh <feature> [--module <module> ...]

Checks that required workflow artifacts exist for a feature.
HELP
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$feature" ]; then
  printf 'Missing feature name\n' >&2
  exit 2
fi

status=0

check_file() {
  local path="$1"
  if [ -f "$path" ]; then
    printf 'PASS %s\n' "$path"
  else
    printf 'FAIL missing %s\n' "$path"
    status=1
  fi
}

check_dir() {
  local path="$1"
  if [ -d "$path" ]; then
    printf 'PASS %s\n' "$path"
  else
    printf 'FAIL missing %s\n' "$path"
    status=1
  fi
}

check_file "$WORKFLOW_ROOT/requirements/$feature.md"
check_file "$WORKFLOW_ROOT/tasks/$feature.md"
check_file "$WORKFLOW_ROOT/acceptance_tests/$feature.md"
check_file "$WORKFLOW_ROOT/plans/$feature.md"
check_file "$WORKFLOW_ROOT/progress/$feature/checkpoint.md"
check_dir "$WORKFLOW_ROOT/references/$feature"

for module in "${modules[@]}"; do
  [ -n "$module" ] || continue
  check_file "$WORKFLOW_ROOT/module_cases/$module/cases.md"
  check_file "$WORKFLOW_ROOT/module_cases/$module/manifest.yaml"
done

exit "$status"

