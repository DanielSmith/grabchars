#!/usr/bin/env bash
# 04_default.sh - Default value on Enter: -d flag

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Default Value (-d)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-d: single char default on Enter"
echo    "  With -d y, pressing Enter immediately outputs 'y'."
echo    "  Exit code = length of default string = 1."
instruct "Press Enter immediately (do not type anything)"
show_command "-dy"
echo
actual_out=$("$GRABCHARS" -dy 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "y" && check_exit "$actual_exit" "1" && pass || fail "expected 'y' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-d: multi-char default string on Enter"
echo    "  Default is the word 'yes'. Enter produces it."
echo    "  Exit code = 3 (length of 'yes')."
instruct "Press Enter immediately"
show_command "-dyes"
echo
actual_out=$("$GRABCHARS" -dyes 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" && pass || fail "expected 'yes' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-d: typing a char overrides the default"
echo    "  If you type a real character, default is not used."
instruct "Type 'n'"
show_command "-dyes"
echo
actual_out=$("$GRABCHARS" -dyes 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "n" && check_exit "$actual_exit" "1" && pass || fail "expected 'n' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-d with -s (silent): default still returned, nothing echoed"
echo    "  Silent mode suppresses all output — but exit code still reflects default length."
instruct "Press Enter immediately"
show_command "-dyes -s"
echo
actual_out=$("$GRABCHARS" -dyes -s 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (silent — should be empty)"
check_exit "$actual_exit" "3" && pass || fail "expected exit 3 (len of 'yes') even in silent mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-d with -n3 -r: default fires on Enter even mid-sequence"
echo    "  Set up to read 3 chars but -r allows early exit."
echo    "  Pressing Enter immediately should use the default."
instruct "Press Enter immediately (no chars)"
show_command "-n3 -r -dgumby"
echo
actual_out=$("$GRABCHARS" -n3 -r -dgumby 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "gumby" && check_exit "$actual_exit" "5" && pass || fail "expected 'gumby' with exit 5"

print_summary
