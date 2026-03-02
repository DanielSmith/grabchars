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

# ─────────────────────────────────────────────────────────────────────────────
test_section "Select Mode — Filter Styles (-F)"

CITY_OPTS="san francisco,santa maria,san jose,san luis obispo,san diego"
NEW_OPTS="new haven,new york,newest first,renew annually"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Fp: explicit prefix filter — 'san d' isolates 'san diego'"
echo    "  -Fp is the default. Only options whose names START WITH the typed text match."
echo    "  'san d' matches 'san diego' and nothing else."
instruct "Type 's', 'a', 'n', ' ', 'd', then press Enter"
show_command "select -Fp \"san francisco,santa maria,...\""
echo
actual_out=$("$GRABCHARS" select -Fp "$CITY_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "san diego" && check_exit "$actual_exit" "4" && pass || fail "expected 'san diego' with exit 4"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Ff: fuzzy — 'sf' isolates 'san francisco'"
echo    "  Fuzzy: each typed character must appear in the option in order"
echo    "  with any characters in between (like s.*f as a regex)."
echo    "  Only 'san francisco' has 'f' anywhere after 's'."
instruct "Type 's', 'f', then press Enter"
show_command "select -Ff \"san francisco,santa maria,...\""
echo
actual_out=$("$GRABCHARS" select -Ff "$CITY_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "san francisco" && check_exit "$actual_exit" "0" && pass || fail "expected 'san francisco' with exit 0"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Ff: fuzzy — 'sl' isolates 'san luis obispo'"
echo    "  Only 'san luis obispo' has 'l' anywhere after 's'."
instruct "Type 's', 'l', then press Enter"
show_command "select -Ff \"san francisco,santa maria,...\""
echo
actual_out=$("$GRABCHARS" select -Ff "$CITY_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "san luis obispo" && check_exit "$actual_exit" "3" && pass || fail "expected 'san luis obispo' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Ff: fuzzy — 'nek' isolates 'new york'"
echo    "  n-e-k in order: new(y)or(k) — only 'new york' has all three in sequence."
instruct "Type 'n', 'e', 'k', then press Enter"
show_command "select -Ff \"new haven,new york,...\""
echo
actual_out=$("$GRABCHARS" select -Ff "$NEW_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "new york" && check_exit "$actual_exit" "1" && pass || fail "expected 'new york' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Fc: contains — 'york' isolates 'new york'"
echo    "  Contains: the typed text must appear as a contiguous substring anywhere."
echo    "  'york' is only a substring of 'new york'."
instruct "Type 'y', 'o', 'r', 'k', then press Enter"
show_command "select -Fc \"new haven,new york,...\""
echo
actual_out=$("$GRABCHARS" select -Fc "$NEW_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "new york" && check_exit "$actual_exit" "1" && pass || fail "expected 'new york' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -Fc: contains — 'ren' isolates 'renew annually'"
echo    "  'ren' appears only at the start of 'renew annually' in this list."
instruct "Type 'r', 'e', 'n', then press Enter"
show_command "select -Fc \"new haven,new york,...\""
echo
actual_out=$("$GRABCHARS" select -Fc "$NEW_OPTS" 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "renew annually" && check_exit "$actual_exit" "3" && pass || fail "expected 'renew annually' with exit 3"

print_summary
