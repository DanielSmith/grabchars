#!/usr/bin/env bash
# 01_basic.sh - Basic single-character capture

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Basic Operation"

# ─────────────────────────────────────────────────────────────────────────────
test_start "single character capture"
echo    "  grabchars with no flags reads one character and exits."
echo    "  The character is echoed to stdout. Exit code = 1."
instruct "Type the letter 'a'"
show_command ""
echo
actual_out=$("$GRABCHARS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "a" && check_exit "$actual_exit" "1" && pass || fail "output or exit code wrong"

# ─────────────────────────────────────────────────────────────────────────────
test_start "single character, any key"
echo    "  Exit code equals the number of characters read (1)."
instruct "Type any single character"
show_command ""
echo
actual_out=$("$GRABCHARS" 2>/dev/null)
actual_exit=$?
echo
echo    "  You typed: \"$actual_out\""
check_exit "$actual_exit" "1" && pass || fail "exit code should be 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "stdout vs stderr routing (default)"
echo    "  By default output goes to stdout. Stderr should be empty."
instruct "Type 'x'"
show_command ""
echo
_tmpfile=$(mktemp)
actual_stdout=$("$GRABCHARS" 2>"$_tmpfile")
actual_stderr=$(cat "$_tmpfile"); rm -f "$_tmpfile"
echo
ok=0
check_output "$actual_stdout" "x" "stdout" || ok=1
check_output "$actual_stderr" ""  "stderr (should be empty)" || ok=1
[[ $ok -eq 0 ]] && pass || fail "stdout/stderr routing wrong"

# ─────────────────────────────────────────────────────────────────────────────
test_start "version flag"
watch_note "fully automated — no keystrokes needed"
show_command "--version"
actual_out=$("$GRABCHARS" --version 2>&1)
actual_exit=$?
check_output_contains "$actual_out" "2.0" "version string"
check_exit "$actual_exit" "0" && pass || fail "exit should be 0 for --version"

# ─────────────────────────────────────────────────────────────────────────────
test_start "help flag exits with 255"
watch_note "fully automated — no keystrokes needed"
show_command "-h"
"$GRABCHARS" -h >/dev/null 2>&1
actual_exit=$?
check_exit "$actual_exit" "255" && pass || fail "exit should be 255 for -h"

print_summary
