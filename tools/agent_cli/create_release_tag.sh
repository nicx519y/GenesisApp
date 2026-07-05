#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_dir/genesis_app"
pubspec_path="$app_dir/pubspec.yaml"

usage() {
  cat <<'EOF'
Usage:
  tools/agent_cli/create_release_tag.sh android [--push] [--dry-run]
  tools/agent_cli/create_release_tag.sh ios [--push] [--dry-run]

Platform is required. This script never infers android or ios.

Tag format:
  Android: android-v{versionName}+{versionCode}
  iOS:     ios-v{versionName}+{buildNumber}

The version is read from pubspec.yaml, for example:
  version: 0.2.3+23

Examples:
  tools/agent_cli/create_release_tag.sh android
  tools/agent_cli/create_release_tag.sh ios --push

If the platform is not specified, this script will not create a tag.
EOF
}

fail() {
  echo "Error: $*" >&2
  echo >&2
  usage >&2
  exit 2
}

platform="${1:-}"
if [[ -z "$platform" ]]; then
  fail "missing platform. Explicitly specify android or ios. No tag was created."
fi
shift || true

case "$platform" in
  android|ios)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    fail "unsupported platform '$platform'. Please specify android or ios."
    ;;
esac

push_tag=false
dry_run=false
while (($#)); do
  case "$1" in
    --push)
      push_tag=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument '$1'."
      ;;
  esac
  shift
done

if [[ ! -f "$pubspec_path" ]]; then
  fail "pubspec.yaml not found at $pubspec_path."
fi

version="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "$pubspec_path")"
if [[ -z "$version" ]]; then
  fail "missing version in pubspec.yaml."
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  fail "unsupported pubspec version '$version'. Expected format like 0.2.3+23."
fi

version_name="${version%%+*}"
build_number="${version#*+}"
tag_name="${platform}-v${version_name}+${build_number}"

cd "$app_dir"
git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "not inside a git repository."
cd "$git_root"

if git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null; then
  fail "tag '$tag_name' already exists locally."
fi

if ! $dry_run && [[ -n "$(git status --porcelain)" ]]; then
  fail "working tree is not clean. Commit or stash changes before creating a release tag."
fi

if [[ "$platform" == "android" ]]; then
  tag_message="Android release v${version_name}+${build_number}"
else
  tag_message="iOS release v${version_name}+${build_number}"
fi

echo "Platform: $platform"
echo "Version:  $version"
echo "Tag:      $tag_name"
echo "Commit:   $(git rev-parse --short HEAD)"

if $dry_run; then
  echo
  echo "Dry run only. No tag was created."
  exit 0
fi

git tag -a "$tag_name" -m "$tag_message"
echo "Created local tag: $tag_name"

if $push_tag; then
  git push origin "$tag_name"
  echo "Pushed tag to origin: $tag_name"
else
  echo "Push with:"
  echo "  git push origin '$tag_name'"
fi
