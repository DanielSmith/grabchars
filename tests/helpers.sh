#!/usr/bin/env bash
# helpers.sh - shared utilities for grabchars interactive test suite

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Binary location ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRABCHARS="${GRABCHARS:-$SCRIPT_DIR/../target/release/grabchars}"

# ── Test tracking ─────────────────────────────────────────────────────────────
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ── Internal helpers ──────────────────────────────────────────────────────────

_check_binary() {
    if [[ ! -x "$GRABCHARS" ]]; then
        echo -e "${RED}ERROR: grabchars binary not found at: $GRABCHARS${RESET}"
        echo -e "${DIM}Run: cargo build --release${RESET}"
        exit 1
    fi
}

_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"
}

# ── Test lifecycle ────────────────────────────────────────────────────────────

# test_section "Section Title"
test_section() {
    echo
    echo -e "${BOLD}${CYAN}══ $1 ══${RESET}"
}

# test_start "description of this test"
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    _separator
    echo -e "${BOLD}Test $TESTS_RUN: $1${RESET}"
}

# instruct "what the user should type or do"
instruct() {
    echo -e "${YELLOW}  ➤  $1${RESET}"
}

# show_command "args..." — display the grabchars command about to be run
show_command() {
    echo -e "${DIM}running:${RESET}"
    echo -e "${CYAN}grabchars $*${RESET}"
}

# watch_note "what will happen automatically"
watch_note() {
    echo -e "${DIM}  (${1})${RESET}"
}

# pass [optional note]
pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    if [[ -n "$1" ]]; then
        echo -e "  ${GREEN}✓ PASS${RESET}  $1"
    else
        echo -e "  ${GREEN}✓ PASS${RESET}"
    fi
}

# fail "reason"
fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗ FAIL${RESET}  $1"
}

# skip "reason"
skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "  ${DIM}⊘ SKIP  $1${RESET}"
}

# ── Result checking ───────────────────────────────────────────────────────────

# check_exit ACTUAL EXPECTED [label]
check_exit() {
    local actual="$1"
    local expected="$2"
    local label="${3:-exit code}"
    if [[ "$actual" == "$expected" ]]; then
        echo -e "  ${GREEN}✓${RESET} $label: $actual (expected $expected)"
        return 0
    else
        echo -e "  ${RED}✗${RESET} $label: got $actual, expected $expected"
        return 1
    fi
}

# check_output ACTUAL EXPECTED [label]
check_output() {
    local actual="$1"
    local expected="$2"
    local label="${3:-output}"
    if [[ "$actual" == "$expected" ]]; then
        echo -e "  ${GREEN}✓${RESET} $label: \"$actual\" (expected \"$expected\")"
        return 0
    else
        echo -e "  ${RED}✗${RESET} $label: got \"$actual\", expected \"$expected\""
        return 1
    fi
}

# check_output_contains ACTUAL SUBSTRING [label]
check_output_contains() {
    local actual="$1"
    local substring="$2"
    local label="${3:-output}"
    if [[ "$actual" == *"$substring"* ]]; then
        echo -e "  ${GREEN}✓${RESET} $label contains \"$substring\""
        return 0
    else
        echo -e "  ${RED}✗${RESET} $label: \"$actual\" does not contain \"$substring\""
        return 1
    fi
}

# run_and_check - run grabchars, capture stdout, check exit and output
# Usage: run_and_check EXPECTED_OUTPUT EXPECTED_EXIT -- [grabchars args...]
#   Prints results. Returns 0 if both match.
run_and_check() {
    local expected_out="$1"
    local expected_exit="$2"
    shift 2
    # consume the '--' separator if present
    [[ "$1" == "--" ]] && shift

    local actual_out
    actual_out=$("$GRABCHARS" "$@" 2>/dev/null)
    local actual_exit=$?

    local ok=0
    check_output "$actual_out" "$expected_out" "stdout" || ok=1
    check_exit   "$actual_exit" "$expected_exit" "exit"  || ok=1
    return $ok
}

# ── Summary ───────────────────────────────────────────────────────────────────

print_summary() {
    echo
    _separator
    echo -e "${BOLD}Results${RESET}"
    echo -e "  Run:     $TESTS_RUN"
    echo -e "  ${GREEN}Passed:  $TESTS_PASSED${RESET}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${RED}Failed:  $TESTS_FAILED${RESET}"
    else
        echo -e "  Failed:  $TESTS_FAILED"
    fi
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "  ${DIM}Skipped: $TESTS_SKIPPED${RESET}"
    fi
    _separator

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
    else
        echo -e "${RED}${BOLD}$TESTS_FAILED test(s) failed.${RESET}"
    fi
    echo
    # Machine-readable line for the master runner to parse (no color codes)
    echo "GRABCHARS_TOTALS $TESTS_RUN $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED"
}

# Accumulate counts from a sub-script into parent totals
# Usage: accumulate_from SUB_TESTS_RUN SUB_PASSED SUB_FAILED SUB_SKIPPED
accumulate_from() {
    TESTS_RUN=$((TESTS_RUN + $1))
    TESTS_PASSED=$((TESTS_PASSED + $2))
    TESTS_FAILED=$((TESTS_FAILED + $3))
    TESTS_SKIPPED=$((TESTS_SKIPPED + $4))
}

# ── Pause helpers ─────────────────────────────────────────────────────────────

# press_any_key - wait for user to acknowledge before continuing
press_any_key() {
    echo -e "${DIM}  Press any key to continue...${RESET}"
    read -r -s -n1
}

# countdown N "message"
countdown() {
    local n="$1"
    local msg="${2:-Waiting}"
    for ((i=n; i>0; i--)); do
        printf "\r${DIM}  %s... %d ${RESET}" "$msg" "$i"
        sleep 1
    done
    printf "\r%*s\r" 40 ""   # clear the line
}
