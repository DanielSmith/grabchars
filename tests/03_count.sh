#!/usr/bin/env bash
# 03_count.sh - Multi-character input: -n and -r flags

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Character Count (-n) and Return-exits (-r)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-n3: read exactly 3 characters"
echo    "  grabchars exits automatically after exactly 3 keystrokes."
echo    "  No Enter needed."
instruct "Type exactly three characters: 'a', 'b', 'c'"
show_command "-n3"
echo
actual_out=$("$GRABCHARS" -n3 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "abc" && check_exit "$actual_exit" "3" && pass || fail "expected 'abc' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-n5: read exactly 5 characters"
instruct "Type five characters: '1', '2', '3', '4', '5'"
show_command "-n5"
echo
actual_out=$("$GRABCHARS" -n5 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "12345" && check_exit "$actual_exit" "5" && pass || fail "expected '12345' with exit 5"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-n3 -r: read up to 3 chars, RETURN exits early"
echo    "  With -r, pressing Enter exits immediately with however many chars were typed."
instruct "Type 'a', then press Enter (exit after 1 char)"
show_command "-n3 -r"
echo
actual_out=$("$GRABCHARS" -n3 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "a"  "stdout" && check_exit "$actual_exit" "1" && pass || fail "expected 'a' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-n3 -r: RETURN on first keystroke (empty input)"
echo    "  Pressing Enter immediately with no prior input."
echo    "  Should output nothing and exit with code 0."
instruct "Press Enter immediately without typing anything"
show_command "-n3 -r"
echo
actual_out=$("$GRABCHARS" -n3 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (empty)" && check_exit "$actual_exit" "0" && pass || fail "expected empty output and exit 0"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-n3 -r: complete all 3 chars without Enter"
echo    "  With -r but enough chars typed, Enter is not needed."
instruct "Type 'x', 'y', 'z' quickly (no Enter)"
show_command "-n3 -r"
echo
actual_out=$("$GRABCHARS" -n3 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "xyz" && check_exit "$actual_exit" "3" && pass || fail "expected 'xyz' with exit 3"

print_summary
