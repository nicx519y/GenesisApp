#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'HELP'
Usage: bash agent_workflow/scripts/run_module_regression.sh <module> [--ui] [--install] [--no-static]

Examples:
  bash agent_workflow/scripts/run_module_regression.sh me
  bash agent_workflow/scripts/run_module_regression.sh me --ui --install
  bash agent_workflow/scripts/run_module_regression.sh messages --ui

The script runs module tests from module_cases/<module>/manifest.yaml.
It falls back to static verification when no module tests are listed.
With --ui, it also runs Maestro flows listed in the manifest.
HELP
}

module="${1:-}"
run_ui=0
install_app=0
run_static=1

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
    --no-static)
      run_static=0
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
manifest="$case_dir/manifest.yaml"
printf 'GenesisApp module regression\n' | tee "$report"
printf 'Module: %s\n' "$module" | tee -a "$report"
printf 'Cases: %s\n' "$case_dir/cases.md" | tee -a "$report"
printf 'Manifest: %s\n' "$manifest" | tee -a "$report"

if [ ! -f "$manifest" ]; then
  printf 'Missing manifest: %s\n' "$manifest" >&2
  exit 2
fi

test_count=0
while IFS= read -r command_line; do
  [ -n "$command_line" ] || continue
  test_count=$((test_count + 1))
  run_logged "$report" bash -lc "cd '$APP_DIR' && $command_line"
done < <(awk '
  /^tests:/ { in_tests=1; next }
  /^[a-zA-Z_][a-zA-Z0-9_-]*:/ { if (in_tests) exit }
  in_tests && /^[[:space:]]*-[[:space:]]+/ {
    line=$0
    sub(/^[[:space:]]*-[[:space:]]+/, "", line)
    print line
  }
' "$manifest")

if [ "$test_count" -eq 0 ] && [ "$run_static" -eq 1 ]; then
  run_logged "$report" bash "$SCRIPT_DIR/run_static_verify.sh"
fi

if [ "$run_ui" -eq 1 ]; then
  flow_count=0
  while IFS= read -r flow; do
    [ -n "$flow" ] || continue
    flow_count=$((flow_count + 1))
    args=(bash "$SCRIPT_DIR/run_ui_smoke.sh" --platform android --flow "$PROJECT_ROOT/$flow")
    if [ "$install_app" -eq 1 ]; then
      args+=(--install)
      install_app=0
    fi
    run_logged "$report" "${args[@]}"
  done < <(awk '
    /^[[:space:]]*android:/ { in_android=1; next }
    /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_-]*:/ { if (in_android) exit }
    in_android && /^[[:space:]]*-[[:space:]]+/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      print line
    }
  ' "$manifest")

  if [ "$flow_count" -eq 0 ]; then
    flow="$case_dir/maestro"
    if [ -d "$flow" ] || [ -f "$flow" ]; then
      args=(bash "$SCRIPT_DIR/run_ui_smoke.sh" --platform android --flow "$flow")
      if [ "$install_app" -eq 1 ]; then
        args+=(--install)
      fi
      run_logged "$report" "${args[@]}"
    else
      printf 'SKIP UI flow: no android flows listed in %s\n' "$manifest" | tee -a "$report"
    fi
  else
    printf 'Ran %s UI flow(s)\n' "$flow_count" | tee -a "$report"
  fi
fi

printf '\nPASS module regression\nReport: %s\n' "$report" | tee -a "$report"
