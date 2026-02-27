#!/usr/bin/env bash
# 10_select.sh - Vertical select mode

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

OPTS="apple banana cherry date elderberry fig grape"

test_section "Select Mode (vertical)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select: type to filter, Enter to choose"
echo    "  A vertical select appears on stderr. Type to filter the list."
echo    "  The matching option is shown; press Enter to confirm."
instruct "Type 'b', 'a' to narrow to 'banana', then press Enter"
show_command "select $OPTS"
echo
actual_out=$("$GRABCHARS" select $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "banana" && check_exit "$actual_exit" "6" && pass || fail "expected 'banana' with exit 6"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select: Enter with no input selects first match"
instruct "Press Enter immediately (no filter typed)"
show_command "select $OPTS"
echo
actual_out=$("$GRABCHARS" select $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "apple" && check_exit "$actual_exit" "5" && pass || fail "expected 'apple' (first item)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select: Escape cancels with exit 255"
instruct "Press Escape immediately"
show_command "select $OPTS"
echo
actual_out=$("$GRABCHARS" select $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 on Escape"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select: -d default fires on timeout"
echo    "  With -t3 -d cherry, if you don't choose in time, 'cherry' is returned."
instruct "Do NOT type anything — wait for timeout"
show_command "select -t3 -dcherry $OPTS"
echo
watch_note "timing out in 3 seconds..."
actual_out=$("$GRABCHARS" select -t3 -dcherry $OPTS 2>/dev/null)
actual_exit=$?
echo
echo    "  Output was: \"$actual_out\""
check_output "$actual_out" "cherry" && check_exit "$actual_exit" "6" && pass || fail "expected 'cherry' with exit 6"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select: -U maps choice to uppercase"
instruct "Type 'f', 'i' to match 'fig', press Enter"
show_command "select -U $OPTS"
echo
actual_out=$("$GRABCHARS" select -U $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "FIG" && check_exit "$actual_exit" "3" && pass || fail "expected 'FIG' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select --file: load options from a file"
TMPFILE=$(mktemp)
printf 'red\ngreen\nblue\n' > "$TMPFILE"
echo    "  Options loaded from file: red, green, blue"
instruct "Type 'g' to match 'green', press Enter"
show_command "select --file /tmp/options.txt"
echo
actual_out=$("$GRABCHARS" select --file "$TMPFILE" 2>/dev/null)
actual_exit=$?
rm -f "$TMPFILE"
echo
check_output "$actual_out" "green" && check_exit "$actual_exit" "5" && pass || fail "expected 'green' with exit 5"

print_summary
