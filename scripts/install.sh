#!/bin/sh
set -eu

repository=${SCREENSHOT_ROUTER_REPOSITORY:-info-sum/comfyScreen}
ref=${SCREENSHOT_ROUTER_REF:-main}
archive_url=${SCREENSHOT_ROUTER_ARCHIVE_URL:-"https://github.com/$repository/archive/refs/heads/$ref.tar.gz"}

if [ "$(uname)" != "Darwin" ]; then
    printf '%s\n' 'ScreenshotRouter는 macOS에서만 설치할 수 있습니다.' >&2
    exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
    printf '%s\n' 'ScreenshotRouter는 Apple Silicon(M1 이상) Mac이 필요합니다.' >&2
    exit 1
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ScreenshotRouter.XXXXXX")
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT HUP INT TERM

archive="$work_dir/source.tar.gz"
curl --fail --location --silent --show-error "$archive_url" -o "$archive"
tar -xzf "$archive" -C "$work_dir"

source_dir=$(find "$work_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
installer="$source_dir/Install ScreenshotRouter.command"

if [ ! -x "$installer" ]; then
    printf '%s\n' '다운로드한 프로젝트에서 설치 프로그램을 찾을 수 없습니다.' >&2
    exit 1
fi

"$installer"
