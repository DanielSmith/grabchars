#!/usr/bin/env bash
# 07_output.sh - Output routing: -e (stderr), -b (both), -s (silent), -Z

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Output Routing (-e, -b, -s, -Z)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-e: output goes to stderr only"
echo    "  With -e, the character is written to stderr, not stdout."
instruct "Type 'x'"
show_command "-e"
echo
_tmpfile=$(mktemp)
stdout=$("$GRABCHARS" -e 2>"$_tmpfile")
stderr=$(cat "$_tmpfile"); rm -f "$_tmpfile"
echo
ok=0
check_output "$stdout" "" "stdout (should be empty)" || ok=1
check_output "$stderr" "x" "stderr"                  || ok=1
[[ $ok -eq 0 ]] && pass || fail "output routing wrong"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-b: output goes to both stdout and stderr"
echo    "  With -b, the character appears on both streams simultaneously."
echo    "  Useful for: capture output AND show it to the user at the same time."
instruct "Type 'm'"
show_command "-b"
echo
_tmpfile=$(mktemp)
stdout=$("$GRABCHARS" -b 2>"$_tmpfile")
stderr=$(cat "$_tmpfile"); rm -f "$_tmpfile"
echo
ok=0
check_output "$stdout" "m" "stdout" || ok=1
check_output "$stderr" "m" "stderr" || ok=1
[[ $ok -eq 0 ]] && pass || fail "both-stream output wrong"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-s: silent mode — nothing output, exit code still works"
echo    "  -s suppresses all character output. Exit code still = chars read."
instruct "Type any character"
show_command "-s"
echo
stdout=$("$GRABCHARS" -s 2>/dev/null)
actual_exit=$?
echo
check_output "$stdout" "" "stdout (should be empty)"
check_exit "$actual_exit" "1" && pass || fail "expected exit 1 in silent mode"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-s with -n3: silent, exit = char count"
instruct "Type three characters: '1', '2', '3'"
show_command "-s -n3"
echo
stdout=$("$GRABCHARS" -s -n3 2>/dev/null)
actual_exit=$?
echo
check_output "$stdout" "" "stdout (should be empty)"
check_exit "$actual_exit" "3" && pass || fail "expected exit 3 (three chars, silent)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-p prompt: prompt printed to stdout before reading"
echo    "  -p prints a prompt to stdout. You should see it appear."
instruct "Type 'y' when the prompt appears"
show_command '-p "Continue? "'
echo
actual_out=$("$GRABCHARS" -p"Continue? " 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "Continue? y" && check_exit "$actual_exit" "1" && pass || fail "prompt+char on stdout expected"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-q prompt: prompt printed to stderr (stdout clean for capture)"
echo    "  -q puts the prompt on stderr. stdout gets only the typed character."
echo    "  This is the recommended pattern for shell scripts."
instruct "Type 'n' when the prompt appears"
show_command '-q "Continue? "'
echo
actual_out=$("$GRABCHARS" -q"Continue? " 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "n" "stdout (prompt excluded)" && check_exit "$actual_exit" "1" && pass || fail "only char on stdout expected"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-Z0: suppress trailing newline to stderr"
echo    "  Normally grabchars emits a trailing newline to stderr."
echo    "  -Z0 suppresses it."
watch_note "automated check — comparing stderr byte-for-byte"
show_command '-q "Test" -dy -t1  (vs -Z0 variant)'
stderr_with=$("$GRABCHARS"    -q "Test" -dy -t1 2>&1 >/dev/null)
stderr_without=$("$GRABCHARS" -q "Test" -dy -t1 -Z0 2>&1 >/dev/null)
echo
if [[ "$stderr_with" != "$stderr_without" ]]; then
    pass "-Z0 changes stderr output as expected"
else
    fail "stderr was identical with and without -Z0"
fi

print_summary
