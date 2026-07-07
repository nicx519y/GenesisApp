#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
app_dir="$repo_dir/genesis_app"
entrypoint="$script_dir/compress_images.dart"
package_config="$app_dir/.dart_tool/package_config.json"

usage() {
  cat <<'USAGE'
Usage:
  scripts/compress_images.sh --input <file-or-dir> --output <dir> [options]

Examples:
  scripts/compress_images.sh -i raw_tiles -o genesis_app/assets/tilemap --scale 0.5 --format webp
  scripts/compress_images.sh -i raw_tiles -o genesis_app/assets/tilemap --max-width 1024 --quality 82 --recursive --overwrite

Options:
  -i, --input <path>       Source image file or directory.
  -o, --output <dir>      Directory to write compressed images.
      --scale <ratio>     Proportional shrink ratio, greater than 0 and no more than 1.
      --max-width <px>    Maximum output width. Never upscales.
      --max-height <px>   Maximum output height. Never upscales.
      --format <format>   same, jpg, jpeg, png, or webp. Default: same.
      --quality <1-100>   JPEG quality. Default: 85.
      --png-level <0-9>   PNG compression level. Default: 9.
      --append-size       Add processed image dimensions before the extension.
      --recursive         Read input directories recursively.
      --overwrite         Replace files that already exist in the output directory.
      --dry-run           Print planned work without writing files.
  -h, --help              Show this help.

Supported inputs: .jpg, .jpeg, .png, .webp
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$app_dir/pubspec.yaml" ]]; then
  echo "Missing Flutter app directory: $app_dir" >&2
  exit 1
fi

if [[ ! -f "$entrypoint" ]]; then
  echo "Missing Dart entrypoint: $entrypoint" >&2
  exit 1
fi

if [[ ! -f "$package_config" ]]; then
  (
    cd "$app_dir"
    dart pub get
  )
fi

exec dart --packages="$package_config" "$entrypoint" "$@"
