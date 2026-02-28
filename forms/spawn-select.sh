#!/bin/bash
# forms/spawn-select.sh — Spawn a grabchars selection menu in a new terminal window.
#
# Usage:
#   spawn-select.sh OPTIONS PROMPT [layout=v|h] [default] [timeout]
#
#   OPTIONS  Comma-separated list: "dev,staging,prod"
#   PROMPT   Prompt string shown above the menu
#   layout   v = vertical filter-as-you-type (default)
#            h = horizontal left/right selection
#   default  Pre-selected option (must be one of the OPTIONS values)
#   timeout  Seconds before auto-selecting the default (0 = no timeout)
#
# Returns JSON on stdout:
#   {"status":"selected","value":"staging"}
#   {"status":"cancelled"}              # user pressed Escape
#   {"status":"error","message":"..."}
#
# Exit code: 0 = got a selection, 1 = error
#
# Examples:
#   result=$(./spawn-select.sh "dev,staging,prod" "Deploy to:" v staging 30)
#   result=$(./spawn-select.sh "accept,reject,skip" "Code review:" h)

set -euo pipefail

OPTIONS="${1:?Usage: spawn-select.sh OPTIONS PROMPT [layout=v|h] [default] [timeout]}"
PROMPT="${2:?Usage: spawn-select.sh OPTIONS PROMPT [layout=v|h] [default] [timeout]}"
LAYOUT="${3:-v}"
DEFAULT="${4:-}"
TIMEOUT="${5:-0}"

if [[ "$LAYOUT" != "v" && "$LAYOUT" != "h" ]]; then
    printf '{"status":"error","message":"layout must be v or h"}\n'
    exit 1
fi

GRABCHARS=$(command -v grabchars 2>/dev/null) || {
    printf '{"status":"error","message":"grabchars not found in PATH"}\n'
    exit 1
}

OUTPUT_FILE=$(mktemp /tmp/gc-select-XXXXXX.json)
DONE_FILE="${OUTPUT_FILE}.done"
RUNNER=$(mktemp /tmp/gc-select-runner-XXXXXX.sh)

cleanup() {
    rm -f "$OUTPUT_FILE" "$DONE_FILE" "$RUNNER"
    if [[ -n "${WIN_ID:-}" ]]; then
        osascript << APPLEEOF 2>/dev/null || true
tell application "iTerm2"
    try
        close (windows whose id is $WIN_ID) saving no
    end try
end tell
APPLEEOF
    fi
}
trap cleanup EXIT

rm -f "$OUTPUT_FILE" "$DONE_FILE"

# Determine grabchars subcommand
if [[ "$LAYOUT" == "h" ]]; then
    SUBCMD="select-lr"
else
    SUBCMD="select"
fi

# Build optional flag strings (written into the runner as literals)
DEFAULT_FLAGS=""
[[ -n "$DEFAULT" ]] && DEFAULT_FLAGS="-d $(printf '%q' "$DEFAULT")"
TIMEOUT_FLAGS=""
[[ "$TIMEOUT" -gt 0 ]] && TIMEOUT_FLAGS="-t $(printf '%q' "$TIMEOUT")"

{
    printf '#!/bin/zsh -f\n'
    printf 'GRABCHARS=%s\n' "$(printf '%q' "$GRABCHARS")"
    printf 'OUTPUT=%s\n'    "$(printf '%q' "$OUTPUT_FILE")"
    printf 'DONE=%s\n'      "$(printf '%q' "$DONE_FILE")"
    printf 'SUBCMD=%s\n'    "$(printf '%q' "$SUBCMD")"
    printf 'OPTIONS=%s\n'   "$(printf '%q' "$OPTIONS")"
    printf 'PROMPT=%s\n'    "$(printf '%q' "$PROMPT")"
    printf 'DEFAULT_FLAGS=%s\n' "$(printf '%q' "$DEFAULT_FLAGS")"
    printf 'TIMEOUT_FLAGS=%s\n' "$(printf '%q' "$TIMEOUT_FLAGS")"
    cat << 'BODY'
# shellcheck disable=SC2086
RESULT=$("$GRABCHARS" "$SUBCMD" $DEFAULT_FLAGS $TIMEOUT_FLAGS -q "$PROMPT" "$OPTIONS")
EXIT=$?
if [ "$EXIT" -eq 255 ]; then
    printf '{"status":"cancelled"}' > "$OUTPUT"
else
    # Escape double quotes in result for JSON safety
    SAFE=$(printf '%s' "$RESULT" | sed 's/"/\\"/g')
    printf '{"status":"selected","value":"%s"}' "$SAFE" > "$OUTPUT"
fi
printf 'done' > "$DONE"
BODY
} > "$RUNNER"
chmod +x "$RUNNER"

ESC_RUNNER=$(printf '%s' "$RUNNER" | sed "s/'/'\\\\''/g")

WIN_ID=$(osascript << APPLEEOF
tell application "iTerm2"
    set newWin to (create window with default profile command "/bin/zsh -f '${ESC_RUNNER}'")
    tell current session of newWin
        set name to "📋 Select"
    end tell
    return id of newWin
end tell
APPLEEOF
) || {
    printf '{"status":"error","message":"failed to spawn iTerm2 window"}\n'
    exit 1
}

MAX_POLLS=$(( (TIMEOUT == 0 ? 300 : TIMEOUT + 15) * 5 ))
elapsed=0
while [[ ! -f "$DONE_FILE" ]]; do
    sleep 0.2
    elapsed=$(( elapsed + 1 ))
    if [[ $elapsed -gt $MAX_POLLS ]]; then
        printf '{"status":"error","message":"timed out waiting for window"}\n'
        exit 1
    fi
done

cat "$OUTPUT_FILE"
