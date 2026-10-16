#!/bin/zsh

set -u

app_path="$HOME/Applications/ScreenshotRouter.app"
bundle_id="com.beom.ScreenshotRouter"

echo "ScreenshotRouter를 완전히 삭제합니다."
echo "저장한 스크린샷은 삭제되지 않습니다."
read "answer?계속할까요? [y/N] "

case "$answer" in
  y|Y)
    ;;
  *)
    echo "삭제를 취소했습니다."
    exit 0
    ;;
esac

pkill -x ScreenshotRouter >/dev/null 2>&1 || true

rm -rf -- \
  "$app_path" \
  "$HOME/Library/Caches/$bundle_id" \
  "$HOME/Library/Saved Application State/$bundle_id.savedState" \
  "$HOME/Library/Application Support/$bundle_id"

defaults delete "$bundle_id" >/dev/null 2>&1 || true
tccutil reset ScreenCapture "$bundle_id" >/dev/null 2>&1 || true
tccutil reset Accessibility "$bundle_id" >/dev/null 2>&1 || true

echo "ScreenshotRouter 삭제가 완료되었습니다."
echo "이 창을 닫아도 됩니다."
