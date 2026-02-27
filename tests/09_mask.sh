#!/usr/bin/env bash
# 09_mask.sh - Mask mode (-m): positional input validation

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Mask Mode (-m)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m 'nnn': exactly 3 digits"
echo    "  Mask 'nnn' requires exactly three digit characters."
echo    "  Non-digits are rejected silently."
instruct "Type '4', '2', '7' (letters ignored if you make a mistake)"
show_command "-m 'nnn'"
echo
actual_out=$("$GRABCHARS" -m'nnn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "427" && check_exit "$actual_exit" "3" && pass || fail "expected '427' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m 'Ulll': 1 uppercase + 3 lowercase"
echo    "  Mask: U=uppercase, l=lowercase."
instruct "Type 'J', 'o', 'h', 'n'"
show_command "-m 'Ulll'"
echo
actual_out=$("$GRABCHARS" -m'Ulll' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "John" && check_exit "$actual_exit" "4" && pass || fail "expected 'John' with exit 4"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m phone: auto-inserts literal formatting"
echo    "  Mask: '(nnn) nnn-nnnn'"
echo    "  Parentheses, space, and dash are auto-inserted as literals."
echo    "  You only type the 10 digits."
instruct "Type: 4, 1, 5, 5, 5, 5, 1, 2, 1, 2"
show_command "-m '(nnn) nnn-nnnn'"
echo
actual_out=$("$GRABCHARS" -m'(nnn) nnn-nnnn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "(415) 555-1212" && check_exit "$actual_exit" "14" && pass || fail "expected '(415) 555-1212'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m date: auto-inserts slashes"
echo    "  Mask: 'nn/nn/nnnn'"
echo    "  Slashes auto-inserted. You type only the 8 digits."
instruct "Type: 0, 7, 0, 4, 1, 9, 7, 6"
show_command "-m 'nn/nn/nnnn'"
echo
actual_out=$("$GRABCHARS" -m'nn/nn/nnnn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "07/04/1976" && check_exit "$actual_exit" "10" && pass || fail "expected '07/04/1976'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m backspace through literals"
echo    "  Backspace should remove the last digit AND the auto-inserted literal."
echo    "  Mask: 'nn-nn'. Type '1','2' (dash appears), then Backspace should"
echo    "  remove the dash and '2', leaving just '1'."
instruct "Type '1', '2', then Backspace, then '9', '8' → result: '19-88'"
show_command "-m 'nn-nn'"
echo
actual_out=$("$GRABCHARS" -m'nn-nn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "19-88" && check_exit "$actual_exit" "5" && pass || fail "expected '19-88'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m quantifier: 'n+' accepts one or more digits, Enter to finish"
echo    "  Mask 'n+' with -r: enter any number of digits, press Enter when done."
instruct "Type '4', '2' then press Enter"
show_command "-m 'n+' -r"
echo
actual_out=$("$GRABCHARS" -m'n+' -r 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "42" && check_exit "$actual_exit" "2" && pass || fail "expected '42' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m quantifier: 'c?' optional letter + 'nnn'"
echo    "  Mask 'c?nnn': optional letter, then exactly 3 digits."
instruct "Skip the letter — just type '1', '2', '3'"
show_command "-m 'c?nnn'"
echo
actual_out=$("$GRABCHARS" -m'c?nnn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "123" && check_exit "$actual_exit" "3" && pass || fail "expected '123' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m Escape cancels"
echo    "  Pressing Escape in mask mode cancels with exit 255."
instruct "Press Escape immediately"
show_command "-m 'nnn'"
echo
actual_out=$("$GRABCHARS" -m'nnn' 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 on Escape"

print_summary
