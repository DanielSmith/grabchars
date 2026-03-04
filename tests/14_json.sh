#!/usr/bin/env bash
# 14_json.sh - JSON output (-J) tests

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

# Helper: extract a field from compact JSON (no jq dependency)
json_field() {
    local json="$1" field="$2"
    # handles string, number, boolean, null
    echo "$json" | sed -n "s/.*\"$field\":\s*\"\{0,1\}\([^,\"}\{]*\)\"\{0,1\}.*/\1/p"
}

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Automated Validation"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-J0 produces no JSON (explicit off)"
watch_note "fully automated — no keystrokes needed"
show_command "-J0 -cy -d y"
echo
actual_out=$("$GRABCHARS" -J0 -cy -d y 2>/dev/null <<< "")
actual_exit=$?
echo
# With -d y and stdin EOF triggering default, output should be plain "y"
if [[ "$actual_out" == "y" ]]; then
    pass "-J0 gave plain text output"
else
    fail "expected plain 'y', got: $actual_out"
fi

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Normal Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -J: single character capture"
echo    "  Type a single character. JSON should contain the character,"
echo    "  exit=1, status=ok, mode=normal."
instruct "Type 'y'"
show_command "-J -cy -q 'y/n: '"
echo
actual_out=$("$GRABCHARS" -J -cy -q "y/n: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
status=$(json_field "$actual_out" "status")
mode=$(json_field "$actual_out" "mode")
check_output "$value" "y" "value" \
  && check_output "$status" "ok" "status" \
  && check_output "$mode" "normal" "mode" \
  && check_exit "$actual_exit" "1" \
  && pass || fail "unexpected JSON output"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -J: default on Enter"
echo    "  Press Enter without typing. JSON should show status=default,"
echo    "  default_used=true, value=y."
instruct "Press Enter"
show_command "-J -cy -d y -q 'Continue? [Y/n] '"
echo
actual_out=$("$GRABCHARS" -J -cy -d y -q "Continue? [Y/n] " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
status=$(json_field "$actual_out" "status")
def_used=$(json_field "$actual_out" "default_used")
check_output "$value" "y" "value" \
  && check_output "$status" "default" "status" \
  && check_output "$def_used" "true" "default_used" \
  && check_exit "$actual_exit" "1" \
  && pass || fail "unexpected JSON for default"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -J: ESC with -B200"
echo    "  Press Escape. JSON should show status=cancelled, exit=200."
instruct "Press Escape"
show_command "-J -cy -B200 -q 'y/n: '"
echo
actual_out=$("$GRABCHARS" -J -cy -B200 -q "y/n: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
status=$(json_field "$actual_out" "status")
exit_val=$(json_field "$actual_out" "exit")
check_output "$status" "cancelled" "status" \
  && check_output "$exit_val" "200" "exit" \
  && check_exit "$actual_exit" "200" \
  && pass || fail "unexpected JSON for ESC"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -J: multi-char with editing"
echo    "  Type 'abc' then Enter. JSON should show value=abc, exit=3."
instruct "Type 'abc', then press Enter"
show_command "-J -n10 -r -q 'Text: '"
echo
actual_out=$("$GRABCHARS" -J -n10 -r -q "Text: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
status=$(json_field "$actual_out" "status")
check_output "$value" "abc" "value" \
  && check_output "$status" "ok" "status" \
  && check_exit "$actual_exit" "3" \
  && pass || fail "unexpected JSON for multi-char"

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Mask Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "mask mode -J: phone number"
echo    "  Type 10 digits (e.g. 2125551212). JSON should show the"
echo    "  formatted value with literals, mode=mask."
instruct "Type '2125551212'"
show_command "-J -m '(nnn) nnn-nnnn' -q 'Phone: '"
echo
actual_out=$("$GRABCHARS" -J -m "(nnn) nnn-nnnn" -q "Phone: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
mode=$(json_field "$actual_out" "mode")
index=$(json_field "$actual_out" "index")
check_output "$value" "(212) 555-1212" "value" \
  && check_output "$mode" "mask" "mode" \
  && check_output "$index" "null" "index" \
  && check_exit "$actual_exit" "10" \
  && pass || fail "unexpected JSON for mask"

# ─────────────────────────────────────────────────────────────────────────────
test_start "mask mode -J: ESC cancels"
echo    "  Press Escape in mask mode. JSON should show status=cancelled."
instruct "Press Escape"
show_command "-J -m nnn -q 'Digits: '"
echo
actual_out=$("$GRABCHARS" -J -m nnn -q "Digits: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
status=$(json_field "$actual_out" "status")
check_output "$status" "cancelled" "status" \
  && check_exit "$actual_exit" "255" \
  && pass || fail "unexpected JSON for mask ESC"

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Select Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -J: choose second option"
echo    "  Choose 'no' from the list. JSON should show value=no,"
echo    "  index=1, and filter text."
instruct "Type 'n', press Enter"
show_command "-J select 'yes,no,cancel' -q 'Choice: '"
echo
actual_out=$("$GRABCHARS" -J select "yes,no,cancel" -q "Choice: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
index=$(json_field "$actual_out" "index")
mode=$(json_field "$actual_out" "mode")
check_output "$value" "no" "value" \
  && check_output "$index" "1" "index" \
  && check_output "$mode" "select" "mode" \
  && check_exit "$actual_exit" "1" \
  && pass || fail "unexpected JSON for select"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -J: ESC cancelled"
echo    "  Press Escape. JSON should show status=cancelled, index=null."
instruct "Press Escape"
show_command "-J select 'yes,no,cancel' -q 'Choice: '"
echo
actual_out=$("$GRABCHARS" -J select "yes,no,cancel" -q "Choice: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
status=$(json_field "$actual_out" "status")
index=$(json_field "$actual_out" "index")
check_output "$status" "cancelled" "status" \
  && check_output "$index" "null" "index" \
  && check_exit "$actual_exit" "255" \
  && pass || fail "unexpected JSON for select ESC"

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Select-LR Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr -J: choose with arrow keys"
echo    "  Press Right once to highlight 'no', then Enter."
echo    "  JSON should show value=no, index=1, mode=select-lr."
instruct "Press Right, then Enter"
show_command "-J select-lr 'yes,no,cancel' -q 'Choice: '"
echo
actual_out=$("$GRABCHARS" -J select-lr "yes,no,cancel" -q "Choice: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
value=$(json_field "$actual_out" "value")
index=$(json_field "$actual_out" "index")
mode=$(json_field "$actual_out" "mode")
check_output "$value" "no" "value" \
  && check_output "$index" "1" "index" \
  && check_output "$mode" "select-lr" "mode" \
  && check_exit "$actual_exit" "1" \
  && pass || fail "unexpected JSON for select-lr"

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Raw Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "raw mode -J: capture arrow key as hex"
echo    "  Press an arrow key (e.g. Up). JSON value should be hex-encoded"
echo    "  (e.g. '1b 5b 41'), mode=raw."
instruct "Press Up arrow"
show_command "-J -R -n3 -q 'Press an arrow key: '"
echo
actual_out=$("$GRABCHARS" -J -R -n3 -q "Press an arrow key: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
mode=$(json_field "$actual_out" "mode")
status=$(json_field "$actual_out" "status")
check_output "$mode" "raw" "mode" \
  && check_output "$status" "ok" "status" \
  && check_exit "$actual_exit" "3" \
  && pass || fail "unexpected JSON for raw mode"

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-Jp) — Pretty Print"

# ─────────────────────────────────────────────────────────────────────────────
test_start "pretty-print -Jp: output is multi-line"
echo    "  Type 'y'. JSON should be indented across multiple lines."
instruct "Type 'y'"
show_command "-Jp -cy -q 'y/n: '"
echo
actual_out=$("$GRABCHARS" -Jp -cy -q "y/n: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON:"
echo "$actual_out"
# Pretty-print should contain newlines
if [[ "$actual_out" == *$'\n'* ]]; then
    check_exit "$actual_exit" "1" && pass "output is multi-line" || fail "wrong exit code"
else
    fail "expected multi-line output from -Jp"
fi

# ─────────────────────────────────────────────────────────────────────────────
test_section "JSON Output (-J) — Timeout"

# ─────────────────────────────────────────────────────────────────────────────
test_start "timeout with default -J: status=default, timed_out=true"
echo    "  Wait 2 seconds. JSON should show status=default, timed_out=true."
watch_note "auto-fires after 2 seconds — do not type anything"
show_command "-J -cy -d y -t2 -q 'Wait 2s: '"
echo
actual_out=$("$GRABCHARS" -J -cy -d y -t2 -q "Wait 2s: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
status=$(json_field "$actual_out" "status")
timed=$(json_field "$actual_out" "timed_out")
def_used=$(json_field "$actual_out" "default_used")
check_output "$status" "default" "status" \
  && check_output "$timed" "true" "timed_out" \
  && check_output "$def_used" "true" "default_used" \
  && check_exit "$actual_exit" "1" \
  && pass || fail "unexpected JSON for timeout+default"

# ─────────────────────────────────────────────────────────────────────────────
test_start "timeout without default -J: status=timeout, exit=254"
echo    "  Wait 2 seconds. JSON should show status=timeout, exit=254."
watch_note "auto-fires after 2 seconds — do not type anything"
show_command "-J -n10 -r -t2 -q 'Wait 2s: '"
echo
actual_out=$("$GRABCHARS" -J -n10 -r -t2 -q "Wait 2s: " 2>/dev/tty)
actual_exit=$?
echo
echo "  JSON: $actual_out"
status=$(json_field "$actual_out" "status")
exit_val=$(json_field "$actual_out" "exit")
timed=$(json_field "$actual_out" "timed_out")
check_output "$status" "timeout" "status" \
  && check_output "$exit_val" "254" "exit" \
  && check_output "$timed" "true" "timed_out" \
  && check_exit "$actual_exit" "254" \
  && pass || fail "unexpected JSON for timeout without default"

print_summary
