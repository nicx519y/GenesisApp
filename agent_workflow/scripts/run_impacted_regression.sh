#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

base_ref="HEAD"
run_ui=0
install_app=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      base_ref="${2:-HEAD}"
      shift
      ;;
    --ui)
      run_ui=1
      ;;
    --install)
      install_app=1
      ;;
    -h|--help)
      cat <<'HELP'
Usage: bash agent_workflow/scripts/run_impacted_regression.sh [--base <ref>] [--ui] [--install]

Detects impacted modules from git diff and runs module regression for each.
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

modules="$(bash "$SCRIPT_DIR/list_impacted_modules.sh" "$base_ref")"

if [ -z "$modules" ]; then
  printf 'No impacted modules detected from git diff against %s\n' "$base_ref"
  exit 0
fi

printf 'Impacted modules:\n%s\n' "$modules"

while IFS= read -r module; do
  [ -n "$module" ] || continue
  args=(bash "$SCRIPT_DIR/run_module_regression.sh" "$module")
  if [ "$run_ui" -eq 1 ]; then
    args+=(--ui)
  fi
  if [ "$install_app" -eq 1 ]; then
    args+=(--install)
    install_app=0
  fi
  "${args[@]}"
done <<< "$modules"

