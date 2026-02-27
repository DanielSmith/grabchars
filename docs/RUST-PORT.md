# Grabchars: Rust Port Notes

Original author: Dan Smith, 1988-1990 (`daniel@island.uu.net`)
Rust port: February 2026

---

## What Is Grabchars?

`grabchars` reads one or more keystrokes directly from the terminal without
requiring Enter. Written in 1988 and posted to `comp.sources.misc`, it provides
features that bash/zsh `read` still lack: character filtering (`-c`), default
values on timeout or Enter (`-d`), case mapping (`-U`/`-L`), output routing
(`-e`/`-b`), and exit status set to the character count.

The original C code (~665 lines across 4 files) no longer compiles on modern
systems due to K&R function syntax, missing headers, BSD-only terminal APIs
(`sgtty.h`), deprecated regex functions (`re_comp`/`re_exec`), and old signal
handler conventions.

The Rust port is a complete rewrite that preserves exact CLI compatibility with
the original while adding line editing, arrow key navigation, Emacs keybindings,
and a proper POSIX signal architecture.

---

## Current Feature Set

The Rust port now includes all original grabchars functionality plus significant
new capabilities:

### Original features (fully ported)
- **Single-keystroke capture** -- grab exactly 1 key without Enter
- **Multi-character input** (`-n`) -- grab exactly N keystrokes
- **Character filtering** (`-c`) -- only accept specified characters (regex)
- **Default values** (`-d`) -- return a default on Enter or timeout
- **Timeout** (`-t`) -- alarm-based timeout with SIGALRM
- **Case mapping** (`-U`/`-L`) -- force upper or lowercase on input
- **Output routing** (`-e`/`-b`) -- stdout, stderr, or both
- **Silent mode** (`-s`) -- no echo, exit status only
- **Prompt** (`-p`/`-q`) -- prompt to stdout or stderr
- **Return key exits** (`-r`) -- Enter breaks early (with `-n`)
- **Input flush** (`-f`) -- flush type-ahead before reading
- **Exit status = character count** -- for shell `$?` testing

### New in the Rust port
- **Line editing** (`-E`) -- auto-enabled for `-n > 1`
- **Arrow key navigation** -- Left/Right cursor movement within the buffer
- **Home/End keys** -- jump to start/end of input
- **Forward delete** -- Delete key removes character ahead of cursor
- **Emacs keybindings** -- Ctrl-A/E/F/B/D/K/U/W (see below)
- **Trailing newline control** (`-Z`) -- suppress the final newline to stderr
- **Escape sequence consumption** -- arrow keys in non-edit mode are silently
  ignored instead of dumping `^[[C` garbage

### Emacs keybindings (active when editing is enabled)

| Key | Action |
|-----|--------|
| Ctrl-A | Beginning of line (Home) |
| Ctrl-E | End of line (End) |
| Ctrl-F | Forward one character (Right) |
| Ctrl-B | Backward one character (Left) |
| Ctrl-D | Delete character at cursor (forward delete) |
| Ctrl-K | Kill to end of line |
| Ctrl-U | Kill to beginning of line |
| Ctrl-W | Kill word backward |

Ctrl-K, Ctrl-U, and Ctrl-W all correctly adjust the character count (`num_read`)
by the number of characters removed. With `-n 20`, you can type 20 chars, kill
10 with Ctrl-K, then type 10 more -- the budget tracks deletions.

---

## Comparison with Other Tools

### grabchars vs. `gum` (charmbracelet/gum)

[gum](https://github.com/charmbracelet/gum) is a Go-based tool for glamorous
shell scripts. It's a Swiss Army knife with `input`, `choose`, `confirm`,
`filter`, `spin`, `style`, and more.

| Capability | grabchars | gum |
|-----------|-----------|-----|
| Grab exactly N keystrokes without Enter | Yes (`-n`) | No -- `gum input` always requires Enter |
| Single-key yes/no without Enter | Yes (`-c yn`) | No -- `gum confirm` requires Enter |
| Character filtering | Yes (`-c`, regex) | No |
| Timeout with default | Yes (`-t` + `-d`) | `--timeout` exists but has had bugs |
| Case mapping | Yes (`-U`/`-L`) | No |
| Line editing | Yes (arrows, Emacs keys) | Yes (basic line editing in `gum input`) |
| Output to stdout, prompt on stderr | Yes | Yes |
| Choose from list | Not yet | Yes (`gum choose`, `gum filter`) |
| Fuzzy filtering | No | Yes (`gum filter`) |
| Styled output / colors | No | Yes (`gum style`, Lip Gloss) |
| Spinner / progress | No | Yes (`gum spin`) |
| Markdown rendering | No | Yes (`gum format`) |
| Binary size | ~1 MB | ~15-20 MB |
| Dependencies | libc + regex | Large Go dependency tree (bubbletea, lipgloss, glamour, etc.) |

**Where grabchars wins:** Keystroke-level control. If your script needs "read
exactly 3 vowels with a 5-second timeout and a default of 'aei'", grabchars does
it in one command. gum has no equivalent -- you'd need `gum input` plus wrapper
logic, and still can't enforce character-at-a-time filtering without Enter.

**Where gum wins:** Rich TUI widgets. Choose-from-list, fuzzy filter, styled
output, spinners, markdown. gum is a UI toolkit; grabchars is a precision
input tool. They're complementary, not competing.

### grabchars vs. bash `read`

| Capability | grabchars | `read` builtin |
|-----------|-----------|---------------|
| Grab N chars without Enter | Yes (`-n`) | Yes (`-n`) |
| Character filtering | Yes (`-c`, regex) | No -- must loop/validate yourself |
| Default on timeout | Yes (`-d` + `-t`) | No -- must script `$?` + fallback |
| Default on empty Enter | Yes (`-d` + `-r`) | No |
| Line editing in -n mode | Yes (arrows, Emacs) | No -- `-n` disables readline |
| Case mapping | Yes (`-U`/`-L`) | No |
| Output routing | Yes (`-e`/`-b`) | No -- captured via `$REPLY` only |
| Silent mode | Yes (`-s`) | Yes (`-s`) |
| Timeout | Yes (`-t`) | Yes (`-t`, fractional seconds) |
| Exit status = char count | Yes | No -- 0 on success, >128 on timeout |
| Prompt | Yes (`-p`/`-q`) | Yes (`-p`) |

**Where grabchars wins:** Character filtering, defaults, case mapping, line
editing during fixed-length input, exit status as a count. A common shell
pattern -- "ask the user for y/n with a timeout defaulting to n" -- is one
grabchars command vs. 5-10 lines of bash with `read -n1 -t5`, `$?` checking,
and fallback logic.

**Where `read` wins:** It's always available (builtin), supports fractional
timeouts (`-t 0.5`), reads into named variables, supports delimiters (`-d`),
and reads from file descriptors (`-u`). For simple line input, `read` is fine.

### grabchars vs. dialog / whiptail

Not really comparable. `dialog` and `whiptail` are ncurses-based full-screen
widget toolkits (menus, file browsers, gauges, etc.). They take over the
terminal. grabchars is inline -- it reads keystrokes at the cursor position
without disrupting the screen. Different use cases entirely.

### grabchars vs. fzf

Also not comparable. `fzf` is a fuzzy finder that reads a list from stdin and
lets you filter/select interactively. It's for selection, not keystroke capture.
grabchars could potentially feed choices *to* fzf, but they don't overlap.

---

## Project Structure

```
grabchars/
  src/
    main.rs                # Argument parsing, key input, main loop, output
    term.rs                # Terminal raw mode setup/restore
  Cargo.toml
  grabchars.c                # Original C main (360 lines)
  sys.c                      # Original C terminal/signal/erase (255 lines)
  globals.c                  # Original C globals
  grabchars.h                # Original C header (FLAG struct, macros)
  grabchars.1                # Man page
  README                     # Original readme
  TODO                       # Dan Smith's TODO list
  docs/
    RUST-PORT.md             # This file
```

---

## Dependencies

```toml
[dependencies]
libc = "0.2"      # POSIX termios, signals, alarm
regex = "1"       # Character filtering (-c)
```

Key reading uses a custom `read_key()` function built on `libc::read()` to avoid
conflicts with our termios raw mode and SIGALRM setup. Select/select-lr use raw
ANSI sequences directly rather than a terminal library.

---

## What Maps Where

### Original C files -> Rust modules

| C file | Rust | Notes |
|--------|------|-------|
| `grabchars.c` main + arg parsing + char loop | `src/main.rs` | Single file, self-contained |
| `sys.c` `init_term()`, `lets_go()` | `src/term.rs` | `init_term()` / `restore_term()` / `restore_saved()` |
| `sys.c` `init_signal()`, `overtime()` | `src/main.rs` | `setup_signals()`, `setup_alarm()`, signal handlers |
| `sys.c` `handle_default()` | `src/main.rs` | `handle_default()` |
| `sys.c` `handle_erase()` + `DV_ERASE` | `src/main.rs` | **Replaced** with `KeyInput` enum + full line editing |
| `globals.c` (flags, outfile, exit_stat) | `src/main.rs` | `Flags` struct, local variables, atomics for signal safety |
| `grabchars.h` (FLAG typedef, macros) | `src/main.rs` | `Flags` struct |

### Global state

| C | Rust | Why |
|---|------|-----|
| `FLAG *flags` (heap-allocated) | `Flags` struct on stack | No need for heap allocation |
| `int exit_stat` | `static AtomicI32 EXIT_STAT` | Must be accessible from signal handlers |
| `FILE *outfile, *otherout` | `output_to_stderr: bool` | Simpler; `output_char`/`output_str` handle routing |
| `struct sgttyb orig` / `struct termio orig` | `libc::termios` returned from `init_term()` | POSIX termios replaces both BSD and SysV APIs |
| saved termios for signal handler | `static Mutex<Option<libc::termios>> SAVED_TERMIOS` | `restore_saved()` reads this in signal context |

---

## Terminal Handling (`term.rs`)

Replaces the BSD `sgtty.h` / SysV `termio.h` dual-path code from `sys.c` with
a single POSIX `termios` implementation.

**`init_term(flush: bool) -> libc::termios`**
- Calls `tcgetattr` to save original settings
- Stores a copy in `SAVED_TERMIOS` (for signal handler restoration)
- Sets raw mode: `c_lflag &= !(ICANON | ECHO)`, `VMIN=1`, `VTIME=0`
- Uses `TCSAFLUSH` (flush input) or `TCSANOW` (no flush) based on `-f` flag
- Equivalent to BSD `CBREAK | ~ECHO` with `TIOCSETP`/`TIOCSETN`

**`restore_term(orig: &libc::termios)`**
- Calls `tcsetattr(TCSAFLUSH)` to restore original terminal settings

**`restore_saved()`**
- Reads the static `SAVED_TERMIOS` and restores -- used by signal handlers
  where we can't pass parameters

---

## Key Input Architecture

### The `read_key()` / `parse_escape_seq()` pipeline

Instead of reading raw bytes and checking them inline, the port uses a `KeyInput`
enum and a `read_key()` function that returns structured key events:

```rust
enum KeyInput {
    Char(u8),
    Backspace, Delete,
    Left, Right, Home, End,
    KillToEnd, KillToStart, KillWordBack,
    Enter, Unknown,
}
```

`read_key()` reads one byte via `libc::read()`, then:
- Maps control characters to their Emacs bindings (0x01=Home, 0x02=Left, etc.)
- Maps 0x7F/0x08 to Backspace, 0x0A/0x0D to Enter
- On 0x1B (Escape), calls `parse_escape_seq()` to consume the CSI sequence

`parse_escape_seq()` handles:
- `\x1b[C/D/H/F` -- arrow keys, Home, End
- `\x1b[3~` -- Delete
- `\x1b[1~/4~` -- alternate Home/End
- Everything else -- `Unknown` (consumed and discarded)

On EINTR during escape sequence reads, returns `Unknown` -- the main loop
re-checks `TIMED_OUT`. Partial escape state is safely lost.

### ANSI escape output

Output escape sequences are defined as constants, not hardcoded inline:

```rust
const CSI: &str = "\x1b[";
const CURSOR_LEFT: &[u8] = b"\x1b[D";
const CURSOR_RIGHT: &[u8] = b"\x1b[C";
const CLEAR_TO_EOL: &[u8] = b"\x1b[K";
```

Parameterized moves use helper functions (`cursor_left_n`, `cursor_right_n`)
that write through the `CSI` constant.

### Redraw strategy

`redraw_input()` does a full-buffer redraw: move cursor to column 0 of the
buffer, clear to end of line, write the entire buffer, then reposition the
cursor. The buffer is small (at most `how_many` chars), so this is efficient.

For simple cursor-only movement (Left/Right/Home/End with no buffer change),
single escape sequences are emitted directly.

---

## Signal Handling

| Signal | C (`sys.c`) | Rust |
|--------|-------------|------|
| `SIGINT` | `signal(SIGINT, lets_go)` | `libc::signal(SIGINT, signal_handler)` |
| `SIGQUIT` | `signal(SIGQUIT, lets_go)` | `libc::signal(SIGQUIT, signal_handler)` |
| `SIGTSTP` | `signal(SIGTSTP, lets_go)` (BSD only) | `libc::signal(SIGTSTP, signal_handler)` |
| `SIGALRM` | `signal(SIGALRM, overtime)` | `libc::sigaction(SIGALRM, alarm_handler)` with `sa_flags=0` |

The `SIGALRM` handler uses `sigaction` instead of `signal()` to guarantee
that `read()` returns `EINTR` on all POSIX systems. On macOS, `signal()` sets
`SA_RESTART` by default, which would cause `read()` to silently resume after
the alarm -- never returning to check the timeout flag.

The alarm handler sets `TIMED_OUT` (an `AtomicBool`). The main loop checks
this at the top of each iteration and on `EINTR` from `read()`.

---

## Argument Parsing

The original uses `getopt(3)`. The Rust port uses a custom `ArgParser` that
replicates the original's behavior:

- Flags can be combined: `-brs` sets both, ret_key, and silent
- Value args can be attached (`-n4`, `-caeiou`) or separate (`-n 4`, `-c aeiou`)
- Value args consume the rest of the current word, then break to the next arg
- Unknown flags print usage and exit 255

This was chosen over `clap` to preserve exact CLI compatibility with the
original, including quirks like `-p 'prompt text'` where the prompt is printed
immediately during parsing (side effect during arg parse, matching the C
behavior).

---

## Flags

```rust
struct Flags {
    both: bool,            // -b: output to stdout AND stderr
    check: bool,           // -c: character filtering active
    dflt: bool,            // -d: default string set
    flush: bool,           // -f: flush input buffer on init
    ret_key: bool,         // -r: Enter key exits (with -n)
    silent: bool,          // -s: no output, just exit status
    erase: Option<bool>,   // -E: line editing (see below)
    lower: bool,           // -L: map input to lowercase
    upper: bool,           // -U: map input to uppercase
    trailing_newline: bool, // -Z: trailing newline to stderr (default: on)
}
```

### New/changed vs. original C

| Flag | Original C | Rust port |
|------|-----------|-----------|
| `-E` | `bool`, BSD erase/kill chars | `Option<bool>` tri-state with auto-default |
| `-Z` | not present | New: controls trailing newline to stderr |
| `-E0`/`-E1` | not present | New: explicit enable/disable syntax |

---

## Character Filtering (`-c`)

The original used BSD `re_comp()`/`re_exec()` for character matching. The Rust
port uses the `regex` crate:

- Input like `-c aeiou` becomes regex `^[aeiou]$`
- Input already bracketed like `-c '[a-z]'` becomes `^[a-z]$`
- Each character is tested individually against the pattern
- Non-matching characters are silently skipped (not counted, not echoed)

---

## The Main Character Loop

The heart of grabchars. Reads one logical key at a time via `read_key()`.

### Edit mode (when `erase_active`)

The loop is a `match` on `KeyInput`:

| Key | Action |
|-----|--------|
| `Char(b)` | Apply `-c` filter and case mapping. Insert at `cursor_pos`, increment `cursor_pos` and `num_read`, redraw. |
| `Backspace` | If `cursor_pos > 0`: remove char before cursor, decrement both counters, redraw. |
| `Delete` / Ctrl-D | If `cursor_pos < len`: remove char at cursor, decrement `num_read`, redraw. |
| `Left` / Ctrl-B | If `cursor_pos > 0`: decrement, emit cursor-left. |
| `Right` / Ctrl-F | If `cursor_pos < len`: increment, emit cursor-right. |
| `Home` / Ctrl-A | Move to 0, emit cursor-left-n. |
| `End` / Ctrl-E | Move to len, emit cursor-right-n. |
| `Ctrl-K` | Truncate buffer at cursor, decrement `num_read` by chars removed, clear to EOL. |
| `Ctrl-U` | Drain buffer before cursor, decrement `num_read` by chars removed, redraw. |
| `Ctrl-W` | Kill word backward (skip whitespace, then non-whitespace), adjust `num_read`, redraw. |
| `Enter` | Check default/ret_key logic, or treat as filtered char. |
| `Unknown` | Ignore silently. |

### Non-edit mode (when `!erase_active`)

Only `Char` and `Enter` matter. Arrow key escape sequences are consumed by
`read_key()` and returned as `Unknown` -- silently ignored instead of echoed
as garbage. This is a behavioral improvement even for `-n1` mode.

### Buffer full handling

When `num_read == how_many`, the `while` condition exits the loop. Cursor
movement and deletion still work during the last iteration (before the check).
After any deletion, room opens for new characters.

---

## Output Routing

Characters are sent to stdout by default, or stderr with `-e`, or both with `-b`.

| Function | Purpose |
|----------|---------|
| `output_char(ch, to_stderr, both)` | Single character output |
| `output_str(s, to_stderr, both)` | String output (default string, erase buffer) |

In erase mode, the visual echo goes to stderr always (so the user sees what
they're typing), while the final clean buffer goes to the primary output at
the end.

---

## Exit Status

The exit status is set to the number of characters read, matching the original:

| Situation | Exit status |
|-----------|-------------|
| Normal completion | `num_read` (0 to N) |
| Timeout with default | `default_string.len()` |
| Timeout without default | `-2` |
| Signal (INT/QUIT/TSTP) | Current `EXIT_STAT` value |
| Before any input | `-1` (initial value) |

---

## Trailing Newline (`-Z`)

New feature not in the original. After output completes, a newline is written
to stderr (for terminal cleanliness). This is ON by default.

- `-Z0`: disable trailing newline
- `-Z1` or `-Z`: enable trailing newline (default)

This is useful when embedding grabchars output in a larger line of terminal
output where you don't want the cursor to advance.

---

## What's NOT Ported (Yet)

- `isatty()` detection for pipe vs. terminal
- Man page updates for new flags
- Command history

---

## Building

```bash
cargo build --release
# Binary: target/release/grabchars
```

## Quick Test Commands

```bash
# Single char (no editing, arrows silently ignored)
./target/release/grabchars -p ">> "

# 10 chars with full line editing (auto-enabled)
./target/release/grabchars -n10 -r -p ">> "
# Try: type "hello", Left 3x, type "XY" -> "heXYllo"
# Try: Ctrl-A (home), Ctrl-K (kill all), retype
# Try: Ctrl-W to kill word backward

# 5 vowels only, editing works on accepted chars
./target/release/grabchars -n5 -p ">> " -c aeiou

# 5 chars, editing explicitly disabled
./target/release/grabchars -n5 -p ">> " -E0

# 3 chars with 5-second timeout
./target/release/grabchars -n3 -p ">> " -t5

# Default value on Enter or timeout
./target/release/grabchars -n3 -p ">> " -d abc -t5

# Silent mode (exit status only)
./target/release/grabchars -n3 -s; echo "got $? chars"

# Uppercase mapping
./target/release/grabchars -n3 -p ">> " -U

# 20-char buffer, go wild with editing
./target/release/grabchars -n20 -r -p ">> "
# Type, Ctrl-K, Ctrl-U, Ctrl-W, arrows, Home, End -- count tracks correctly
```
