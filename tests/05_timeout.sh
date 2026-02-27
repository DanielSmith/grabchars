#!/usr/bin/env bash
# 05_timeout.sh - Timeout behavior: -t flag
# These tests require NO keystrokes — watch what happens.

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Timeout (-t)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t3: timeout with no default, no input"
echo    "  grabchars will show a prompt and wait. After 3 seconds it times out."
echo    "  Nothing is output. Exit code = 254 (timeout)."
instruct "Do NOT type anything — just watch the clock run out"
show_command '-q "Waiting (timeout in 3s): " -t3'
echo
watch_note "timing out in 3 seconds..."
actual_out=$("$GRABCHARS" -q "  Waiting (timeout in 3s): " -t3 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit "$actual_exit" "254" && pass || fail "expected exit 254 on timeout"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t3 -d yes: timeout fires the default"
echo    "  When timeout occurs and -d is set, the default is output as if typed."
echo    "  Output: 'yes'. Exit code = 3 (length of 'yes')."
instruct "Do NOT type anything — watch it time out and print the default"
show_command '-q "Waiting (timeout in 3s, default=yes): " -t3 -dyes'
echo
watch_note "timing out in 3 seconds..."
actual_out=$("$GRABCHARS" -q "  Waiting (timeout in 3s, default=yes): " -t3 -dyes 2>/dev/null)
actual_exit=$?
echo
echo    "  Output was: \"$actual_out\""
check_output "$actual_out" "yes" && check_exit "$actual_exit" "3" && pass || fail "expected 'yes' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t5 -d 'gumby': longer timeout with multi-word default"
echo    "  5-second timeout, default is 'gumby'. Watch it fire."
instruct "Do NOT type anything"
show_command '-q "Waiting for input (5s timeout, default=gumby): " -t5 -dgumby'
echo
watch_note "timing out in 5 seconds..."
actual_out=$("$GRABCHARS" -q "  Waiting for input (5s timeout, default=gumby): " -t5 -dgumby 2>/dev/null)
actual_exit=$?
echo
echo    "  Output was: \"$actual_out\""
check_output "$actual_out" "gumby" && check_exit "$actual_exit" "5" && pass || fail "expected 'gumby' with exit 5"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t3: user types before timeout — timeout does NOT fire"
echo    "  If you type before the clock runs out, grabchars exits normally."
echo    "  Exit code = 1 (one char read), not 254."
instruct "Type 'z' within 3 seconds"
show_command "-q \"Type 'z' within 3 seconds: \" -t3"
echo
actual_out=$("$GRABCHARS" -q "  Type 'z' within 3 seconds: " -t3 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "z" && check_exit "$actual_exit" "1" && pass || fail "expected 'z' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t3 -d y: type something — default NOT used"
echo    "  Even with -d set, if you type a real character the default is bypassed."
instruct "Type 'n' within 3 seconds"
show_command "-q \"Type 'n' within 3 seconds (default=y): \" -t3 -dy"
echo
actual_out=$("$GRABCHARS" -q "  Type 'n' within 3 seconds (default=y): " -t3 -dy 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "n" && check_exit "$actual_exit" "1" && pass || fail "expected 'n' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-t2 with -n3 -r: timeout during multi-char read"
echo    "  Even in multi-char mode, timeout fires cleanly."
echo    "  Exit code = 254 (timeout, no default)."
instruct "Do NOT type anything — let it time out"
show_command '-q "Multi-char timeout (2s): " -n3 -r -t2'
echo
watch_note "timing out in 2 seconds..."
actual_out=$("$GRABCHARS" -q "  Multi-char timeout (2s): " -n3 -r -t2 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit "$actual_exit" "254" && pass || fail "expected exit 254"

print_summary
