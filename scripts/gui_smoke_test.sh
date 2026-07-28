#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$("$ROOT_DIR/scripts/package_app.sh")"
OUTPUT_DIR="$(dirname "$APP_DIR")"
BIN="$APP_DIR/Contents/MacOS/DesktopCatPet"
TEST_DIR="$ROOT_DIR/.build/gui-test"
STATE_FILE="$TEST_DIR/state.json"
COMMAND_FILE="$TEST_DIR/command.txt"
SCREENSHOT_FILE="$TEST_DIR/screenshot.png"
WALK_SCREENSHOT_FILE="$TEST_DIR/walk_right_screenshot.png"
DRIVER="$TEST_DIR/GuiTestDriver"
REPORT="$OUTPUT_DIR/DesktopCatPet_GUI_TEST_REPORT.txt"

mkdir -p "$TEST_DIR"
: > "$COMMAND_FILE"

clang \
  -fobjc-arc \
  -mmacosx-version-min=13.0 \
  -framework AppKit \
  -framework ApplicationServices \
  "$ROOT_DIR/ObjC/GuiTestDriver.m" \
  -o "$DRIVER"

fail() {
  echo "FAIL: $1" | tee "$REPORT"
  if [[ -f "$STATE_FILE" ]]; then
    echo "" >> "$REPORT"
    echo "Last state:" >> "$REPORT"
    cat "$STATE_FILE" >> "$REPORT"
  fi
  if [[ -n "${APP_PID:-}" ]]; then
    kill "$APP_PID" >/dev/null 2>&1 || true
  fi
  exit 1
}

json_value() {
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); cur=d
for part in sys.argv[2].split('.'):
    cur=cur[part]
print(cur)" "$STATE_FILE" "$1"
}

wait_for_state() {
  local expected="$1"
  local deadline=$((SECONDS + 8))
  while (( SECONDS < deadline )); do
    if [[ -f "$STATE_FILE" ]]; then
      local animation
      animation="$(json_value animation 2>/dev/null || true)"
      if [[ "$animation" == "$expected" ]]; then
        return 0
      fi
    fi
    sleep 0.15
  done
  return 1
}

wait_for_frame_x_change() {
  local old_x="$1"
  local deadline=$((SECONDS + 8))
  while (( SECONDS < deadline )); do
    local new_x
    new_x="$(json_value frame.x 2>/dev/null || echo "$old_x")"
    python3 -c "import sys; raise SystemExit(0 if abs(float(sys.argv[1])-float(sys.argv[2])) > 20 else 1)" "$old_x" "$new_x" && return 0
    sleep 0.15
  done
  return 1
}

"$BIN" \
  --ui-test \
  --state-file "$STATE_FILE" \
  --command-file "$COMMAND_FILE" \
  --initial-frame 160 160 220 220 &
APP_PID=$!

wait_for_state "idle_front" || fail "App did not reach idle_front"

visible="$(json_value visible)"
[[ "$visible" == "1" || "$visible" == "True" || "$visible" == "true" ]] || fail "Window is not visible"

screencapture -x "$SCREENSHOT_FILE" || fail "Screenshot failed"
[[ -s "$SCREENSHOT_FILE" ]] || fail "Screenshot is empty"

echo "walk_right" > "$COMMAND_FILE"
wait_for_state "walk_right" || fail "Walk command failed"
sleep 0.25
screencapture -x "$WALK_SCREENSHOT_FILE" || fail "Walk screenshot failed"
[[ -s "$WALK_SCREENSHOT_FILE" ]] || fail "Walk screenshot is empty"

echo "wake" > "$COMMAND_FILE"
wait_for_state "idle_front" || fail "Wake after walk command failed"

x="$(json_value frame.x)"
y="$(json_value frame.y)"
w="$(json_value frame.w)"
h="$(json_value frame.h)"
center_x="$(python3 -c "import sys; print(float(sys.argv[1]) + float(sys.argv[2]) / 2)" "$x" "$w")"
center_y="$(python3 -c "import sys; print(float(sys.argv[1]) + float(sys.argv[2]) / 2)" "$y" "$h")"

"$DRIVER" click "$center_x" "$center_y"
wait_for_state "clicked_happy" || fail "Click did not trigger clicked_happy"
sleep 0.9
wait_for_state "idle_front" || fail "Clicked animation did not return to idle_front"

old_x="$(json_value frame.x)"
to_x="$(python3 -c "import sys; print(float(sys.argv[1]) + 90)" "$center_x")"
to_y="$(python3 -c "import sys; print(float(sys.argv[1]) + 40)" "$center_y")"
"$DRIVER" drag "$center_x" "$center_y" "$to_x" "$to_y"
wait_for_frame_x_change "$old_x" || fail "Drag did not move the pet window"
wait_for_state "idle_front" || fail "Drag did not return to idle_front"

echo "sleep" > "$COMMAND_FILE"
wait_for_state "sleep" || fail "Sleep command failed"

echo "wake" > "$COMMAND_FILE"
wait_for_state "idle_front" || fail "Wake command failed"

echo "scale 0.56" > "$COMMAND_FILE"
sleep 0.5
new_w="$(json_value frame.w)"
python3 -c "import sys; raise SystemExit(0 if abs(float(sys.argv[1])-286.72) < 3 else 1)" "$new_w" || fail "Scale command failed"

echo "opacity 0.7" > "$COMMAND_FILE"
sleep 0.5
opacity="$(json_value opacity)"
python3 -c "import sys; raise SystemExit(0 if abs(float(sys.argv[1])-0.7) < 0.03 else 1)" "$opacity" || fail "Opacity command failed"

echo "click_through_on" > "$COMMAND_FILE"
sleep 0.5
click_through="$(json_value clickThrough)"
[[ "$click_through" == "1" || "$click_through" == "True" || "$click_through" == "true" ]] || fail "Click-through enable failed"

echo "click_through_off" > "$COMMAND_FILE"
sleep 0.5
click_through="$(json_value clickThrough)"
[[ "$click_through" == "0" || "$click_through" == "False" || "$click_through" == "false" ]] || fail "Click-through disable failed"

echo "random_off" > "$COMMAND_FILE"
sleep 0.5
random_movement="$(json_value randomMovement)"
[[ "$random_movement" == "0" || "$random_movement" == "False" || "$random_movement" == "false" ]] || fail "Random movement disable failed"

echo "random_on" > "$COMMAND_FILE"
sleep 0.5
random_movement="$(json_value randomMovement)"
[[ "$random_movement" == "1" || "$random_movement" == "True" || "$random_movement" == "true" ]] || fail "Random movement enable failed"

echo "quit" > "$COMMAND_FILE"
sleep 0.4
if kill -0 "$APP_PID" >/dev/null 2>&1; then
  kill "$APP_PID" >/dev/null 2>&1 || true
  fail "Quit command failed"
fi

{
  echo "PASS"
  echo "App: $APP_DIR"
  echo "Screenshot: $SCREENSHOT_FILE"
  echo "Walk screenshot: $WALK_SCREENSHOT_FILE"
  echo "State file: $STATE_FILE"
  echo "Verified: launch, visible window, screenshot, walk frame screenshot, click, drag, sleep, wake, scale, opacity, click-through, random movement, quit"
} > "$REPORT"

cat "$REPORT"
