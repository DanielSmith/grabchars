#!/bin/bash
# forms/spawn-decision.sh — Spawn a y/n grabchars prompt in a new terminal window.
#
# Usage:
#   spawn-decision.sh PROMPT [default=n] [timeout=30]
#
# Returns JSON on stdout:
#   {"status":"y","timed_out":false}
#   {"status":"n","timed_out":true}    # user let timer expire (default applied)
#   {"status":"cancelled"}             # user pressed Escape
#   {"status":"error","message":"..."}
#
# Exit code: 0 = got an answer, 1 = error
#
# Example:
#   result=$(./spawn-decision.sh "Deploy to production?" n 15)
#   val=$(echo "$result" | jq -r '.status')

set -euo pipefail

PROMPT="${1:?Usage: spawn-decision.sh PROMPT [default=n] [timeout=30]}"
DEFAULT="${2:-n}"
TIMEOUT="${3:-30}"

# Validate DEFAULT
if [[ "$DEFAULT" != "y" && "$DEFAULT" != "n" ]]; then
    printf '{"status":"error","message":"default must be y or n"}\n'
    exit 1
fi

# Resolve grabchars while we still have the caller's PATH
GRABCHARS=$(command -v grabchars 2>/dev/null) || {
    printf '{"status":"error","message":"grabchars not found in PATH"}\n'
    exit 1
}

OUTPUT_FILE=$(mktemp /tmp/gc-decision-XXXXXX.json)
DONE_FILE="${OUTPUT_FILE}.done"
RUNNER=$(mktemp /tmp/gc-decision-runner-XXXXXX.sh)

# Cleanup on any exit
cleanup() {
    rm -f "$OUTPUT_FILE" "$DONE_FILE" "$RUNNER"
    # Close the iTerm2 window if we recorded its ID
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

# Build display prompt — show which option is the default and the timeout
if [[ "$DEFAULT" == "y" ]]; then
    DISPLAY_PROMPT="${PROMPT} [Y/n, ${TIMEOUT}s]: "
else
    DISPLAY_PROMPT="${PROMPT} [y/N, ${TIMEOUT}s]: "
fi

# Write the runner script — variable assignments use printf %q for safe quoting;
# the body is a literal heredoc (no variable expansion inside 'BODY').
{
    printf '#!/bin/zsh -f\n'
    printf 'GRABCHARS=%s\n' "$(printf '%q' "$GRABCHARS")"
    printf 'OUTPUT=%s\n'    "$(printf '%q' "$OUTPUT_FILE")"
    printf 'DONE=%s\n'      "$(printf '%q' "$DONE_FILE")"
    printf 'PROMPT=%s\n'    "$(printf '%q' "$DISPLAY_PROMPT")"
    printf 'DEFAULT=%s\n'   "$(printf '%q' "$DEFAULT")"
    printf 'TIMEOUT=%s\n'   "$(printf '%q' "$TIMEOUT")"
    cat << 'BODY'
RESULT=$("$GRABCHARS" -c yn -d "$DEFAULT" -t "$TIMEOUT" -b -q "$PROMPT")
EXIT=$?
if [ "$EXIT" -eq 255 ]; then
    printf '{"status":"cancelled"}' > "$OUTPUT"
else
    TIMED_OUT="false"
    [ "$EXIT" -eq 254 ] && TIMED_OUT="true"
    printf '{"status":"%s","timed_out":%s}' "$RESULT" "$TIMED_OUT" > "$OUTPUT"
fi
printf 'done' > "$DONE"
BODY
} > "$RUNNER"
chmod +x "$RUNNER"

# Escape runner path for AppleScript (handles spaces and special chars)
ESC_RUNNER=$(printf '%s' "$RUNNER" | sed "s/'/'\\\\''/g")

# Spawn iTerm2 window with minimal zsh (no rc files) running the runner
WIN_ID=$(osascript << APPLEEOF
tell application "iTerm2"
    set newWin to (create window with default profile command "/bin/zsh -f '${ESC_RUNNER}'")
    tell current session of newWin
        set name to "❓ Decision"
    end tell
    return id of newWin
end tell
APPLEEOF
) || {
    printf '{"status":"error","message":"failed to spawn iTerm2 window"}\n'
    exit 1
}

# Poll for completion — cap at timeout + 15 seconds
MAX_POLLS=$(( (TIMEOUT + 15) * 5 ))
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
