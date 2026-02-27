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
mask mode, select/select-lr menus, raw byte capture, and a proper POSIX signal
architecture.

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
- **Character exclusion** (`-C`) -- reject specific characters, accept everything else
- **Raw mode** (`-R`) -- bypass escape-sequence parser; every byte captured as-is,
  `-n` counts bytes; arrow key = 3 bytes; `-c`/`-C`/`-U`/`-L`/`-E` silently ignored
- **Mask mode** (`-m`) -- positional input validation; character classes (U/l/c/n/x/p/./`[...]`),
  literal auto-insertion, quantifiers (`*`/`+`/`?`)
- **Vertical select** (`select`) -- filter-as-you-type list selection
- **Horizontal select** (`select-lr`) -- left/right list navigation with configurable highlight
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
| Choose from list | Yes (`select`, `select-lr`) | Yes (`gum choose`, `gum filter`) |
| Fuzzy filtering | No (`select` uses prefix filter) | Yes (`gum filter`) |
| Raw byte capture | Yes (`-R`) | No |
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
    main.rs      # Argument parsing, Flags, signal/alarm setup, normal+raw mode loops
    input.rs     # read_key() + read_byte(): raw byte reads, escape sequence parsing
    output.rs    # output_char/str/bytes(), redraw_input(), cursor helpers
    mask.rs      # Mask mode (-m): MaskElement, MaskClass, quantifiers, run_mask_mode()
    select.rs    # Vertical select and horizontal select-lr modes
    term.rs      # Terminal raw mode setup/restore (POSIX termios)
  docs/
    cookbook.md          # Runnable examples covering every feature
    maskInput.md         # Mask syntax reference
    RAW-MODE.md          # Raw mode (-R) reference
    RUST-PORT.md         # This file
    quantifiers-plan.md  # Design doc for mask quantifiers
  tests/
    helpers.sh           # Shared test utilities and assertions
    menu.sh              # Interactive test selector (uses grabchars select-lr)
    run_tests.sh         # Master test runner
    01_basic.sh … 12_raw.sh   # Test suites by feature
  Cargo.toml
  LICENSE                # Apache 2.0
```

---

## Dependencies

```toml
[dependencies]
libc = "0.2"      # POSIX termios, signals, alarm
regex = "1"       # Character filtering (-c)
```

Key reading uses a custom `read_key()` / `read_byte()` built on `libc::read()`
to avoid conflicts with our termios raw mode and SIGALRM setup. Select/select-lr
use raw ANSI sequences directly rather than a terminal library.

---

## What Maps Where

### Original C files -> Rust modules

| C file | Rust | Notes |
|--------|------|-------|
| `grabchars.c` main + arg parsing + char loop | `src/main.rs` | Significantly expanded |
| `sys.c` `init_term()`, `lets_go()` | `src/term.rs` | `init_term()` / `restore_term()` / `restore_saved()` |
| `sys.c` `init_signal()`, `overtime()` | `src/main.rs` | `setup_signals()`, `setup_alarm()`, signal handlers |
| `sys.c` `handle_default()` | `src/output.rs` | Moved to output module |
| `sys.c` `handle_erase()` + `DV_ERASE` | `src/main.rs` | **Replaced** with `KeyInput` enum + full line editing |
| `globals.c` (flags, outfile, exit_stat) | `src/main.rs` | `Flags` struct, local variables, atomics for signal safety |
| `grabchars.h` (FLAG typedef, macros) | `src/main.rs` | `Flags` struct |
| *(new)* | `src/input.rs` | Key input and escape sequence parsing |
| *(new)* | `src/output.rs` | All output functions |
| *(new)* | `src/mask.rs` | Mask mode |
| *(new)* | `src/select.rs` | Select / select-lr modes |

### Global state

| C | Rust | Why |
|---|------|-----|
| `FLAG *flags` (heap-allocated) | `Flags` struct on stack | No need for heap allocation |
| `int exit_stat` | `static AtomicI32 EXIT_STAT` | Must be accessible from signal handlers |
| `FILE *outfile, *otherout` | `output_to_stderr: bool` | Simpler; `output_char`/`output_str`/`output_bytes` handle routing |
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

### The `read_byte()` function (`input.rs`)

The lowest-level primitive. One `libc::read()` call for a single byte:

```rust
pub fn read_byte(fd: i32) -> Result<u8, io::Error>
```

Returns:
- `Ok(byte)` — success
- `Err(UnexpectedEof)` — EOF (n == 0)
- `Err(last_os_error())` — error, including `ErrorKind::Interrupted` for EINTR

`read_byte` is `pub` so that raw mode (`-R`) can call it directly from `main.rs`,
bypassing all escape-sequence interpretation.

### The `read_key()` / `parse_escape_seq()` pipeline

Used by normal mode, mask mode, and select modes. Returns structured key events:

```rust
enum KeyInput {
    Char(u8),
    Backspace, Delete,
    Left, Right, Up, Down,
    Home, End,
    Tab,
    Escape,
    KillToEnd, KillToStart, KillWordBack,
    Enter, Unknown,
}
```

`read_key()` calls `read_byte()`, then:
- Maps control characters to their Emacs bindings (0x01=Home, 0x02=Left, etc.)
- Maps 0x7F/0x08 to Backspace, 0x0A/0x0D to Enter
- On 0x1B (Escape), calls `parse_escape_seq()` to consume the CSI sequence

`parse_escape_seq()` handles:
- `\x1b[C/D/H/F` -- arrow keys, Home, End
- `\x1b[3~` -- Delete
- `\x1b[1~/4~` -- alternate Home/End
- Everything else -- `Unknown` (consumed and discarded)

ESC disambiguation: `byte_available(fd, 50)` (poll with 50ms timeout) decides
whether ESC is bare or the start of a sequence. Bare ESC returns `KeyInput::Escape`.

On EINTR, `read_byte` returns `Err(Interrupted)`. Callers handle it by
`continue`-ing their loop to re-check `TIMED_OUT`. Partial escape state is
safely lost.

### ANSI escape output

Output escape sequences are defined as constants:

```rust
const CSI: &str = "\x1b[";
const CURSOR_LEFT:  &[u8] = b"\x1b[D";
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

The alarm handler sets `TIMED_OUT` (an `AtomicBool`). All reading loops check
this at the top of each iteration and on `EINTR` from `read_byte()`.

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
    both: bool,             // -b: output to stdout AND stderr
    check: bool,            // -c: character filtering active
    exclude: bool,          // -C: character exclusion active
    dflt: bool,             // -d: default string set
    flush: bool,            // -f: flush input buffer on init
    raw: bool,              // -R: raw byte capture (bypass escape parser)
    ret_key: bool,          // -r: Enter key exits (with -n)
    silent: bool,           // -s: no output, just exit status
    erase: Option<bool>,    // -E: line editing (None=auto, Some(true)=on, Some(false)=off)
    lower: bool,            // -L: map input to lowercase
    upper: bool,            // -U: map input to uppercase
    trailing_newline: bool, // -Z: trailing newline to stderr (default: on)
    highlight_style: HighlightStyle,  // -H: select-lr highlight (Reverse/Bracket/Arrow)
}
```

### New/changed vs. original C

| Flag | Original C | Rust port |
|------|-----------|-----------|
| `-E` | `bool`, BSD erase/kill chars | `Option<bool>` tri-state with auto-default |
| `-C` | not present | New: character exclusion (complement of `-c`) |
| `-R` | not present | New: raw byte capture mode |
| `-H` | not present | New: select-lr highlight style |
| `-Z` | not present | New: controls trailing newline to stderr |
| `-E0`/`-E1` | not present | New: explicit enable/disable syntax |

---

## Character Filtering (`-c`) and Exclusion (`-C`)

The original used BSD `re_comp()`/`re_exec()` for character matching. The Rust
port uses the `regex` crate:

- Input like `-c aeiou` becomes regex `^[aeiou]$`
- Input already bracketed like `-c '[a-z]'` becomes `^[a-z]$`
- Each character is tested individually against the pattern
- Non-matching characters are silently skipped (not counted, not echoed)

`-C` works identically but inverted: matching characters are rejected.

Both flags are silently ignored in raw mode (`-R`).

---

## The Main Character Loop

`main()` branches into one of four modes in this order:

```
1. select / select-lr  →  src/select.rs   (early exit)
2. mask mode (-m)      →  src/mask.rs     (early exit)
3. raw mode (-R)       →  inline in main  (early exit)
4. normal mode         →  inline in main  (falls through)
```

### Raw mode loop (`-R`)

Calls `input::read_byte(stdin_fd)` in a tight loop, accumulating bytes directly:

- Each byte (any byte, including 0x1B) is pushed to the buffer unconditionally
- EINTR → `continue` (allows SIGALRM to interrupt, TIMED_OUT re-checked next iter)
- If `-r` is active and byte is 0x0A or 0x0D → exit loop (Enter byte not stored)
- `-c`/`-C`/`-U`/`-L`/`-E` are never consulted
- On loop exit: `output_bytes(&buffer, ...)` then `process::exit(num_read)`

### Edit mode (when `erase_active`)

The loop is a `match` on `KeyInput`:

| Key | Action |
|-----|--------|
| `Char(b)` | Apply `-c`/`-C` filters and case mapping. Insert at `cursor_pos`, increment `cursor_pos` and `num_read`, redraw. |
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
| `Unknown` / `Up` / `Down` / `Tab` / `Escape` | Ignore silently. |

### Non-edit mode (when `!erase_active`)

Only `Char`, `Backspace` (as raw byte 0x7F), and `Enter` matter. Arrow key
escape sequences are consumed by `read_key()` and returned as `Unknown` --
silently ignored instead of echoed as garbage. This is a behavioral improvement
even for `-n1` mode.

### Buffer full handling

When `num_read == how_many`, the `while` condition exits the loop. Cursor
movement and deletion still work during the last iteration (before the check).
After any deletion, room opens for new characters.

---

## Output Routing

Characters are sent to stdout by default, or stderr with `-e`, or both with `-b`.

| Function | Purpose |
|----------|---------|
| `output_char(ch, to_stderr, both)` | Single character (used in non-edit mode per-char echo) |
| `output_str(s, to_stderr, both)` | String output (default string, final edit buffer) |
| `output_bytes(buf, to_stderr, both)` | Raw byte slice output (raw mode; uses `write_all`, no UTF-8 assumption) |

In edit mode, the visual echo goes to stderr always (so the user sees what
they're typing), while the final clean buffer goes to the primary output at
the end.

In raw mode, there is no per-byte echo. The entire buffer is written at exit
via `output_bytes`.

---

## Exit Status

The exit status is set to the number of characters (or bytes, in raw mode) read:

| Situation | Exit status |
|-----------|-------------|
| Normal completion | `num_read` (0 to N) |
| Raw mode completion | `num_read` in bytes (arrow key = 3) |
| Timeout with default | `default_string.len()` |
| Timeout without default | `-2` (i.e., 254 in u8 shell exit) |
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

# Phone number mask — literals auto-inserted
./target/release/grabchars -m "(nnn) nnn-nnnn" -q "Phone: "

# Date mask
./target/release/grabchars -m "nn/nn/nnnn" -q "Date (MM/DD/YYYY): "

# Vertical select from a list
./target/release/grabchars select "red,green,blue,yellow" -q "Color: "

# Horizontal select
./target/release/grabchars select-lr "yes,no,cancel" -q "Action: "

# Raw mode: capture arrow key as 3 bytes, exit code 3
./target/release/grabchars -R -n3 -q "Press arrow key: "

# Raw mode: discover what bytes a key sends
./target/release/grabchars -R -n6 -q "Press a key: " | xxd

# 20-char buffer, go wild with editing
./target/release/grabchars -n20 -r -p ">> "
# Type, Ctrl-K, Ctrl-U, Ctrl-W, arrows, Home, End -- count tracks correctly
```
