#!/usr/bin/env bash
# 09_mask.sh - Mask mode (-m): positional input validation

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Mask Mode (-m)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m 'nnn' -e: exactly 3 digits (echo+both)"
echo    "  Mask 'nnn' requires exactly three digit characters."
echo    "  Non-digits are rejected silently. You see each digit as you type."
instruct "Type '4', '2', '7' (letters ignored if you make a mistake)"
show_command "-m 'nnn' -e -b"
echo
actual_out=$("$GRABCHARS" -m'nnn' -e -b)
actual_exit=$?
echo
check_output "$actual_out" "427" && check_exit "$actual_exit" "3" && pass || fail "expected '427' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m 'Ulll' -e: 1 uppercase + 3 lowercase (echo+both)"
echo    "  Mask: U=uppercase, l=lowercase. You see each letter as you type."
instruct "Type 'J', 'o', 'h', 'n'"
show_command "-m 'Ulll' -e -b"
echo
actual_out=$("$GRABCHARS" -m'Ulll' -e -b)
actual_exit=$?
echo
check_output "$actual_out" "John" && check_exit "$actual_exit" "4" && pass || fail "expected 'John' with exit 4"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m phone -e: auto-inserts literal formatting (echo+both)"
echo    "  Mask: '(nnn) nnn-nnnn'"
echo    "  Parentheses, space, and dash are auto-inserted as literals."
echo    "  You only type the 10 digits. Watch the formatting appear."
instruct "Type: 4, 1, 5, 5, 5, 5, 1, 2, 1, 2"
show_command "-m '(nnn) nnn-nnnn' -e -b"
echo
actual_out=$("$GRABCHARS" -m'(nnn) nnn-nnnn' -e -b)
actual_exit=$?
echo
check_output "$actual_out" "(415) 555-1212" && check_exit "$actual_exit" "14" && pass || fail "expected '(415) 555-1212'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m date -e: auto-inserts slashes (echo+both)"
echo    "  Mask: 'nn/nn/nnnn'"
echo    "  Slashes auto-inserted. You type only the 8 digits."
instruct "Type: 0, 7, 0, 4, 1, 9, 7, 6"
show_command "-m 'nn/nn/nnnn' -e -b"
echo
actual_out=$("$GRABCHARS" -m'nn/nn/nnnn' -e -b)
actual_exit=$?
echo
check_output "$actual_out" "07/04/1976" && check_exit "$actual_exit" "10" && pass || fail "expected '07/04/1976'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m backspace through literals -e (echo+both)"
echo    "  Backspace removes the auto-inserted literal dash, but not the preceding digit."
echo    "  Mask: 'nn-nn'. Type '1','2' (dash auto-inserted → '12-')."
echo    "  Backspace removes the dash. Then '9' triggers dash re-insertion → '12-9'."
echo    "  Finally '8' completes the mask → '12-98'."
instruct "Type '1', '2', then Backspace, then '9', '8' → result: '12-98'"
show_command "-m 'nn-nn' -e -b"
echo
actual_out=$("$GRABCHARS" -m'nn-nn' -e -b)
actual_exit=$?
echo
check_output "$actual_out" "12-98" && check_exit "$actual_exit" "5" && pass || fail "expected '12-98'"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m quantifier: 'n+' -e -r: one or more digits, Enter to finish"
echo    "  Mask 'n+' with -r -e: enter any number of digits, press Enter when done."
echo    "  You see each digit as you type."
instruct "Type '4', '2' then press Enter"
show_command "-m 'n+' -r -e -b"
echo
actual_out=$("$GRABCHARS" -m'n+' -r -e -b)
actual_exit=$?
echo
check_output "$actual_out" "42" && check_exit "$actual_exit" "2" && pass || fail "expected '42' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-m quantifier: 'c?nnn' -e: optional letter + 3 digits"
echo    "  Mask 'c?nnn': optional letter, then exactly 3 digits."
echo    "  You see characters as you type."
instruct "Skip the letter — just type '1', '2', '3'"
show_command "-m 'c?nnn' -e -b"
echo
actual_out=$("$GRABCHARS" -m'c?nnn' -e -b)
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
