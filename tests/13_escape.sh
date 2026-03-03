#!/usr/bin/env bash
# 13_escape.sh - ESC bail flag (-B) tests

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

OPTS="yes no maybe"

# ─────────────────────────────────────────────────────────────────────────────
test_section "ESC Bail Flag (-B) — automated validation"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-B254 rejected: conflicts with timeout exit code"
watch_note "fully automated — no keystrokes needed"
show_command "-B254 -cy"
echo
"$GRABCHARS" -B254 -cy 2>/dev/null
actual_exit=$?
echo
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 (invalid -B254)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-B256 rejected: out of range"
watch_note "fully automated — no keystrokes needed"
show_command "-B256 -cy"
echo
"$GRABCHARS" -B256 -cy 2>/dev/null
actual_exit=$?
echo
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 (invalid -B256)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-Babc rejected: non-numeric argument"
watch_note "fully automated — no keystrokes needed"
show_command "-Babc -cy"
echo
"$GRABCHARS" -Babc -cy 2>/dev/null
actual_exit=$?
echo
check_exit "$actual_exit" "255" && pass || fail "expected exit 255 (invalid -Babc)"

# ─────────────────────────────────────────────────────────────────────────────
test_section "ESC Bail Flag (-B) — Normal Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -B200: ESC exits with code 200"
echo    "  With -B200, pressing Escape exits immediately with code 200."
echo    "  No output is produced."
instruct "Press Escape"
show_command "-B200 -cy"
echo
actual_out=$("$GRABCHARS" -B200 -cy 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "200" && pass || fail "expected exit 200, no output"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -B0: ESC is a no-op, then accept input"
echo    "  With -B0, Escape is silently ignored."
echo    "  Press ESC first, then type 'y' — 'y' should be returned."
instruct "Press Escape, then type 'y'"
show_command "-B0 -cy"
echo
actual_out=$("$GRABCHARS" -B0 -cy 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "y" && check_exit "$actual_exit" "1" \
  && pass || fail "expected 'y' with exit 1 after ESC no-op"

# ─────────────────────────────────────────────────────────────────────────────
test_start "normal mode -B255: ESC exits with code 255 (explicit)"
echo    "  -B255 is the explicit form of the mask/select default."
echo    "  In normal mode (where ESC is normally a no-op), -B255 makes ESC exit."
instruct "Press Escape"
show_command "-B255 -cy"
echo
actual_out=$("$GRABCHARS" -B255 -cy 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "255" && pass || fail "expected exit 255, no output"

# ─────────────────────────────────────────────────────────────────────────────
test_section "ESC Bail Flag (-B) — Mask Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "mask mode default: ESC exits with code 255"
echo    "  Without -B, ESC in mask mode clears the display and exits 255."
instruct "Press Escape"
show_command "-m nnn -q 'Digits: '"
echo
actual_out=$("$GRABCHARS" -m nnn -q "Digits: " 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "255" && pass || fail "expected exit 255 on ESC"

# ─────────────────────────────────────────────────────────────────────────────
test_start "mask mode -B200: ESC exits with code 200"
echo    "  With -B200, pressing ESC in mask mode exits with code 200 instead of 255."
instruct "Press Escape"
show_command "-B200 -m nnn -q 'Digits: '"
echo
actual_out=$("$GRABCHARS" -B200 -m nnn -q "Digits: " 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "200" && pass || fail "expected exit 200, no output"

# ─────────────────────────────────────────────────────────────────────────────
test_start "mask mode -B0: ESC is a no-op, then complete the mask"
echo    "  With -B0, ESC is silently ignored in mask mode."
echo    "  Press ESC first, then type '1', '2', '3' to fill the 3-digit mask."
instruct "Press Escape, then type '1', '2', '3'"
show_command "-B0 -m nnn -q 'Digits: '"
echo
actual_out=$("$GRABCHARS" -B0 -m nnn -q "Digits: " 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "123" && check_exit "$actual_exit" "3" \
  && pass || fail "expected '123' with exit 3 after ESC no-op"

# ─────────────────────────────────────────────────────────────────────────────
test_section "ESC Bail Flag (-B) — Select Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -B200: ESC exits with code 200"
echo    "  With -B200, pressing ESC in select mode exits with code 200."
instruct "Press Escape"
show_command "select -B200 $OPTS"
echo
actual_out=$("$GRABCHARS" select -B200 $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "200" && pass || fail "expected exit 200, no output"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select -B0: ESC is a no-op, then choose 'no'"
echo    "  With -B0, ESC is silently ignored in select mode."
echo    "  Press ESC, then type 'n' to match 'no', then Enter."
instruct "Press Escape, type 'n', press Enter"
show_command "select -B0 $OPTS"
echo
actual_out=$("$GRABCHARS" select -B0 $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "no" && check_exit "$actual_exit" "1" \
  && pass || fail "expected 'no' with exit 1 after ESC no-op"

# ─────────────────────────────────────────────────────────────────────────────
test_section "ESC Bail Flag (-B) — Select-LR Mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr -B200: ESC exits with code 200"
echo    "  With -B200, pressing ESC in select-lr mode exits with code 200."
instruct "Press Escape"
show_command "select-lr -B200 $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr -B200 $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)" \
  && check_exit "$actual_exit" "200" && pass || fail "expected exit 200, no output"

# ─────────────────────────────────────────────────────────────────────────────
test_start "select-lr -B0: ESC is a no-op, then confirm first option"
echo    "  With -B0, ESC is silently ignored in select-lr mode."
echo    "  Press ESC, then press Enter to confirm the first option ('yes')."
instruct "Press Escape, then press Enter"
show_command "select-lr -B0 $OPTS"
echo
actual_out=$("$GRABCHARS" select-lr -B0 $OPTS 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" \
  && pass || fail "expected 'yes' with exit 3 after ESC no-op"

print_summary
