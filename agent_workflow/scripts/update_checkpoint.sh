#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

feature="${1:-}"
if [ -z "$feature" ]; then
  cat <<'HELP'
Usage: bash agent_workflow/scripts/update_checkpoint.sh <feature> [options]

Options:
  --stage <text>       Append current workflow stage.
  --status <text>      Append current status.
  --done <text>        Append completed item.
  --next <text>        Append next item.
  --evidence <text>    Append verification evidence.
  --blocker <text>     Append blocker/risk.
  --handoff <text>     Append handoff note.

Example:
  bash agent_workflow/scripts/update_checkpoint.sh login-flow \
    --stage CODE_READY \
    --done "Updated login cancel behavior" \
    --next "Run module regression for me"
HELP
  exit 2
fi
shift

checkpoint="$(bash "$SCRIPT_DIR/init_checkpoint.sh" "$feature")"
now="$(date '+%Y-%m-%d %H:%M:%S %z')"

append_item() {
  local title="$1"
  local text="$2"
  {
    printf '\n### %s\n\n' "$title"
    printf -- '- %s: %s\n' "$now" "$text"
  } >> "$checkpoint"
}

if [ "$#" -eq 0 ]; then
  append_item "状态更新" "checkpoint touched"
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stage)
      append_item "阶段" "${2:-}"
      shift
      ;;
    --status)
      append_item "当前状态" "${2:-}"
      shift
      ;;
    --done)
      append_item "已完成" "${2:-}"
      shift
      ;;
    --next)
      append_item "待完成" "${2:-}"
      shift
      ;;
    --evidence)
      append_item "验证证据" "${2:-}"
      shift
      ;;
    --blocker)
      append_item "Blockers / 风险" "${2:-}"
      shift
      ;;
    --handoff)
      append_item "交接说明" "${2:-}"
      shift
      ;;
    -h|--help)
      bash "$0" ""
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

printf '%s\n' "$checkpoint"

