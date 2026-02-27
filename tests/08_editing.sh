#!/usr/bin/env bash
# 08_editing.sh - Line editing: -E0 (off), -E (on/default), -E1 (force on)
# These tests involve backspace, cursor movement, kill-to-end, etc.

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Line Editing (-E0, -E, -E1)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "default editing: backspace corrects input"
echo    "  With -n3, you can use Backspace to correct mistakes."
instruct "Type 'a', 'b', Backspace, 'c', 'd'  →  result should be 'acd'"
show_command "-n3"
echo
actual_out=$("$GRABCHARS" -n3 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "acd" && check_exit "$actual_exit" "3" && pass || fail "expected 'acd' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-E0: editing disabled — backspace is a literal character"
echo    "  With -E0, Backspace is passed through as a raw character, not erased."
echo    "  The buffer fills with whatever raw bytes you type."
instruct "Type 'a', then Backspace — grabchars should exit (2 chars received)"
show_command "-n2 -E0"
echo
# We can't easily verify backspace byte in the output, so check exit=2
actual_out=$("$GRABCHARS" -n2 -E0 2>/dev/tty)
actual_exit=$?
echo
echo    "  Exit code: $actual_exit  (expected 2)"
check_exit "$actual_exit" "2" && pass || fail "expected exit 2 (2 raw chars)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-E1: editing explicitly enabled"
echo    "  -E1 forces editing on. Same behavior as default."
instruct "Type 'x', 'y', Backspace, 'z', then Enter  →  result should be 'xz'"
show_command "-n3 -E1 -r"
echo
actual_out=$("$GRABCHARS" -n3 -E1 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "xz" && check_exit "$actual_exit" "2" && pass || fail "expected 'xz' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "cursor movement: left/right arrows reposition within buffer"
echo    "  In edit mode with -n4, use Left arrow to back up, then type to insert."
instruct "Type 'a', 'b', 'c', Left arrow, Left arrow, 'd' — result 'adbc'"
echo    "  (Left×2 brings cursor before 'b'; typing 'd' inserts there)"
show_command "-n4"
echo
actual_out=$("$GRABCHARS" -n4 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "adbc" && check_exit "$actual_exit" "4" && pass || fail "expected 'adbc' with exit 4"

# ─────────────────────────────────────────────────────────────────────────────
test_start "kill to end of line (Ctrl-K)"
echo    "  Ctrl-K deletes from cursor to end of buffer."
instruct "Type 'a', 'b', 'c', 'd', Left×2, then Ctrl-K, then Enter (-r mode)"
echo    "  Result should be 'ab' (cd were killed)"
show_command "-n10 -r"
echo
actual_out=$("$GRABCHARS" -n10 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "ab" && check_exit "$actual_exit" "2" && pass || fail "expected 'ab' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "kill word back (Ctrl-W)"
echo    "  Ctrl-W deletes backward one word."
instruct "Type 'hello', then Ctrl-W, then Enter (-r mode)"
echo    "  Result should be '' (entire word killed)"
show_command "-n10 -r"
echo
actual_out=$("$GRABCHARS" -n10 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" && check_exit "$actual_exit" "0" && pass || fail "expected empty with exit 0"

print_summary
