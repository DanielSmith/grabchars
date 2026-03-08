# grabchars — Release Notes

---

## 2.1

### JSON output (`-J`) — new

`-J` replaces normal stdout output with a single JSON object containing the
captured value, exit code, status, and contextual metadata. Works in all modes.

| Flag | Behavior |
|------|----------|
| `-J` or `-J1` | Compact JSON on stdout (single line) |
| `-Jp` | Pretty-printed JSON (indented) |
| `-J0` | Explicit off — normal behavior (default) |

Output fields (always present):

| Field | Type | Description |
|-------|------|-------------|
| `value` | string | The captured text |
| `exit` | integer | Exit code (identical to `$?`) |
| `status` | string | `"ok"`, `"default"`, `"timeout"`, or `"cancelled"` |
| `mode` | string | `"normal"`, `"mask"`, `"select"`, `"select-lr"`, or `"raw"` |
| `timed_out` | boolean | Whether the timeout fired |
| `default_used` | boolean | Whether the default value was returned |
| `index` | int\|null | 0-based index of selected option (select modes only) |
| `filter` | string\|null | Filter text typed before confirming (select modes only) |

```bash
result=$(grabchars -J select "yes,no,cancel" -B100 -q "Action: " 2>/dev/tty)
status=$(echo "$result" | jq -r '.status')
value=$(echo "$result"  | jq -r '.value')

case "$status" in
    ok)        echo "Selected: $value" ;;
    default)   echo "Defaulted to: $value" ;;
    timeout)   echo "Timed out" ;;
    cancelled) echo "Cancelled via ESC" ;;
esac
```

In raw mode (`-R`), the `value` field is hex-encoded (space-separated bytes)
since raw captures may not be valid UTF-8.

No external JSON crate — the emitter is hand-written to keep zero dependencies.
See `docs/JSON-OUTPUT.md` for the full specification and examples.

### Filter styles for select modes (`-F`) — new

Both `select` and `select-lr` now support three filter styles via `-F`:

| Flag | Style | Behavior |
|------|-------|----------|
| `-Fp` | Prefix | Only options that start with the typed text match (default) |
| `-Ff` | Fuzzy | Typed characters must appear in order, with anything between (subsequence) |
| `-Fc` | Contains | Typed text must appear anywhere as a contiguous substring |

```bash
grabchars select-lr -Ff "san francisco,santa maria,san jose,san luis obispo"
# Type 'sl' → only 'san luis obispo' has 'l' after 's' → immediate match

grabchars select -Fc "new haven,new york,newest first,renew annually"
# Type 'ork' → only 'new york' contains that substring
```

The default (`-Fp`) preserves the 2.0 behavior exactly — no change for existing scripts.

### ESC bail flag (`-B<n>`) — new

Controls what happens when the user presses Escape.

| Flag | Behavior |
|------|----------|
| *(none)* | Current behavior — ESC exits 255 in mask/select, no-op in normal mode |
| `-B0` | ESC is a no-op in all modes (kiosk/embedded use) |
| `-B1`–`-B253` | ESC exits with code *n* |
| `-B255` | ESC exits 255 explicitly (same as default for mask/select) |

`-B254` is disallowed — 254 is already the timeout-with-no-default exit code.

This lets scripts distinguish "user pressed ESC" from "bad invocation" for the
first time:

```bash
CHOICE=$(grabchars select "yes,no,cancel" -B200 -q "Continue? ")
case $? in
    0)   echo "Selected: yes" ;;
    1)   echo "Selected: no" ;;
    2)   echo "Selected: cancel" ;;
    200) echo "User pressed ESC" ;;
    255) echo "Error invoking grabchars" ;;
esac
```

**Note:** `-B0` in select modes disables the only in-band cancel key. The user
must Ctrl+C to exit, which restores the terminal less cleanly. Document this
in scripts that use it.

### Flush flag (`-f`) — now documented

The `-f` flag flushes any type-ahead input from the terminal buffer before
reading. This was present in the original 1988 code and carried into 2.0,
but was never documented. It prevents stale keystrokes (from fast typing or
pasted text that arrived before the prompt) from being read as input.

```bash
grabchars -f -c yn -q "Are you sure? [y/n] "
```

### Bug fix: whitespace in comma-separated option lists

Options passed as a single comma-separated string were not trimmed before
matching. An option like `"san francisco, santa maria"` (note the space after
the comma) produced an item `" santa maria"` with a leading space — which
never matched any filter input. Options are now trimmed consistently.

### Security: async-signal-safe terminal restore

The saved terminal state (used to restore the terminal from signal handlers)
was previously stored behind a `Mutex`. A `Mutex` is not async-signal-safe
under POSIX: if a signal arrived during the brief window when `init_term()`
held the lock, the signal handler's attempt to acquire the same lock would
deadlock.

The storage is now a `MaybeUninit<termios>` written exactly once before
signals are registered, guarded by an `AtomicBool` flag. No lock is taken
in the signal handler path.

### Robustness: clear error when stdin is not a terminal

Invoking grabchars with stdin redirected from a pipe or file previously
produced no output and exited 0 — silently broken. grabchars now detects
this at startup and exits 255 with a diagnostic:

```
grabchars: stdin is not a terminal
```

This does not affect normal use. PTYs (SSH, tmux, screen, Docker) pass the
check identically to physical terminals.

---

## 2.0 — The rewrite

### The short version

grabchars was written in 1988 and posted to `comp.sources.misc`. It was
never properly finished. This is the finished version.

I am the original author. You may have come across grabchars in the
O'Reilly book "Unix Power Tools".

---

### What the 1988 version was

The original C code (~665 lines across four files) read raw keystrokes from
the terminal for use in shell scripts. The core idea was right: shell scripts
need a way to grab a single character, or a fixed number of characters, or
a character from a specific set — without requiring Enter, without the full
weight of readline, and with the exit code carrying the character count so
scripts could branch on it directly.

But the execution had real problems:

- **BSD-only.** The terminal API was `sgtty.h` — a BSD interface that was
  already being superseded by SysV `termio.h` in 1988. It never worked
  correctly on most Unix systems of the time, let alone modern ones.

- **No line editing.** Multi-character input had no cursor movement, no
  backspace-to-edit, no way to fix a mistake without starting over. `-E`
  (erase mode) was a minimal backspace-only feature that was unreliable.

- **Portability rot.** K&R function syntax, `re_comp()`/`re_exec()` for
  regex (long deprecated), signal conventions that varied unpredictably
  across platforms. The code stopped compiling on modern systems decades ago.

- **Neglected.** Posted to Usenet and left. The problems were known but
  never addressed.

---

### What 2.0 fixes and what it adds

#### Portability — fixed

The terminal layer is rewritten on POSIX `termios`, which works correctly
on Linux, macOS, and WSL. There is one code path, not two. The original's
BSD/SysV split is gone entirely.

Signal handling is also corrected. The timeout mechanism (`-t`) uses
`sigaction` with `sa_flags=0` instead of `signal()`. On macOS, `signal()`
sets `SA_RESTART` by default, which causes `read()` to silently resume
after SIGALRM fires — the timeout never triggers. This was a latent bug
in the original that would have broken `-t` on macOS. It is fixed from
the start in 2.0.

#### CLI compatibility — preserved

Every flag the 1988 version had works identically in 2.0. Shell scripts
written for the original run unchanged: `-c`, `-C`, `-d`, `-e`, `-b`,
`-f`, `-n`, `-p`, `-q`, `-r`, `-s`, `-t`, `-U`, `-L`. The exit-code
convention (exit status = number of characters read) is unchanged.

#### Line editing — done properly

Multi-character input (`-n > 1`) now has full line editing, auto-enabled
by default. Left/Right arrow keys move the cursor within the buffer.
Home/End jump to start and end. Delete removes the character ahead of
the cursor. Backspace removes the character behind it.

Emacs keybindings work throughout:

| Key | Action |
|-----|--------|
| Ctrl-A / Ctrl-E | Beginning / end of line |
| Ctrl-F / Ctrl-B | Forward / backward one character |
| Ctrl-D | Delete character at cursor |
| Ctrl-K | Kill to end of line |
| Ctrl-U | Kill to beginning of line |
| Ctrl-W | Kill word backward |

Kill commands track the character budget correctly — with `-n 20` you can
type 20 characters, kill 10 with Ctrl-K, and type 10 more. Editing can be
forced on with `-E` or off with `-E0`.

#### Mask mode (`-m`) — new

Positional input validation with auto-inserted literals. The mask string
defines a pattern; grabchars enforces it character by character and inserts
literal separators automatically.

```bash
grabchars -m "(nnn) nnn-nnnn"   # phone: (212) 555-1212
grabchars -m "nn/nn/nnnn"       # date:  01/15/2026
grabchars -m "UUU-nnnnnn"       # serial: ABC-001234
grabchars -m "#xxxxxx"          # hex color: #a3f0c2
```

Character classes: `U` uppercase, `l` lowercase, `c` any letter, `n` digit,
`x` hex, `p` punctuation, `.` any character, `[...]` custom class.
Quantifiers (`*`, `+`, `?`) allow variable-length fields.

#### Selection menus — new

Two interactive selection modes for choosing from a list of options.

**Vertical select** (`grabchars select`) — filter-as-you-type with Up/Down
navigation. Type to narrow the list; arrow keys to cycle; Enter to confirm.

**Horizontal select (left-right)** (`grabchars select-lr`) — all matching options on one
line, Left/Right to move between them. Three highlight styles: reverse video
(default), bracket (`[option]`), or arrow (`>option<`).

Both modes support defaults (`-d`), timeouts (`-t`), and output routing.
Exit code is the zero-based position of the selected option in the original
list.

#### Raw mode (`-R`) — new

Bypasses the escape sequence parser entirely. Every byte arriving from the
terminal is captured as-is — an arrow key is three bytes (`1b 5b 41`), not
one logical `Left` event. `-n` counts bytes.

Useful for: discovering what byte sequence a key actually sends, building
key-binding capture tools, forwarding input to programs that do their own
terminal interpretation.

```bash
# Capture an arrow key — 3 bytes, exit code 3
grabchars -R -n3 -q "Press arrow key: "

# Show exactly what bytes a key sends
grabchars -R -n6 -q "Press a key: " | xxd
```

#### Trailing newline control (`-Z`) — new

After output completes, a newline is written to stderr so the shell prompt
appears on a new line. This is on by default. `-Z0` suppresses it for cases
where grabchars output is embedded in a larger line of terminal output.

---

### What grabchars is not

It is a script primitive, not an interactive tool. It belongs in the same
category as `tput`, `stty`, and `printf` — things shell scripts call, not
things people type at a prompt. The user experience is: a script runs, a
prompt appears, the user presses something, and the script continues. The
user never sees the grabchars command itself.

This shapes every design decision: no configuration file, no color themes,
no plugin system. The interface is the command line. The documentation is
the cookbook.

---

### Compatibility

- **OS:** Linux, macOS, WSL. Any POSIX-compliant system with a real TTY.
- **Rust:** 1.85 or later (edition 2024).
- **Original CLI:** Fully preserved. Scripts written for the 1988 version
  (should) work without modification.  I have not extensively tested that,
  and I would think there are few scripts out there from the 80's (but
  I could be wrong ;)
