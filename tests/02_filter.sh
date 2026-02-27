#!/usr/bin/env bash
# 02_filter.sh - Character filtering: -c (include) and -C (exclude)

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Character Filtering (-c and -C)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c vowels: accept only aeiou"
echo    "  Only vowel keystrokes are accepted. Non-vowels are silently ignored."
instruct "First type a non-vowel (e.g. 'b'), then type 'a' — only 'a' should register"
show_command "-caeiou"
echo
actual_out=$("$GRABCHARS" -caeiou 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "a" && check_exit "$actual_exit" "1" && pass || fail "expected 'a' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c digit range [0-9]"
echo    "  Only digits 0-9 are accepted."
instruct "Type a letter first (ignored), then type '7'"
show_command "-c '[0-9]'"
echo
actual_out=$("$GRABCHARS" -c'[0-9]' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "7" && check_exit "$actual_exit" "1" && pass || fail "expected '7' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c yes/no filter"
echo    "  Tight filter — only y and n accepted."
instruct "Type 'n'"
show_command "-cyn"
echo
actual_out=$("$GRABCHARS" -cyn 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "n" && check_exit "$actual_exit" "1" && pass || fail "expected 'n' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-C exclude filter: reject 'aeiou', accept consonants"
echo    "  -C is the exclusion filter — listed chars are rejected."
instruct "Type 'e' first (rejected), then type 'b'"
show_command "-Caeiou"
echo
actual_out=$("$GRABCHARS" -Caeiou 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "b" && check_exit "$actual_exit" "1" && pass || fail "expected 'b' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c with -n3: collect 3 vowels"
echo    "  Reads exactly 3 characters, all must be vowels."
instruct "Type three vowels: 'a', 'e', 'i'"
show_command "-caeiou -n3"
echo
actual_out=$("$GRABCHARS" -caeiou -n3 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "aei" && check_exit "$actual_exit" "3" && pass || fail "expected 'aei' with exit 3"

print_summary
