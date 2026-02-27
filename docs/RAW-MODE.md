# Raw Mode (-R)

Raw mode captures terminal input byte-by-byte without any interpretation.
Where normal grabchars translates keystroke sequences into logical keys
(Left, Backspace, Enter, …), `-R` hands every byte straight to the
caller exactly as the terminal sends it.

---

## Why raw mode exists

Every key the user presses is transmitted to the program as one or more
bytes. Simple keys send one byte each (`a` → `0x61`). Special keys send
multi-byte escape sequences:

| Key       | Bytes (hex)              | Bytes (decimal) |
|-----------|--------------------------|-----------------|
| Up arrow  | `1b 5b 41`               | 27 91 65        |
| Down arrow| `1b 5b 42`               | 27 91 66        |
| Right arrow| `1b 5b 43`             | 27 91 67        |
| Left arrow| `1b 5b 44`               | 27 91 68        |
| Home      | `1b 5b 48` or `1b 5b 31 7e` | varies       |
| End       | `1b 5b 46` or `1b 5b 34 7e` | varies       |
| Delete    | `1b 5b 33 7e`            | 27 91 51 126    |
| F1        | `1b 4f 50`               | 27 79 80        |
| Backspace | `7f` (or `08`)           | 127 (or 8)      |
| Escape    | `1b`                     | 27              |
| Enter     | `0d` (or `0a`)           | 13 (or 10)      |
| Ctrl-C    | `03`                     | 3               |

Normal grabchars absorbs these sequences and collapses them to a single
logical `KeyInput` variant. That is exactly right for interactive text
input — but it makes it impossible to discover what byte sequence a
particular key actually sends, or to forward the raw sequence to another
program that will do its own interpretation.

`-R` skips the entire `read_key()` / escape-sequence-parser path and
calls `read_byte()` in a direct loop instead.

---

## Usage

```
grabchars -R [other flags]
```

`-R` is a normal grabchars flag and stacks freely with most other flags.
It does not interact with select or mask modes (those branch before the
raw-mode block is reached).

### Minimal examples

```bash
# Capture exactly 3 bytes, then exit
grabchars -R -n 3

# Capture bytes until Enter is pressed (Enter byte not included)
grabchars -R -n 20 -r

# Capture 1 byte silently; exit code tells you it arrived
grabchars -R -n 1 -s

# Capture up to 6 bytes with a 5-second timeout
grabchars -R -n 6 -t 5
```

---

## Flag interactions

### Flags that work normally

| Flag | Behaviour in raw mode |
|------|-----------------------|
| `-n<N>` | Collect exactly N **bytes** (not characters). Arrow key = 3 bytes toward N. Required; defaults to 1. |
| `-r` | LF (0x0A) or CR (0x0D) exits the loop. The Enter byte is **not** added to the buffer or counted. |
| `-s` | Suppress all output. The exit code still reports byte count. |
| `-e` | Route output to stderr instead of stdout. |
| `-b` | Route output to both stdout and stderr. |
| `-Z0/-Z1` | Control whether a trailing newline goes to stderr after exit. Default on. |
| `-d<str>` | If `-r` is active and Enter is pressed with zero bytes accumulated, output the default string instead. |
| `-t<secs>` | Timeout: if it fires with zero bytes and `-d` is set, output the default; otherwise output whatever was collected so far and exit 254. |
| `-p<prompt>` | Prompt to stdout before reading (printed at arg-parse time, before raw loop). |
| `-q<prompt>` | Prompt to stderr before reading. |
| `-f` | Flush typeahead from the terminal before reading. |

### Flags silently ignored

| Flag | Why ignored |
|------|-------------|
| `-c<chars>` | Include filter — meaningless for raw bytes; filtering a 3-byte escape sequence by individual byte value makes no semantic sense. |
| `-C<chars>` | Exclude filter — same reason. |
| `-U` / `-L` | Case mapping — operates on characters, not bytes. |
| `-E` / `-E0` / `-E1` | Line editing — the raw loop has no concept of a cursor or editing buffer; every byte is just appended. |

No warning is emitted when these flags are combined with `-R`; they are
simply inert.

---

## Byte counting and `-n`

`-n` specifies how many **bytes** to collect, not how many keys or
characters. The distinction matters for multi-byte sequences:

- An arrow key sends 3 bytes → counts as 3 toward `-n`.
- An F-key may send 4 or 5 bytes → counts as 4 or 5.
- An ASCII letter sends 1 byte → counts as 1.

Example: `grabchars -R -n 3` collects exactly 3 bytes and exits. If the
user presses Up arrow, all 3 bytes of the CSI sequence arrive and the
loop exits immediately. If the user presses `a`, only 1 byte arrives;
the loop waits for 2 more.

There is no concept of "one logical key = one unit" in raw mode.

---

## Exit codes

| Situation | Exit code |
|-----------|-----------|
| N bytes collected | N (1–253) |
| Default returned on Enter with `-r -d` | length of the default string |
| Timeout with zero input and no `-d` | 254 |
| Timeout with partial input | 254 |
| Timeout with zero input and `-d` set | length of the default string |
| EOF or read error before `-n` reached | bytes collected so far |

Exit code 255 (Escape pressed) does not apply in raw mode: Escape is just
byte 0x1B and counts toward `-n` like any other byte.

---

## Output format

Output is the raw byte buffer written with `write_all` — no encoding,
no translation. If the buffer contains a 3-byte arrow sequence, those
3 bytes are written verbatim. If stdout is a terminal, the terminal may
render them as cursor movement. If stdout is a pipe or file, they are
stored as-is.

To inspect raw output in hex:

```bash
grabchars -R -n 3 -q "Press a key: " | xxd
```

---

## Interaction with `-r` (Enter to exit)

When `-r` is active, any byte equal to `0x0D` (CR) or `0x0A` (LF) causes
the raw loop to exit. The Enter byte is **not** pushed into the buffer and
is **not** counted. Exit code reflects only the non-Enter bytes collected.

If `-r` fires with zero bytes accumulated and `-d` is set, the default
string is output exactly as in normal mode.

Note: in normal mode, Enter with `-r` is detected at the `KeyInput::Enter`
level, after the parser has consumed both bytes of any CR/LF pair. In raw
mode, `0x0D` and `0x0A` are checked individually as each byte arrives.
On virtually all terminals, Enter sends only one of these, so the
difference is invisible in practice.

---

## Interaction with `-d` (default) and `-t` (timeout)

Both work the same as in normal mode, with the caveat that "no input"
means the byte buffer is empty:

```bash
# Timeout with default: auto-returns "yes" after 5 seconds
grabchars -R -n 10 -r -d yes -t 5 -q "Confirm (5s): "
```

If the timeout fires with bytes already in the buffer, those bytes are
output (unless `-s`) and the exit code is 254 regardless of whether
partial input exists.

---

## Implementation

### Data flow

```
main.rs arg parser
  └─ flags.raw = true

main.rs main()
  ├─ select mode? → branch out (before raw block)
  ├─ mask mode?   → branch out (before raw block)
  └─ flags.raw?   → raw loop (early exit, never falls through to normal loop)
       │
       ├─ input::read_byte(stdin_fd)   ← one syscall per byte
       │     libc::read(fd, buf, 1)
       │     returns Ok(byte) | Err(EINTR) | Err(other)
       │
       ├─ EINTR → continue (SIGALRM restartable at outer loop level)
       ├─ 0x0A / 0x0D + flags.ret_key → break 'raw
       └─ otherwise → buffer.push(b), num_read += 1
       │
       └─ after loop:
            output::output_bytes(&buffer, output_to_stderr, flags.both)
            process::exit(num_read as i32)
```

### Modified and added functions

**`input::read_byte(fd: i32) → Result<u8, io::Error>`** *(was private,
now `pub`)*

One `libc::read` call for a single byte. Returns:
- `Ok(byte)` on success
- `Err(UnexpectedEof)` on EOF (n == 0)
- `Err(last_os_error())` on error, including `ErrorKind::Interrupted` for
  EINTR

EINTR propagates up to the raw loop, which catches it and continues:
```rust
Err(ref e) if e.kind() == io::ErrorKind::Interrupted => continue,
```
This allows SIGALRM (the timeout signal) to interrupt the blocking
`read()` call and let the loop check `TIMED_OUT` on the next iteration.

**`output::output_bytes(buf: &[u8], to_stderr: bool, both: bool)`** *(new)*

Writes a `&[u8]` slice verbatim using `write_all`, respecting the same
`-e`/`-b` routing as `output_str` and `output_char`. Does not assume the
buffer is valid UTF-8.

### Branch position in main()

The raw-mode block sits between the mask-mode branch and the
`erase_active` resolution:

```
select mode branch  →  exits early
mask mode branch    →  exits early
raw mode branch     →  exits early   ← here
erase_active = ...
normal reading loop
```

This means `-R` combined with `select` or `mask` subcommands is
impossible by construction: the select and mask branches run first.

---

## Common key sequences (quick reference)

Exact sequences vary by terminal emulator and OS. These are typical
values on modern xterm-compatible terminals (xterm, iTerm2, GNOME
Terminal, Windows Terminal).

```
Key              Hex bytes           Notes
─────────────────────────────────────────────────────────────────
a–z, A–Z, 0–9   61–7a, 41–5a, 30–39  one byte each
Space            20
Tab              09
Enter            0d (or 0a on some)
Backspace        7f (or 08 on some)
Escape           1b                  bare, no following bytes
Ctrl-A … Ctrl-Z  01 … 1a            except Ctrl-I=Tab, Ctrl-J=LF,
                                     Ctrl-M=CR (=Enter on most)
Ctrl-C           03
Ctrl-D           04
─────────────────────────────────────────────────────────────────
Up               1b 5b 41           ESC [ A
Down             1b 5b 42           ESC [ B
Right            1b 5b 43           ESC [ C
Left             1b 5b 44           ESC [ D
Home             1b 5b 48           ESC [ H  (xterm)
                 1b 5b 31 7e        ESC [ 1 ~  (vt220 style)
End              1b 5b 46           ESC [ F  (xterm)
                 1b 5b 34 7e        ESC [ 4 ~  (vt220 style)
Insert           1b 5b 32 7e        ESC [ 2 ~
Delete           1b 5b 33 7e        ESC [ 3 ~
PgUp             1b 5b 35 7e        ESC [ 5 ~
PgDn             1b 5b 36 7e        ESC [ 6 ~
─────────────────────────────────────────────────────────────────
F1               1b 4f 50           ESC O P  (xterm SS3)
                 1b 5b 31 31 7e     ESC [ 1 1 ~  (vt220 style)
F2               1b 4f 51 / 1b 5b 31 32 7e
F3               1b 4f 52 / 1b 5b 31 33 7e
F4               1b 4f 53 / 1b 5b 31 34 7e
F5               1b 5b 31 35 7e
F6               1b 5b 31 37 7e     (skips 16)
F7               1b 5b 31 38 7e
F8               1b 5b 31 39 7e
F9               1b 5b 32 30 7e
F10              1b 5b 32 31 7e
F11              1b 5b 32 33 7e
F12              1b 5b 32 34 7e
```

To discover what your terminal sends for any key:

```bash
grabchars -R -n 6 -q "Press a key: " | xxd
```

Adjust `-n` to be larger than any sequence you expect. If fewer bytes
arrive (e.g. a plain letter gives 1 byte), the loop waits for the
remaining count — press Enter while `-r` is set to exit early, or just
press enough keys to fill the count.

A better discovery loop with `-r` to exit on Enter:

```bash
while true; do
    printf "Key (Enter to stop): "
    grabchars -R -n 10 -r | xxd
done
```

Each iteration shows up to 10 bytes, stops on Enter.

---

## Caveats

**No character-level filtering.** `-c`, `-C`, `-U`, `-L` are silently
ignored. If you need to filter, do it in the shell on the captured output,
or use normal grabchars mode.

**Byte count, not key count.** `-n 3` captures exactly 3 bytes. An arrow
key fills the quota; a plain letter does not. Design scripts accordingly.

**No echo.** The terminal is already in raw mode (as in all grabchars
modes). Characters are not echoed as they arrive. If you want the user to
see what they're pressing, handle it in the calling script after grabchars
returns.

**ESC ambiguity at `-n 1`.** If you collect exactly 1 byte and the user
presses an arrow key, you get `0x1B` and the remaining bytes (`5b 41` for
Up) are left in the terminal buffer. The next program to read from the
terminal will see them. Use a larger `-n` when capturing sequences, or use
`-r` so Enter flushes leftover input.

**Terminal variation.** The byte sequences for special keys are defined by
the terminal emulator, not the OS. They vary across terminals, terminal
multiplexers (tmux, screen), and SSH sessions. Test with the actual target
terminal.

**select / mask modes.** `-R` is incompatible with `select`, `select-lr`,
and `-m`. If those modes are detected they branch before the raw-mode
block, so `-R` is silently ignored in those cases.
