#!/usr/bin/env bash
# menu.sh - Interactive test selector for grabchars
#
# Uses grabchars itself to pick which test group to run.
# Run from any directory: bash tests/menu.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
_check_binary

# ── Build the option list ──────────────────────────────────────────────────────
# "all" plus each numbered test file, comma-separated for grabchars select-lr.

options="all"
for f in "$SCRIPT_DIR"/[0-9][0-9]_*.sh; do
    [[ -f "$f" ]] || continue
    options="$options,$(basename "$f" .sh)"
done

# ── Header ────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}grabchars test suite${RESET}"
echo -e "${DIM}Using grabchars to navigate — appropriately meta.${RESET}"
echo
echo -e "${DIM}← → to navigate · type to jump · Enter to run · Esc to quit${RESET}"
echo

# ── Show the menu using grabchars select-lr ───────────────────────────────────
choice=$("$GRABCHARS" select-lr "$options" 2>/dev/tty)
exit_code=$?
echo

if [[ $exit_code -eq 255 || -z "$choice" ]]; then
    echo -e "${DIM}No selection — exiting.${RESET}"
    echo
    exit 0
fi

# ── Run the selected tests ─────────────────────────────────────────────────────
if [[ "$choice" == "all" ]]; then
    bash "$SCRIPT_DIR/run_tests.sh"
else
    # Extract numeric prefix: "01_basic" → "01"
    prefix="${choice%%_*}"
    bash "$SCRIPT_DIR/run_tests.sh" "$prefix"
fi
