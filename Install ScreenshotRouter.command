#!/bin/zsh
set -e

source_dir=${0:A:h}
source_app="$source_dir/ScreenshotRouter.app"
applications_dir=${SCREENSHOT_ROUTER_APPLICATIONS_DIR:-"$HOME/Applications"}
destination_app="$applications_dir/ScreenshotRouter.app"
staged_app="$applications_dir/.ScreenshotRouter.app.installing.$$"
backup_app="$applications_dir/.ScreenshotRouter.app.backup.$$"

[[ -d "$source_app" ]] || { echo "ScreenshotRouter.app을 찾을 수 없습니다."; exit 1; }
mkdir -p "$applications_dir"
rm -rf "$staged_app" "$backup_app"
ditto "$source_app" "$staged_app"
codesign --force --deep --sign - \
  --requirements '=designated => identifier "com.beom.ScreenshotRouter"' \
  "$staged_app"

if [[ -d "$destination_app" ]]; then
  mv "$destination_app" "$backup_app"
fi

if ! mv "$staged_app" "$destination_app"; then
  [[ -d "$backup_app" ]] && mv "$backup_app" "$destination_app"
  exit 1
fi

rm -rf "$backup_app"
# Braces matter: zsh would read "$destination_app에" as one (unset) variable name.
echo "ScreenshotRouter를 ${destination_app}에 설치했습니다."

if [[ ${SCREENSHOT_ROUTER_OPEN_AFTER_INSTALL:-1} == 1 ]]; then
  open "$destination_app"
fi
