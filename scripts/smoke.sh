#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
qa_dir=$(mktemp -d "$PWD/.omo/evidence/smoke.XXXXXX")
app_pid=
cleanup() {
    if [ -n "$app_pid" ]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -r "$qa_dir"
    printf 'CLEANUP: temporary watch/destination folders removed: %s\n' "$qa_dir"
}
trap cleanup EXIT HUP INT TERM
mkdir "$qa_dir/watch" "$qa_dir/destination"
printf 'COMMAND: SCREENSHOT_ROUTER_WATCH_DIR=%s/watch SCREENSHOT_ROUTER_DESTINATIONS=%s/destination .build/release/ScreenshotRouter\n' "$qa_dir" "$qa_dir"
SCREENSHOT_ROUTER_WATCH_DIR="$qa_dir/watch" SCREENSHOT_ROUTER_DESTINATIONS="$qa_dir/destination" .build/release/ScreenshotRouter > "$qa_dir/app.log" 2>&1 &
app_pid=$!
sleep 3
kill -0 "$app_pid"
printf 'PASS: release executable alive after three seconds; PID=%s\n' "$app_pid"
ps -p "$app_pid" -o pid=,comm=
kill "$app_pid"
wait "$app_pid" 2>/dev/null || true
if kill -0 "$app_pid" 2>/dev/null; then
    printf 'FAIL: app still running\n'
    exit 1
fi
printf 'PASS: process terminated\n'
app_pid=
if [ -s "$qa_dir/app.log" ]; then
    printf 'Application output:\n'
    cat "$qa_dir/app.log"
fi
