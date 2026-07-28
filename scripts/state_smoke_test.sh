#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$("$ROOT_DIR/scripts/package_app.sh")"
OUTPUT_DIR="$(dirname "$APP_DIR")"
BIN="$APP_DIR/Contents/MacOS/DesktopCatPet"
TEST_DIR="$ROOT_DIR/.build/state-test"
STATE_FILE="$TEST_DIR/state.json"
COMMAND_FILE="$TEST_DIR/command.txt"
REPORT="$OUTPUT_DIR/DesktopCatPet_STATE_TEST_REPORT.txt"

mkdir -p "$TEST_DIR"
: > "$COMMAND_FILE"

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

wait_for_value() {
  local path="$1"
  local expected="$2"
  local deadline=$((SECONDS + 8))
  while (( SECONDS < deadline )); do
    if [[ -f "$STATE_FILE" ]]; then
      local value
      value="$(json_value "$path" 2>/dev/null || true)"
      if [[ "$value" == "$expected" ]]; then
        return 0
      fi
    fi
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

wait_for_value "animation" "idle_front" || fail "App did not reach idle_front"

echo "sleep" > "$COMMAND_FILE"
wait_for_value "animation" "sleep" || fail "Sleep command failed"

echo "wake" > "$COMMAND_FILE"
wait_for_value "animation" "idle_front" || fail "Wake command failed"

echo "scale 0.56" > "$COMMAND_FILE"
sleep 0.5
new_w="$(json_value frame.w)"
python3 -c "import sys; raise SystemExit(0 if abs(float(sys.argv[1])-286.72) < 3 else 1)" "$new_w" || fail "Scale command failed"

echo "opacity 0.7" > "$COMMAND_FILE"
sleep 0.5
opacity="$(json_value opacity)"
python3 -c "import sys; raise SystemExit(0 if abs(float(sys.argv[1])-0.7) < 0.03 else 1)" "$opacity" || fail "Opacity command failed"

echo "click_through_on" > "$COMMAND_FILE"
wait_for_value "clickThrough" "True" || fail "Click-through enable failed"

echo "click_through_off" > "$COMMAND_FILE"
wait_for_value "clickThrough" "False" || fail "Click-through disable failed"

echo "random_off" > "$COMMAND_FILE"
wait_for_value "randomMovement" "False" || fail "Random movement disable failed"

echo "random_on" > "$COMMAND_FILE"
wait_for_value "randomMovement" "True" || fail "Random movement enable failed"

old_intimacy="$(json_value intimacy)"
echo "click_part head" > "$COMMAND_FILE"
wait_for_value "animation" "clicked_happy" || fail "Head click command failed"
sleep 0.4
new_intimacy="$(json_value intimacy)"
python3 -c "import sys; raise SystemExit(0 if float(sys.argv[2]) > float(sys.argv[1]) else 1)" "$old_intimacy" "$new_intimacy" || fail "Head click did not increase intimacy"

echo "behavior dock" > "$COMMAND_FILE"
wait_for_value "mode" "dockSitting" || fail "Dock behavior failed"

echo "behavior edge" > "$COMMAND_FILE"
wait_for_value "mode" "edgeWalking" || fail "Edge walking behavior failed"

echo "behavior follow" > "$COMMAND_FILE"
wait_for_value "mode" "followingMouse" || fail "Mouse following behavior failed"

echo "behavior look" > "$COMMAND_FILE"
wait_for_value "mode" "lookingAtMouse" || fail "Looking-at-mouse behavior failed"

echo "behavior auto" > "$COMMAND_FILE"
wait_for_value "behaviorMode" "auto" || fail "Auto behavior failed"

echo "quit" > "$COMMAND_FILE"
sleep 0.4
if kill -0 "$APP_PID" >/dev/null 2>&1; then
  kill "$APP_PID" >/dev/null 2>&1 || true
  fail "Quit command failed"
fi

{
  echo "PASS"
  echo "App: $APP_DIR"
  echo "State file: $STATE_FILE"
  echo "Verified: launch, sleep, wake, scale, opacity, click-through, random movement, body-part click, behavior modes, quit"
} > "$REPORT"

cat "$REPORT"
