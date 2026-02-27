#!/usr/bin/env bash
# 06_case.sh - Case mapping: -U (uppercase) and -L (lowercase)

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Case Mapping (-U and -L)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-U: lowercase input mapped to uppercase"
echo    "  Type a lowercase letter — it should come out uppercase."
instruct "Type 'a'"
show_command "-U"
echo
actual_out=$("$GRABCHARS" -U 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "A" && check_exit "$actual_exit" "1" && pass || fail "expected 'A' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-U: uppercase input stays uppercase"
instruct "Type 'B' (capital)"
show_command "-U"
echo
actual_out=$("$GRABCHARS" -U 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "B" && check_exit "$actual_exit" "1" && pass || fail "expected 'B' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-L: uppercase input mapped to lowercase"
echo    "  Type a capital — it should come out lowercase."
instruct "Type 'Z' (capital)"
show_command "-L"
echo
actual_out=$("$GRABCHARS" -L 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "z" && check_exit "$actual_exit" "1" && pass || fail "expected 'z' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-L: lowercase input stays lowercase"
instruct "Type 'q'"
show_command "-L"
echo
actual_out=$("$GRABCHARS" -L 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "q" && check_exit "$actual_exit" "1" && pass || fail "expected 'q' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-U with -n3: all 3 chars uppercased"
instruct "Type 'a', 'b', 'c'"
show_command "-U -n3"
echo
actual_out=$("$GRABCHARS" -U -n3 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "ABC" && check_exit "$actual_exit" "3" && pass || fail "expected 'ABC' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-U with -c[a-z]: filter to lowercase, then uppercase"
echo    "  Case mapping applies after filtering."
echo    "  -c accepts only lowercase; -U then converts them."
instruct "Type a capital 'A' first (rejected), then lowercase 'b'"
show_command "-U -c'[a-z]'"
echo
actual_out=$("$GRABCHARS" -U -c'[a-z]' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "B" && check_exit "$actual_exit" "1" && pass || fail "expected 'B' with exit 1"

print_summary
