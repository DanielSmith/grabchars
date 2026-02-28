#!/usr/bin/env bash
# 11_select_lr.sh - Horizontal (left-right) select mode

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

OPTS="yes no maybe"

test_section "Select-LR Mode (horizontal)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: Left/Right arrows navigate, Enter confirms"
echo    "  All options shown on one line. Use ← → to move highlight."
instruct "Press Right arrow once to land on 'no', then Enter"
show_command "select-lr $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "no" && check_exit "$actual_exit" "2" && pass || fail "expected 'no' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: Enter with no movement selects first option"
instruct "Press Enter immediately"
show_command "select-lr $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" && pass || fail "expected 'yes' (first item)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: wrap around right"
echo    "  Three options: yes no maybe. Press Right 3 times to wrap back to 'yes'."
instruct "Press Right arrow 3 times, then Enter"
show_command "select-lr $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" && pass || fail "expected 'yes' (wrapped)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: type to jump to matching option"
echo    "  Typing letters jumps to the first matching option."
instruct "Type 'm' to jump to 'maybe', then Enter"
show_command "select-lr $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "maybe" && check_exit "$actual_exit" "5" && pass || fail "expected 'maybe' with exit 5"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: Escape cancels with exit 255"
instruct "Press Escape"
show_command "select-lr $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 on Escape"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr -H b: bracket highlight style [option]"
echo    "  -H b uses [brackets] instead of reverse video for the current selection."
echo    "  You should see something like:  yes  [no]  maybe  on screen."
instruct "Press Right once to land on 'no', then Enter"
show_command "select-lr -Hb $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr -Hb $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "no" && check_exit "$actual_exit" "2" && pass || fail "expected 'no' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr -H a: arrow highlight style →option←"
echo    "  -H a uses arrows →option← around the current selection."
instruct "Press Enter immediately (select first: 'yes')"
show_command "select-lr -Ha $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr -Ha $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" && pass || fail "expected 'yes' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr: timeout with default"
echo    "  -t3 -d no: after 3 seconds without input, returns 'no'."
instruct "Do NOT press anything — watch it time out"
show_command "select-lr -t3 -dno $OPTS"
echo
watch_note "timing out in 3 seconds..."
actual_out=$("$GRABCHARS" select-lr -t3 -dno $OPTS 2>/dev/null)
actual_exit=$?
echo
echo    "  Output was: \"$actual_out\""
check_output "$actual_out" "no" && check_exit "$actual_exit" "2" && pass || fail "expected 'no' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr --file: load options from a file"
TMPFILE=$(mktemp)
printf 'red\ngreen\nblue\n' > "$TMPFILE"
echo    "  Options loaded from file: red, green, blue"
instruct "Type 'g' to match 'green', press Enter"
show_command "select-lr --file /tmp/options.txt"
echo
actual_out=$("$GRABCHARS" select-lr --file "$TMPFILE" 2>/dev/null)
actual_exit=$?
rm -f "$TMPFILE"
echo
check_output "$actual_out" "green" && check_exit "$actual_exit" "5" && pass || fail "expected 'green' with exit 5"

print_summary
