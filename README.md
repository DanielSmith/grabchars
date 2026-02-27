# grabchars

**Precision keystroke capture for shell scripts.**

`grabchars` reads one or more keystrokes directly from the terminal — no Enter
required. Originally written in C by Dan Smith (1988–1990, `comp.sources.misc`),
this is a complete Rust rewrite preserving exact CLI compatibility while adding
line editing, arrow key navigation, Emacs keybindings, and proper POSIX signal
handling.

If your script needs "read exactly 3 vowels with a 5-second timeout defaulting
to 'aei'", grabchars does it in one command.

---

## Features

- **Single-keystroke capture** — grab exactly 1 key without Enter
- **Multi-character input** (`-n N`) — grab exactly N keystrokes
- **Character filtering** (`-c`) — only accept characters matching a regex pattern
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
- **Trailing newline control** (`-Z`) — suppress the final newline to stderr
- **Exit status = character count** — for shell `$?` testing

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
grabchars [-b] [-c chars] [-d default] [-e] [-f] [-n count]
          [-p prompt] [-q prompt] [-r] [-s] [-t seconds]
          [-E[0|1]] [-L] [-U] [-Z[0|1]]
```

### Flags Reference

| Flag | Description |
|------|-------------|
| `-b` | Output to both stdout and stderr |
| `-c chars` | Character filter — only accept matching characters (regex) |
| `-d default` | Default string returned on Enter or timeout |
| `-e` | Output to stderr instead of stdout |
| `-f` | Flush type-ahead input buffer before reading |
| `-n count` | Number of keystrokes to read (default: 1) |
| `-p prompt` | Print prompt to stdout |
| `-q prompt` | Print prompt to stderr |
| `-r` | Enter key exits early (with `-n`) |
| `-s` | Silent mode — no echo, exit status only |
| `-t seconds` | Timeout in seconds |
| `-E` / `-E1` | Enable line editing (auto-enabled when `-n > 1`) |
| `-E0` | Disable line editing |
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
./grabchars -p "Continue? [y/n] " -c yn
echo    # user pressed 'y' or 'n' immediately, no Enter needed

# 10 chars with full line editing (auto-enabled)
./grabchars -n10 -r -p "Name: "

# 5 vowels only
./grabchars -n5 -p "Vowels: " -c aeiou

# 3 chars with 5-second timeout and default
./grabchars -n3 -p "Code: " -d abc -t5

# Silent mode (exit status only)
./grabchars -n3 -s; echo "Read $? characters"

# Uppercase mapping
./grabchars -n3 -p "Initials: " -U

# Disable editing for fixed-length input
./grabchars -n5 -p "PIN: " -E0

# 20-char buffer — try arrows, Ctrl-K, Ctrl-U, Ctrl-W
./grabchars -n20 -r -p ">> "
```

### Exit Status

| Situation | Exit status |
|-----------|-------------|
| Normal completion | Number of characters read (0–N) |
| Timeout with `-d` | Length of default string |
| Timeout without `-d` | 254 (`-2` unsigned) |

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
  docs/
    RUST-PORT.md             # Detailed port notes and design decisions
  src/
    main.rs                  # Argument parsing, key input, main loop, output
    term.rs                  # Terminal raw mode setup/restore (POSIX termios)
  Cargo.toml
  grabchars.c                # Original C source (reference)
  sys.c                      # Original C terminal/signal code (reference)
  globals.c                  # Original C globals (reference)
  grabchars.h                # Original C header (reference)
  grabchars.1                # Man page
```

---

## History

Written in 1988 by Dan Smith (`daniel@island.uu.net`) and posted to
`comp.sources.misc`. The original C code (~665 lines across 4 files) no longer
compiles on modern systems due to K&R syntax, BSD-only terminal APIs
(`sgtty.h`), deprecated regex functions (`re_comp`/`re_exec`), and old signal
conventions. This Rust port is a complete rewrite preserving the original CLI
contract.

---

## License

Licensed under the [Apache License, Version 2.0](LICENSE) ([http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)).
