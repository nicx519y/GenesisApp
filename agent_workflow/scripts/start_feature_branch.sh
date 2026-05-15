#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'HELP'
Usage: bash agent_workflow/scripts/start_feature_branch.sh <feature|fix|ui> <short-slug>

Examples:
  bash agent_workflow/scripts/start_feature_branch.sh feature login-cancel-silent
  bash agent_workflow/scripts/start_feature_branch.sh ui me-tab-login-sheet
HELP
}

kind="${1:-}"
slug="${2:-}"

if [ -z "$kind" ] || [ -z "$slug" ]; then
  usage
  exit 2
fi

case "$kind" in
  feature|fix|ui|chore|docs)
    ;;
  *)
    printf 'Unsupported branch kind: %s\n' "$kind" >&2
    printf 'Allowed kinds: feature, fix, ui, chore, docs\n' >&2
    exit 2
    ;;
esac

safe_slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"

if [ -z "$safe_slug" ]; then
  printf 'Invalid slug: %s\n' "$slug" >&2
  exit 2
fi

branch="codex/$kind-$safe_slug"

cd "$PROJECT_ROOT"

if git rev-parse --verify "$branch" >/dev/null 2>&1; then
  git switch "$branch"
else
  git switch -c "$branch"
fi

printf '%s\n' "$branch"
