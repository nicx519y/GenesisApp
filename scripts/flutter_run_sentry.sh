#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/flutter_run_sentry.sh [-d <device-id>] [--dry-run] [--] [flutter run args...]

Runs the Flutter app with Sentry enabled. By default it sends Sentry traffic to
the current main API host under /sentry:

  https://genesis@<main-host>/sentry/0

Options:
  -d, --device <id>        Device id passed to flutter run.
  --host <host>            Override Sentry host. Defaults to GenesisApi.defaultBaseHost.
  --path <path>            Override Sentry DSN path prefix. Defaults to /sentry.
  --project-id <id>        Override Sentry project id. Defaults to 0.
  --public-key <key>       Override Sentry public key. Defaults to genesis.
  --environment <name>     Override Sentry environment. Defaults to dev.
  --sample-rate <rate>     Override traces sample rate. Defaults to 1.0.
  --debug <true|false>     Override Sentry debug. Defaults to true.
  --dry-run                Print the command without running it.

Environment overrides:
  GENESIS_DEVICE_ID
  GENESIS_SENTRY_HOST
  GENESIS_SENTRY_PATH_PREFIX
  GENESIS_SENTRY_PROJECT_ID
  GENESIS_SENTRY_PUBLIC_KEY
  GENESIS_SENTRY_ENVIRONMENT
  GENESIS_SENTRY_TRACES_SAMPLE_RATE
  GENESIS_SENTRY_DEBUG

Examples:
  scripts/flutter_run_sentry.sh
  scripts/flutter_run_sentry.sh -d 1A101FDF6006AX
  scripts/flutter_run_sentry.sh --host dev.hushie.ai -- --flavor dev
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/genesis_app"
api_file="$app_dir/lib/network/genesis_api.dart"

main_host_from_code() {
  awk -F"'" '/defaultBaseHost/ {print $2; exit}' "$api_file" |
    sed -E 's#^https?://##; s#/.*$##; s#/$##'
}

normalize_host() {
  printf '%s' "$1" | sed -E 's#^https?://##; s#/.*$##; s#/$##'
}

normalize_path_prefix() {
  local path="$1"
  path="${path#/}"
  path="${path%/}"
  if [[ -z "$path" ]]; then
    printf ''
  else
    printf '/%s' "$path"
  fi
}

device_id="${GENESIS_DEVICE_ID:-}"
sentry_host="${GENESIS_SENTRY_HOST:-$(main_host_from_code)}"
sentry_path_prefix="${GENESIS_SENTRY_PATH_PREFIX:-/sentry}"
sentry_project_id="${GENESIS_SENTRY_PROJECT_ID:-0}"
sentry_public_key="${GENESIS_SENTRY_PUBLIC_KEY:-genesis}"
sentry_environment="${GENESIS_SENTRY_ENVIRONMENT:-dev}"
sentry_sample_rate="${GENESIS_SENTRY_TRACES_SAMPLE_RATE:-1.0}"
sentry_debug="${GENESIS_SENTRY_DEBUG:-true}"
dry_run=0
flutter_args=()

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--device)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for $1" >&2
        exit 2
      fi
      device_id="$2"
      shift 2
      ;;
    --host)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --host" >&2
        exit 2
      fi
      sentry_host="$2"
      shift 2
      ;;
    --path)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --path" >&2
        exit 2
      fi
      sentry_path_prefix="$2"
      shift 2
      ;;
    --project-id)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --project-id" >&2
        exit 2
      fi
      sentry_project_id="$2"
      shift 2
      ;;
    --public-key)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --public-key" >&2
        exit 2
      fi
      sentry_public_key="$2"
      shift 2
      ;;
    --environment)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --environment" >&2
        exit 2
      fi
      sentry_environment="$2"
      shift 2
      ;;
    --sample-rate)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --sample-rate" >&2
        exit 2
      fi
      sentry_sample_rate="$2"
      shift 2
      ;;
    --debug)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --debug" >&2
        exit 2
      fi
      sentry_debug="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --)
      shift
      flutter_args+=("$@")
      break
      ;;
    *)
      flutter_args+=("$1")
      shift
      ;;
  esac
done

sentry_host="$(normalize_host "$sentry_host")"
sentry_path_prefix="$(normalize_path_prefix "$sentry_path_prefix")"

if [[ -z "$sentry_host" ]]; then
  echo "Unable to determine Sentry host. Set GENESIS_SENTRY_HOST or pass --host." >&2
  exit 1
fi

sentry_dsn="https://${sentry_public_key}@${sentry_host}${sentry_path_prefix}/${sentry_project_id}"

cmd=(flutter run)
if [[ -n "$device_id" ]]; then
  cmd+=(-d "$device_id")
fi
cmd+=(
  "--dart-define=GENESIS_SENTRY_DSN=${sentry_dsn}"
  "--dart-define=GENESIS_SENTRY_ENVIRONMENT=${sentry_environment}"
  "--dart-define=GENESIS_SENTRY_TRACES_SAMPLE_RATE=${sentry_sample_rate}"
  "--dart-define=GENESIS_SENTRY_DEBUG=${sentry_debug}"
)
if ((${#flutter_args[@]})); then
  cmd+=("${flutter_args[@]}")
fi

printf 'Using GENESIS_SENTRY_DSN=%s\n' "$sentry_dsn"
printf 'Running in %s\n' "$app_dir"

if ((dry_run)); then
  printf 'Command:'
  printf ' %q' "${cmd[@]}"
  printf '\n'
  exit 0
fi

cd "$app_dir"
exec "${cmd[@]}"
