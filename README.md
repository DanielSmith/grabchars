# grabchars 2.0

**direct keystroke capture for shell scripts.**

`grabchars` reads one or more keystrokes directly from the terminal — no Enter
required. Originally written in C by me, Dan Smith (1988–1990, `comp.sources.misc`),
this is a complete Rust rewrite, adding
line editing, arrow key navigation, advanced filtering, Emacs keybindings, and proper POSIX signal
handling.

If your script needs just one character, or something like "read up to 4 digits for a PIN, default to `1234` if the user doesn't respond in 5 seconds", grabchars does it in one command.

---

## Features

- **Single-keystroke capture** — grab exactly 1 key without Enter
- **Multi-character input** (`-n N`) — grab exactly N keystrokes
- **Character filtering** (`-c`) — only accept characters matching a character class (e.g., `aeiou`, `[A-Z]`, `0-9`)
- **Default values** (`-d`) — return a default on Enter or timeout
- **Timeout** (`-t`) — alarm-based timeout with SIGALRM
- **Case mapping** (`-U` / `-L`) — force upper or lowercase
- **Output routing** (`-e` / `-b`) — stdout, stderr, or both
- **Silent mode** (`-s`) — no echo, exit status only
- **Line editing** (`-E`) — auto-enabled for `-n > 1`
- **Arrow key navigation** — Left/Right cursor movement within the buffer
- **Home/End keys** — jump to start/end of input
- **Forward delete** — Delete key removes character ahead of cursor
- **Emacs keybindings** — Ctrl-A/E/F/B/D/K/U/W
- **Raw mode** (`-R`) — capture bytes as-is, bypassing escape-sequence parsing; arrow key = 3 bytes, function keys = 4–5 bytes; `-n` counts bytes
- **Mask mode** (`-m`) — positional input validation with auto-inserted literals (phone numbers, dates, serial numbers)
- **Trailing newline control** (`-Z`) — suppress the final newline to stderr
- **Exit status = character count** — for shell `$?` testing
- **Vertical select** (`select`) — choose from a list with Up/Down arrows and filter-as-you-type
- **Horizontal select** (`select-lr`) — inline left/right selection with configurable highlight styles

---

## Building

```bash
cargo build --release
# Binary: target/release/grabchars
```

### Dependencies

| Crate | Purpose |
|-------|---------|
| `libc` | POSIX termios, signals, alarm |
| `regex` | Character filtering (`-c`) |

---

## Usage

```
grabchars [-b] [-c chars] [-C exclude] [-d default] [-e] [-f] [-m mask]
          [-n count] [-p prompt] [-q prompt] [-r] [-R] [-s] [-t seconds]
          [-E[0|1]] [-H[r|b|a]] [-L] [-U] [-Z[0|1]]

grabchars select  [opts] "item1,item2,..."   # vertical list
grabchars select  [opts] --file filename     # vertical list from file
grabchars select-lr [opts] "item1,item2,..." # horizontal list
grabchars select-lr [opts] --file filename   # horizontal list from file
```

### Flags Reference

| Flag | Description |
|------|-------------|
| `-b` | Output to both stdout and stderr |
| `-c chars` | Character filter — only accept matching characters (character class: `aeiou`, `[A-Z]`, `0-9`) |
| `-C chars` | Character exclusion — reject matching characters, accept everything else |
| `-d default` | Default string returned on Enter or timeout |
| `-e` | Output to stderr instead of stdout |
| `-f` | Flush type-ahead input buffer before reading |
| `-m mask` | Mask mode — positional input with auto-inserted literals (see mask syntax) |
| `-n count` | Number of keystrokes to read (default: 1) |
| `-p prompt` | Print prompt to stdout |
| `-q prompt` | Print prompt to stderr |
| `-r` | Enter key exits early (with `-n`) |
| `-R` | Raw mode — capture bytes as-is, no escape-sequence parsing (`-c`/`-C`/`-U`/`-L`/`-E` are ignored) |
| `-s` | Silent mode — no echo, exit status only |
| `-t seconds` | Timeout in seconds |
| `-E` / `-E1` | Enable line editing (auto-enabled when `-n > 1`) |
| `-E0` | Disable line editing |
| `-H r\|b\|a` | Select-lr highlight style: `r` reverse video (default), `b` bracket, `a` arrow |
| `-L` | Map all input to lowercase |
| `-U` | Map all input to uppercase |
| `-Z0` | Suppress trailing newline to stderr |
| `-Z` / `-Z1` | Enable trailing newline to stderr (default) |

### Emacs Keybindings (when editing is enabled)

| Key | Action |
|-----|--------|
| Ctrl-A | Beginning of line |
| Ctrl-E | End of line |
| Ctrl-F | Forward one character |
| Ctrl-B | Backward one character |
| Ctrl-D | Delete character at cursor |
| Ctrl-K | Kill to end of line |
| Ctrl-U | Kill to beginning of line |
| Ctrl-W | Kill word backward |

Kill commands correctly adjust the character budget — with `-n 20`, you can
type 20 chars, kill 10 with Ctrl-K, then type 10 more.

---

## Examples

```bash
# Single character — y/n prompt
grabchars -q "Continue? [y/n] " -c yn

# 10 chars with full line editing (auto-enabled)
grabchars -n10 -r -q "Name: "

# 5 vowels only
grabchars -n5 -q "Vowels: " -c aeiou

# 3 chars with 5-second timeout and default
grabchars -n3 -q "Code: " -d abc -t5

# Silent mode (exit status only)
grabchars -n3 -s; echo "Read $? characters"

# Uppercase mapping
grabchars -n3 -q "Initials: " -U

# Disable editing for fixed-length input
grabchars -n5 -q "PIN: " -E0

# Phone number — literals auto-inserted
grabchars -m "(nnn) nnn-nnnn" -q "Phone: "

# Date with mask
grabchars -m "nn/nn/nnnn" -q "Date (MM/DD/YYYY): "

# Vertical select — arrow keys + filter-as-you-type
grabchars select "red,green,blue,yellow" -q "Color: "

# Horizontal select — left/right arrows
grabchars select-lr "yes,no,cancel" -q "Action: "

# Horizontal select with bracket highlight style
grabchars select-lr "small,medium,large" -Hb -q "Size: "

# Raw mode: capture arrow key as 3 bytes (ESC [ A), exit code 3
grabchars -R -n3 -q "Press an arrow key: "

# Raw mode: up to 20 bytes, Enter to stop early
grabchars -R -n20 -r -q "Type (Enter to finish): "

# Raw mode: discover what bytes any key sends (pipe to xxd)
grabchars -R -n6 -q "Press a key: " | xxd
```

### Exit Status

| Situation | Exit status |
|-----------|-------------|
| Normal completion | Number of characters read (1–N) |
| Raw mode (`-R`) completion | Number of **bytes** read (arrow key = 3) |
| Timeout with `-d` | Length of default string |
| Timeout without `-d` | 254 |
| ESC pressed | 255 (normal mode only; in `-R`, ESC is just byte 0x1B) |
| Error (bad flags, bad mask) | 255 |

---

## Comparison with Other Tools

### vs. bash `read`

| Capability | grabchars | `read` builtin |
|------------|-----------|----------------|
| Grab N chars without Enter | ✅ `-n` | ✅ `-n` |
| Character filtering | ✅ `-c` (regex) | ❌ manual loop |
| Default on timeout/Enter | ✅ `-d` + `-t` | ❌ script `$?` + fallback |
| Line editing in `-n` mode | ✅ arrows, Emacs keys | ❌ `-n` disables readline |
| Case mapping | ✅ `-U` / `-L` | ❌ |
| Exit status = char count | ✅ | ❌ |

A common pattern — "ask y/n with a 5s timeout defaulting to n" — is one
grabchars command vs. 5–10 lines of bash.

### vs. gum

**grabchars wins** at keystroke-level control: character filtering, fixed-count
input, timeout defaults. **gum wins** at rich TUI: fuzzy filtering, styled
output, spinners, choose-from-list. They're complementary.

### vs. dialog / whiptail / fzf

Different tools for different jobs. `dialog`/`whiptail` are full-screen ncurses
widgets. `fzf` is a fuzzy finder. grabchars is inline keystroke capture — it
reads at the cursor without taking over the terminal.

---

## Project Structure

```
grabchars/
  src/
    main.rs                  # Argument parsing, normal mode loop, signal handling
    input.rs                 # Raw key input, escape sequence parsing
    output.rs                # ANSI sequences, cursor control, output routing
    mask.rs                  # Mask mode — positional input validation
    select.rs                # Select mode (vertical) and select-lr (horizontal)
    term.rs                  # Terminal raw mode setup/restore (POSIX termios)
  docs/
    cookbook.md              # Runnable examples covering all features
    maskInput.md             # Mask syntax reference
    RAW-MODE.md              # Raw mode (-R) reference: byte sequences, flag interactions, impl notes
    RUST-PORT.md             # Port notes, design decisions, architecture detail
    quantifiers-plan.md      # Design doc for mask quantifiers
    README-1990              # Original 1990 readme from comp.sources.misc
  tests/
    helpers.sh               # Shared test utilities
    menu.sh                  # Interactive test menu (uses grabchars select-lr)
    run_tests.sh             # Run all test groups
    01_basic.sh … 12_raw.sh        # Test suites by feature
  Cargo.toml
  LICENSE                    # Apache 2.0
```

---

## History

Written in 1988 by me, Dan Smith (at the time: `daniel@island.uu.net`) and posted to
`comp.sources.misc`. The original C code (~665 lines across 4 files) no longer
compiles on modern systems due to K&R syntax, BSD-only terminal APIs
(`sgtty.h`), deprecated regex functions (`re_comp`/`re_exec`), and old signal
conventions. This Rust port is a complete rewrite.

---

## License

Licensed under the [Apache License, Version 2.0](LICENSE) ([http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)).
