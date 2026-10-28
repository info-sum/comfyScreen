#!/bin/sh
# Removes ScreenshotRouter: the app, its settings and cache, and its permission entries.
# Screenshots already saved to destination folders are not touched.
#
#   curl -fsSL https://raw.githubusercontent.com/info-sum/comfyScreen/main/scripts/uninstall.sh | sh
#
# "Uninstall ScreenshotRouter.command" in the repository runs this same script.
set -u

applications_dir=${SCREENSHOT_ROUTER_APPLICATIONS_DIR:-"$HOME/Applications"}
bundle_id=${SCREENSHOT_ROUTER_BUNDLE_ID:-com.beom.ScreenshotRouter}
app_path="$applications_dir/ScreenshotRouter.app"
cache_dir="$HOME/Library/Caches/ScreenshotRouter"

printf '%s\n' 'ScreenshotRouter를 완전히 삭제합니다.' '저장한 스크린샷은 삭제되지 않습니다.'
pending=$(find "$cache_dir/Pending" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "${pending:-0}" -gt 0 ]; then
    printf '%s\n' "저장하지 않은 캡처 ${pending}개는 함께 삭제됩니다."
fi

# Through `curl | sh` this script arrives on stdin, so the answer is read from the terminal.
if [ "${SCREENSHOT_ROUTER_UNINSTALL_YES:-0}" = 1 ]; then
    answer=y
elif (: < /dev/tty) 2>/dev/null; then
    printf '%s' '계속할까요? [y/N] '
    read -r answer < /dev/tty || answer=
else
    printf '%s\n' '확인할 터미널이 없어 삭제를 취소했습니다. 터미널에서 다시 실행하세요.' >&2
    exit 1
fi

case "$answer" in
    y|Y|yes|YES) ;;
    *)
        printf '%s\n' '삭제를 취소했습니다.'
        exit 0
        ;;
esac

# Quit the installed copy (and only that copy), then wait for it to exit.
executable_pattern=$(printf '%s' "$app_path/Contents/MacOS/ScreenshotRouter" | sed 's/[][\.*^$+?(){}|]/\\&/g')
pkill -f "$executable_pattern" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "$executable_pattern" >/dev/null 2>&1 || break
    sleep 0.3
done

rm -rf -- \
    "$app_path" \
    "$cache_dir" \
    "$HOME/Library/Caches/$bundle_id" \
    "$HOME/Library/Saved Application State/$bundle_id.savedState" \
    "$HOME/Library/Application Support/$bundle_id" \
    "$HOME/Library/HTTPStorages/$bundle_id"

defaults delete "$bundle_id" >/dev/null 2>&1 || true
tccutil reset ScreenCapture "$bundle_id" >/dev/null 2>&1 || true
tccutil reset Accessibility "$bundle_id" >/dev/null 2>&1 || true

printf '%s\n' 'ScreenshotRouter 삭제가 완료되었습니다.'
