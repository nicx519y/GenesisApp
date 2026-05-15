#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'HELP'
Usage: bash agent_workflow/scripts/run_module_regression.sh <module> [--ui] [--install]

Examples:
  bash agent_workflow/scripts/run_module_regression.sh me
  bash agent_workflow/scripts/run_module_regression.sh me --ui --install
  bash agent_workflow/scripts/run_module_regression.sh messages --ui

The script always runs static verification. With --ui, it also runs a matching
Maestro flow directory or file when present under module_cases/<module>/maestro/.
HELP
}

module="${1:-}"
run_ui=0
install_app=0

if [ -z "$module" ]; then
  usage
  exit 2
fi
shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ui)
      run_ui=1
      ;;
    --install)
      install_app=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

case_dir="$WORKFLOW_ROOT/module_cases/$module"
if [ ! -d "$case_dir" ]; then
  printf 'Module case directory not found: %s\n' "$case_dir" >&2
  exit 2
fi

report="$REPORT_DIR/module-$module-regression-$(timestamp).log"
printf 'GenesisApp module regression\n' | tee "$report"
printf 'Module: %s\n' "$module" | tee -a "$report"
printf 'Cases: %s\n' "$case_dir/cases.md" | tee -a "$report"

run_logged "$report" bash "$SCRIPT_DIR/run_static_verify.sh"

if [ "$run_ui" -eq 1 ]; then
  flow="$case_dir/maestro"
  if [ -d "$flow" ] || [ -f "$flow" ]; then
    args=(bash "$SCRIPT_DIR/run_ui_smoke.sh" --platform android --flow "$flow")
    if [ "$install_app" -eq 1 ]; then
      args+=(--install)
    fi
    run_logged "$report" "${args[@]}"
  else
    printf 'SKIP UI flow: %s not found\n' "$flow" | tee -a "$report"
  fi
fi

printf '\nPASS module regression\nReport: %s\n' "$report" | tee -a "$report"
