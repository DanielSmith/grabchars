#!/usr/bin/env bash
# run_tests.sh - Master test runner for grabchars 2.0
#
# Usage:
#   ./run_tests.sh              # run all test files
#   ./run_tests.sh 01 05 09     # run specific test files by number prefix
#   ./run_tests.sh --list       # show available test files

# no set -e: test scripts may exit non-zero on failures, that's expected

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# ── Binary check ──────────────────────────────────────────────────────────────
_check_binary

# ── Argument handling ─────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
    echo "Available test files:"
    for f in "$SCRIPT_DIR"/[0-9][0-9]_*.sh; do
        name=$(basename "$f" .sh)
        echo "  $name"
    done
    exit 0
fi

# Collect test files to run
if [[ $# -gt 0 ]]; then
    test_files=()
    for prefix in "$@"; do
        matches=("$SCRIPT_DIR/${prefix}"_*.sh)
        if [[ ${#matches[@]} -eq 0 || ! -e "${matches[0]}" ]]; then
            echo "Warning: no test file matching '${prefix}_*.sh'" >&2
        else
            test_files+=("${matches[@]}")
        fi
    done
else
    test_files=("$SCRIPT_DIR"/[0-9][0-9]_*.sh)
fi

if [[ ${#test_files[@]} -eq 0 ]]; then
    echo "No test files found." >&2
    exit 1
fi

# ── Header ────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}grabchars 2.0 — interactive test suite${RESET}"
echo -e "${DIM}Binary: $GRABCHARS${RESET}"
echo -e "${DIM}Date:   $(date)${RESET}"

# ── Run each test file as a subprocess, accumulate totals ─────────────────────
TOTAL_RUN=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

for test_file in "${test_files[@]}"; do
    [[ -f "$test_file" ]] || continue

    label=$(basename "$test_file" .sh)
    echo
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  Running: $label${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Run the test file, tee output to a temp file for count extraction.
    # print_summary emits a GRABCHARS_TOTALS line with plain numbers (no colors).
    tmpout=$(mktemp)
    bash "$test_file" | tee "$tmpout"

    # Parse the machine-readable totals line emitted by print_summary
    totals_line=$(grep "^GRABCHARS_TOTALS " "$tmpout" | tail -1)
    read -r _ run passed failed skipped <<< "$totals_line"

    TOTAL_RUN=$((TOTAL_RUN + ${run:-0}))
    TOTAL_PASSED=$((TOTAL_PASSED + ${passed:-0}))
    TOTAL_FAILED=$((TOTAL_FAILED + ${failed:-0}))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + ${skipped:-0}))

    rm -f "$tmpout"

    # Pause between test files so the user can read results
    echo
    echo -e "${DIM}  ↵ Press Enter to continue to next test file...${RESET}"
    read -r -s
done

# ── Grand summary ─────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  GRAND TOTAL${RESET}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Tests run:    $TOTAL_RUN"
echo -e "  ${GREEN}Passed:       $TOTAL_PASSED${RESET}"
if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed:       $TOTAL_FAILED${RESET}"
else
    echo -e "  Failed:       $TOTAL_FAILED"
fi
[[ $TOTAL_SKIPPED -gt 0 ]] && echo -e "  ${DIM}Skipped:      $TOTAL_SKIPPED${RESET}"
echo

if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD}$TOTAL_FAILED test(s) failed.${RESET}"
    exit 1
fi
