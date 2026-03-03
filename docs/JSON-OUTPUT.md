# grabchars JSON Output (`-J`)

## Overview

By default grabchars writes the captured value to stdout and the exit code
is available via `$?`. That is sufficient for simple scripts, but composing
multiple grabchars calls, handling every exit condition, and routing results
through pipelines requires repetitive boilerplate.

`-J` replaces the normal value output with a single JSON object containing
the captured value, exit code, status, and all contextual metadata a script
needs. It is one or the other — you get JSON or you get raw text, never
both at the same time. The exit code (`$?`) is always identical to the
`exit` field in the JSON object.

---

## Flag Syntax

| Flag | Behavior |
|------|----------|
| `-J` or `-J1` | Compact JSON on stdout (single line) |
| `-Jp` | Pretty-printed JSON (indented, for debugging or `jq` piping) |
| `-J0` | Explicit off — normal behavior (default) |

Compact is the right choice for `$()` capture in scripts. Pretty-print is
useful when developing or inspecting output interactively.

---

## Output Fields

All fields are always present. Fields that are not applicable to the current
mode carry a null or zero value rather than being omitted — this makes
consumption uniform regardless of mode.

| Field | Type | Description |
|-------|------|-------------|
| `value` | string | The captured text (what stdout normally contains) |
| `exit` | integer | The exit code — identical to `$?` |
| `status` | string | Human-readable interpretation of the exit (see below) |
| `mode` | string | Which mode was active (see below) |
| `timed_out` | boolean | Whether the timeout fired |
| `default_used` | boolean | Whether the default value (`-d`) was returned |
| `index` | integer \| null | 0-based position of chosen option in select modes; `null` otherwise |
| `filter` | string \| null | Text the user typed in the filter field before confirming (select modes only); `null` otherwise |

### `status` values

| Value | Meaning |
|-------|---------|
| `"ok"` | Normal input captured |
| `"default"` | Default value returned — user pressed Enter with no input, or timeout fired with `-d` set |
| `"timeout"` | Timed out with no default set (exit 254) |
| `"cancelled"` | ESC pressed (exit 255 or `-B<n>`) |
| `"error"` | Argument or runtime error — in practice this will not appear in JSON output since errors during arg parsing exit before JSON mode is active |

### `mode` values

| Value | When |
|-------|------|
| `"normal"` | Standard character capture |
| `"mask"` | Mask mode (`-m`) |
| `"select"` | Vertical select menu |
| `"select-lr"` | Horizontal select menu |
| `"raw"` | Raw byte mode (`-R`) |

---

## Examples

### Normal capture

```bash
result=$(grabchars -J -cy -q "y/n: " 2>/dev/tty)
```

User types `y`:
```json
{"value":"y","exit":1,"status":"ok","mode":"normal","timed_out":false,"default_used":false,"index":null,"filter":null}
```

### Default returned on Enter

```bash
result=$(grabchars -J -cy -d y -q "Continue? [Y/n] " 2>/dev/tty)
```

User presses Enter:
```json
{"value":"y","exit":1,"status":"default","mode":"normal","timed_out":false,"default_used":true,"index":null,"filter":null}
```

### Timeout with default

```bash
result=$(grabchars -J select "yes,no,cancel" -d yes -t 5 -q "Choose (5s): " 2>/dev/tty)
```

Timer fires with no input:
```json
{"value":"yes","exit":0,"status":"default","mode":"select","timed_out":true,"default_used":true,"index":0,"filter":""}
```

### Timeout without default

```bash
result=$(grabchars -J -n 10 -r -t 5 -q "Type something (5s): " 2>/dev/tty)
```

Timer fires:
```json
{"value":"","exit":254,"status":"timeout","mode":"normal","timed_out":true,"default_used":false,"index":null,"filter":null}
```

### ESC cancelled (default, no `-B`)

```bash
result=$(grabchars -J select "yes,no,cancel" -q "Choose: " 2>/dev/tty)
```

User presses ESC:
```json
{"value":"","exit":255,"status":"cancelled","mode":"select","timed_out":false,"default_used":false,"index":null,"filter":null}
```

### ESC with `-B<n>`

```bash
result=$(grabchars -J select "yes,no,cancel" -B100 -q "Choose: " 2>/dev/tty)
```

User presses ESC:
```json
{"value":"","exit":100,"status":"cancelled","mode":"select","timed_out":false,"default_used":false,"index":null,"filter":null}
```

### Select with filter text

```bash
result=$(grabchars -J select "san francisco,santa maria,san jose,san diego" -q "City: " 2>/dev/tty)
```

User types `san j`, presses Enter to select `san jose`:
```json
{"value":"san jose","exit":2,"status":"ok","mode":"select","timed_out":false,"default_used":false,"index":2,"filter":"san j"}
```

### Mask mode

```bash
result=$(grabchars -J -m "(nnn) nnn-nnnn" -q "Phone: " 2>/dev/tty)
```

User types `2125551212`:
```json
{"value":"(212) 555-1212","exit":10,"status":"ok","mode":"mask","timed_out":false,"default_used":false,"index":null,"filter":null}
```

### Pretty-print (for debugging or interactive use)

```bash
grabchars -Jp select "yes,no,cancel" -q "Choose: " 2>/dev/tty
```

```json
{
  "value": "no",
  "exit": 1,
  "status": "ok",
  "mode": "select",
  "timed_out": false,
  "default_used": false,
  "index": 1,
  "filter": "n"
}
```

---

## Consuming with `jq`

```bash
result=$(grabchars -J select "deploy,rollback,quit" -B100 -q "Action: " 2>/dev/tty)

value=$(echo "$result"  | jq -r '.value')
status=$(echo "$result" | jq -r '.status')
index=$(echo "$result"  | jq -r '.index')

case "$status" in
    ok)        echo "Selected: $value (position $index)" ;;
    default)   echo "Defaulted to: $value" ;;
    timeout)   echo "Timed out" ;;
    cancelled) echo "Cancelled via ESC" ;;
esac
```

---

## Raw Mode and Binary Values

In raw mode (`-R`), the captured bytes may not be valid UTF-8. Arrow keys
produce byte sequences like `0x1B 0x5B 0x41`. JSON strings must be valid
UTF-8.

`value` in raw mode is hex-encoded: each byte is two lowercase hex digits,
space-separated.

```bash
grabchars -J -R -n 3 -q "Press an arrow key: " 2>/dev/tty
```

Up arrow:
```json
{"value":"1b 5b 41","exit":3,"status":"ok","mode":"raw","timed_out":false,"default_used":false,"index":null,"filter":null}
```

Scripts consuming raw mode JSON should decode the hex rather than using
`value` directly.

---

## Interaction with Other Flags

### `-s` (silent)

Silent mode suppresses on-screen echo and normal stdout output. With `-J`,
the JSON object is still written to stdout — that is the point of `-J`. The
silent flag's effect (no echo during typing) is preserved; only the final
JSON emission is added.

### `-e` / `-b` (output routing)

`-J` replaces the normal value output with JSON. The `-e` and `-b` flags
control where that JSON lands, exactly as they control where raw text lands
today — `-e` sends it to stderr, `-b` sends it to both. There is no mode
that emits both raw text and JSON simultaneously; it is one or the other.

### `-q` / `-p` (prompts)

Prompts still go to stderr (`-q`) or stdout (`-p`). With `-J` and `$()`
capture, use `-q` as usual so the prompt remains visible and is not captured
along with the JSON.

---

## Implementation Notes

The JSON object is emitted at every exit point that currently writes to
stdout — the same locations that call `output::output_str`, `output::output_char`,
`output::handle_default`, and `output::output_bytes`. A central
`output::emit_json()` function takes a `JsonPayload` struct and writes either
compact or pretty form to stdout.

`JsonPayload` fields map directly to the output fields above. Each exit path
in `main.rs`, `mask.rs`, and `select.rs` constructs a `JsonPayload` and
passes it to `emit_json()` instead of calling the individual output functions.

The `Flags` struct gains:

```rust
pub enum JsonStyle { Compact, Pretty }
pub json: Option<JsonStyle>, // None = off (default)
```

No external JSON crate is needed — the output is a flat object with known
field types (string, integer, boolean, integer-or-null, string-or-null).
A hand-written emitter is straightforward and keeps the dependency count at
zero.

---

## What Is Not Included

**Timing information** — how long the user took to respond. Adds complexity,
rarely useful in practice. Scripts that care about timing can wrap grabchars
with `time`.

**Input history** — what keystrokes were pressed. Not a concern for script
consumption; the value is what matters.

**Grabchars version** — useful for scripts that need to check compatibility,
but better handled by `grabchars --version` as a separate call.
