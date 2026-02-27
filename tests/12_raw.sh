#!/usr/bin/env bash
# 12_raw.sh - Raw mode (-R flag): byte-level capture, no escape parsing

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
_check_binary

test_section "Raw Mode (-R)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "timeout with no default → exit 254 (automated)"
echo    "  -R -n5 -t2: nothing typed, timeout fires."
echo    "  No output. Exit code = 254."
watch_note "timing out in 2 seconds..."
show_command "-R -n5 -t2"
actual_out=$("$GRABCHARS" -R -n5 -t2 2>/dev/null)
actual_exit=$?
check_output "$actual_out" "" "stdout (should be empty)"
check_exit   "$actual_exit" "254" && pass || fail "expected exit 254 on timeout"

# ─────────────────────────────────────────────────────────────────────────────
test_start "timeout with default → default output (automated)"
echo    "  -R -n5 -t2 -d hello: timeout fires, default 'hello' is returned."
echo    "  Output: 'hello'. Exit code = 5."
watch_note "timing out in 2 seconds..."
show_command "-R -n5 -t2 -dhello"
actual_out=$("$GRABCHARS" -R -n5 -t2 -dhello 2>/dev/null)
actual_exit=$?
check_output "$actual_out" "hello" "stdout"
check_exit   "$actual_exit" "5" && pass || fail "expected 'hello' with exit 5"

# ─────────────────────────────────────────────────────────────────────────────
test_start "timeout with default + -s → no output, exit = default length (automated)"
echo    "  -R -n5 -t2 -d hello -s: timeout fires but -s suppresses output."
echo    "  Nothing on stdout. Exit code = 5 (length of 'hello')."
watch_note "timing out in 2 seconds..."
show_command "-R -n5 -t2 -dhello -s"
actual_out=$("$GRABCHARS" -R -n5 -t2 -dhello -s 2>/dev/null)
actual_exit=$?
check_output "$actual_out" "" "stdout (silent — should be empty)"
check_exit   "$actual_exit" "5" && pass || fail "expected exit 5 (silent timeout default)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-e output routing with timeout+default (automated)"
echo    "  -R -t2 -d hi -e: timeout fires, default 'hi' goes to stderr."
echo    "  Stdout empty. Stderr: 'hi'. Exit code = 2."
watch_note "timing out in 2 seconds..."
show_command "-R -t2 -dhi -e"
_tmpfile=$(mktemp)
stdout=$("$GRABCHARS" -R -t2 -dhi -e 2>"$_tmpfile")
actual_exit=$?
stderr=$(cat "$_tmpfile"); rm -f "$_tmpfile"
ok=0
check_output "$stdout" ""   "stdout (should be empty)" || ok=1
check_output "$stderr" "hi" "stderr"                   || ok=1
check_exit   "$actual_exit" "2"                        || ok=1
[[ $ok -eq 0 ]] && pass || fail "expected 'hi' on stderr, stdout empty, exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-b output routing with timeout+default (automated)"
echo    "  -R -t2 -d hi -b: timeout fires, default 'hi' goes to both streams."
echo    "  Stdout: 'hi'. Stderr: 'hi'. Exit code = 2."
watch_note "timing out in 2 seconds..."
show_command "-R -t2 -dhi -b"
_tmpfile=$(mktemp)
stdout=$("$GRABCHARS" -R -t2 -dhi -b 2>"$_tmpfile")
actual_exit=$?
stderr=$(cat "$_tmpfile"); rm -f "$_tmpfile"
ok=0
check_output "$stdout" "hi" "stdout" || ok=1
check_output "$stderr" "hi" "stderr" || ok=1
check_exit   "$actual_exit" "2"      || ok=1
[[ $ok -eq 0 ]] && pass || fail "expected 'hi' on both streams, exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c and -U flags silently ignored (automated)"
echo    "  -R -t1 -d x -c z: -c filter is ignored; timeout fires and returns default."
echo    "  If -c were active it would reject any char other than 'z'."
echo    "  Since -R ignores -c, the default mechanism runs normally."
watch_note "timing out in 1 second..."
show_command "-R -t1 -dx -cz"
actual_out=$("$GRABCHARS" -R -t1 -dx -cz 2>/dev/null)
actual_exit=$?
check_output "$actual_out" "x" "stdout (default)"
check_exit   "$actual_exit" "1" && pass || fail "expected 'x' with exit 1 (-c ignored)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "single ASCII byte"
echo    "  -R -n1: read exactly one byte."
echo    "  Output: the byte typed. Exit code = 1."
instruct "Type the letter 'a'"
show_command "-R -n1"
echo
actual_out=$("$GRABCHARS" -R -n1 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "a" "stdout"
check_exit   "$actual_exit" "1" && pass || fail "expected 'a' with exit 1"

# ─────────────────────────────────────────────────────────────────────────────
test_start "three ASCII bytes"
echo    "  -R -n3: read exactly three bytes."
echo    "  Output: 'abc'. Exit code = 3."
instruct "Type exactly: 'a', 'b', 'c'"
show_command "-R -n3"
echo
actual_out=$("$GRABCHARS" -R -n3 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "abc" "stdout"
check_exit   "$actual_exit" "3" && pass || fail "expected 'abc' with exit 3"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-r flag: Enter exits early, bytes before Enter are returned"
echo    "  -R -n10 -r: collect up to 10 bytes. Enter exits without adding Enter byte."
echo    "  Type 'hi' then Enter — output 'hi', exit code 2."
instruct "Type 'h', 'i', then press Enter"
show_command "-R -n10 -r"
echo
actual_out=$("$GRABCHARS" -R -n10 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "hi" "stdout"
check_exit   "$actual_exit" "2" && pass || fail "expected 'hi' with exit 2"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-r flag: Enter immediately with no prior input"
echo    "  -R -n10 -r: pressing Enter immediately — zero bytes collected."
echo    "  Output: nothing. Exit code = 0."
instruct "Press Enter immediately without typing anything"
show_command "-R -n10 -r"
echo
actual_out=$("$GRABCHARS" -R -n10 -r 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (should be empty)"
check_exit   "$actual_exit" "0" && pass || fail "expected empty output and exit 0"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-r -d: Enter immediately returns default"
echo    "  -R -n10 -r -d hello: pressing Enter with no prior input returns the default."
echo    "  Output: 'hello'. Exit code = 5."
instruct "Press Enter immediately without typing anything"
show_command "-R -n10 -r -dhello"
echo
actual_out=$("$GRABCHARS" -R -n10 -r -dhello 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "hello" "stdout"
check_exit   "$actual_exit" "5" && pass || fail "expected 'hello' with exit 5"

# ─────────────────────────────────────────────────────────────────────────────
test_start "arrow key captured as 3 raw bytes"
echo    "  -R -n3: read exactly 3 bytes. An arrow key sends a 3-byte CSI sequence:"
echo    "  ESC (0x1b)  [  (0x5b)  A/B/C/D (0x41-0x44)"
echo    "  In normal mode these 3 bytes would be collapsed into one logical key."
echo    "  In raw mode all 3 bytes are stored. Exit code = 3."
echo    "  The test checks: exit code is 3, and the first byte is 0x1b (ESC)."
instruct "Press any arrow key (Up, Down, Left, or Right)"
show_command "-R -n3"
echo
_tmpf=$(mktemp)
"$GRABCHARS" -R -n3 2>/dev/tty > "$_tmpf"
actual_exit=$?
nbytes=$(wc -c < "$_tmpf")
first_byte=$(od -An -N1 -tx1 "$_tmpf" | tr -d ' \n')
rm -f "$_tmpf"
echo
ok=0
check_exit "$actual_exit" "3" || ok=1
if [[ "$first_byte" == "1b" ]]; then
    echo -e "  ${GREEN}✓${RESET} first byte is ESC (0x1b) — CSI sequence captured raw"
else
    echo -e "  ${RED}✗${RESET} first byte: got 0x${first_byte}, expected 0x1b (ESC)"
    ok=1
fi
[[ $ok -eq 0 ]] && pass || fail "exit code or first byte wrong"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-c filter silently ignored: char outside filter is accepted"
echo    "  -R -n1 -c z: in normal mode, only 'z' is accepted."
echo    "  In raw mode -c is ignored — any byte is accepted immediately."
echo    "  Type 'a'. If -c were active, 'a' would be rejected and grabchars"
echo    "  would keep waiting. In raw mode it returns 'a' right away."
instruct "Type the letter 'a'"
show_command "-R -n1 -cz"
echo
actual_out=$("$GRABCHARS" -R -n1 -cz 2>/dev/tty)
actual_exit=$?
echo
check_output "$actual_out" "a" "stdout"
check_exit   "$actual_exit" "1" && pass || fail "expected 'a' with exit 1 (-c should be ignored)"

# ─────────────────────────────────────────────────────────────────────────────
test_start "-s silent mode: exit code reflects bytes read, nothing output"
echo    "  -R -n3 -s: collect 3 bytes silently."
echo    "  Nothing on stdout. Exit code = 3."
instruct "Type any three characters: e.g. '1', '2', '3'"
show_command "-R -n3 -s"
echo
actual_out=$("$GRABCHARS" -R -n3 -s 2>/dev/null)
actual_exit=$?
echo
check_output "$actual_out" "" "stdout (silent — should be empty)"
check_exit   "$actual_exit" "3" && pass || fail "expected empty output and exit 3"

print_summary
