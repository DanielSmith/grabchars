# grabchars Security Notes

> **Disclaimer:** grabchars is an open source project that has not been through
> an extensive security audit. As is the case with any command-line tool, use
> at your own risk. The findings below were flagged by a casual AI-assisted
> audit of the source code and should not be taken as a comprehensive or
> authoritative security assessment.

grabchars is a small, purpose-built terminal utility. Its attack surface is
narrow: it reads bytes from a TTY, optionally filters them, and writes them to
stdout or stderr. This document covers what Rust's memory safety eliminates,
what genuine concerns remain, and what script authors should know.

---

## What Rust eliminates

Compared to the original 1988 C implementation (which used K&R syntax, fixed
buffers, `re_comp`/`re_exec`, and BSD signal conventions), Rust's ownership and
type system removes entire categories of vulnerability:

| C vulnerability class | Status in Rust port |
|-----------------------|---------------------|
| Buffer overflows | Eliminated — `Vec<u8>` is bounds-checked; no fixed-size char buffers |
| Use-after-free | Eliminated — ownership prevents freed-memory access |
| Null pointer dereference | Eliminated — `Option<T>` with no implicit null |
| Data races | Eliminated — `AtomicBool`/`AtomicI32` for shared signal state |
| Format string bugs | Eliminated — Rust format strings are type-checked at compile time |
| Uninitialized memory | Eliminated — all variables initialized; `mem::zeroed()` used only for POD C structs |

---

## Unsafe code audit

grabchars has five `unsafe` blocks. All are narrow FFI calls with clearly
satisfied preconditions.

### `input.rs` — `read_byte()`
```rust
libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, 1)
```
Reading 1 byte into a 1-byte stack buffer. The buffer pointer is valid, the
length matches, and the return value is fully checked. No overflow possible.

### `input.rs` — `byte_available()`
```rust
libc::poll(&mut pfd, 1, timeout_ms)
```
Passing a valid, stack-allocated `pollfd` struct. Poll count is 1, matching
the struct. Return value is checked before use. Safe.

### `term.rs` — `init_term()`
```rust
libc::tcgetattr(0, &mut orig);
libc::tcsetattr(0, libc::TCSAFLUSH, &raw);
```
Standard POSIX termios calls on fd 0 (stdin). If fd 0 is not a TTY,
`tcgetattr` returns -1 (error silently ignored) but causes no undefined
behaviour. Safe.

### `main.rs` — `setup_alarm()`
```rust
libc::sigaction(libc::SIGALRM, &sa, std::ptr::null_mut());
libc::alarm(secs);
```
`sigaction` with a zeroed-and-initialized `sigaction` struct. `sa_flags = 0`
is intentional — it prevents `SA_RESTART`, ensuring `read()` returns `EINTR`
on all POSIX systems (both macOS and Linux default to `SA_RESTART` with
`signal()`). Safe and purposeful.

### `main.rs` — `signal_handler()`
```rust
libc::_exit(EXIT_STAT.load(Ordering::Relaxed));
```
`_exit` is async-signal-safe. The atomic load is safe in signal context.
However, this handler calls `term::restore_saved()` before `_exit` — see
defect #1 below.

---

## Known defects

### Defect 1: Mutex in signal handler (`term.rs:66`)

`signal_handler()` calls `restore_saved()`, which calls `SAVED_TERMIOS.lock()`.
A `Mutex` is **not async-signal-safe** under POSIX. If a signal arrives while
the main thread holds the lock (a window of roughly 10–100 nanoseconds during
`init_term()`), the handler will block waiting for the lock, which is already
held by the interrupted thread — a deadlock.

**Practical risk:** Very low. The lock is held for a handful of instructions
during startup only. No user-visible failure has been observed. The original C
used a plain global `struct termios`, which has no locking — the Mutex is a
safety improvement but introduces this specific edge case.

**Correct fix:** Replace the Mutex with a raw static and an `AtomicBool` guard,
or use a signal-safe copy mechanism (atomic store of each field, or write only
once before signals are enabled). Tracked for a future release.

---

### Defect 2: Possible integer truncation on very long `-d` string (`output.rs:70`)

```rust
EXIT_STAT.store(default_string.len() as i32, Ordering::Relaxed);
```

If a caller supplies a `-d` string longer than `i32::MAX` bytes (2 GB), the
cast wraps and the exit code is wrong. In practice no shell script will pass a
2 GB default string, but the cast is formally incorrect. It should be clamped
to 253 (the maximum meaningful exit code for grabchars).

---

## Terminal escape sequence output

A question that comes up with any terminal tool: can user keystrokes inject
escape sequences into the output stream?

**Answer: yes, but this is expected behaviour, not a vulnerability.**

When a user types an escape sequence (e.g., in raw mode `-R`, or as a raw
byte that passes character filtering), grabchars writes those bytes to stdout.
If the calling script then displays the captured output on a terminal without
quoting or sanitizing it, the terminal renders the escape sequences.

```bash
# Example where escape sequence would be rendered:
INPUT=$(grabchars -R -n20 -r)
echo "You typed: $INPUT"      # if $INPUT contains ESC[31m, terminal turns red
```

The escape sequences here come from the user at the keyboard. If the attacker
is at the keyboard, they have full terminal access by other means. The risk
is only meaningful if grabchars output is displayed to a *different* user than
the one who typed it — which would be an unusual deployment.

**Mitigation for script authors:** Use `printf '%q' "$INPUT"` or pass output
through a sanitizer before displaying it to another party.

---

## ReDoS in mask mode custom character classes

The `-m` mask flag compiles user-supplied bracket expressions (e.g., `[a-z]`)
into `regex` crate patterns. The `regex` crate uses a linear-time NFA engine
and is **not** susceptible to catastrophic backtracking in the general case.
However, when multiple quantified elements appear adjacent in a mask, the
resulting combined pattern may expose exponential behaviour in edge cases.

**Example of a problematic mask:**
```bash
grabchars -m '[a-z]*[a-z]*[a-z]*[a-z]*' -r
```

This is only exploitable if the mask string is constructed from untrusted
input — which would be an unusual script design. The mask string is supplied
by the script author, not the user typing keystrokes.

**Mitigation:** Do not construct the `-m` mask string from user-controlled input.

---

## Signal handling gaps: SIGHUP and SIGTERM

grabchars handles SIGINT, SIGQUIT, and SIGTSTP (restores terminal before
exiting). It does not handle SIGHUP or SIGTERM.

If grabchars receives one of these signals (e.g., the user closes the terminal
window, or a parent process sends `kill`), the process exits without restoring
terminal settings. The terminal is left in raw mode (echo disabled, canonical
mode disabled) until the user runs `reset` or `stty sane`.

SIGKILL cannot be caught by any program and always has this behaviour.

**Mitigation:** The calling script can guard against this:
```bash
trap 'stty sane 2>/dev/null' EXIT HUP TERM
```

---

## Shell quoting

grabchars output may contain spaces, newlines, glob characters, or (in raw
mode) arbitrary bytes. Always quote the output when using it in shell commands:

```bash
# Correct
INPUT=$(grabchars -n20 -r)
process "$INPUT"

# Dangerous — word splitting and glob expansion
process $INPUT
```

This is standard shell scripting practice and not specific to grabchars.

---

## Threat model summary

| Threat | Assessment |
|--------|-----------|
| Local attacker at keyboard, normal mode | No meaningful escalation possible; attacker already controls the terminal |
| Malicious `-m` / `-c` flag from a script | Script author controls the flag; only a concern if flags are built from external untrusted input |
| Output displayed to a third party | Escape sequences should be sanitized before re-display; same as any user-input echo |
| Privilege escalation | Not possible — grabchars uses no elevated privileges, no setuid, no child processes |
| Memory corruption | Eliminated by Rust's ownership model; one `unsafe` block per syscall, each audited above |
| SIGKILL terminal corruption | POSIX limitation; not fixable; mitigated by shell `trap` in calling script |

---

---

## Scripting grabchars securely

grabchars is designed to be embedded in shell scripts. The concerns below are
standard shell scripting hygiene, but several of them interact with grabchars
in ways that are not immediately obvious.

---

### Check that grabchars is installed before relying on it

A missing binary produces an error message on stderr and exits with a shell
error code, not the 255 that your script expects from grabchars itself.

```bash
if ! command -v grabchars >/dev/null 2>&1; then
    echo "grabchars is required but not installed." >&2
    exit 1
fi
```

For scripts distributed to others, consider using an absolute path or checking
the version:

```bash
GRABCHARS="${GRABCHARS:-/usr/local/bin/grabchars}"
[[ -x "$GRABCHARS" ]] || { echo "grabchars not found at $GRABCHARS" >&2; exit 1; }
```

Storing the path in a variable also lets users override it:
`GRABCHARS=/opt/bin/grabchars ./myscript.sh`.

---

### Check that a TTY is available

grabchars requires stdin to be a real terminal. In CI/CD pipelines, cron jobs,
or when a script is piped through `ssh`, stdin may not be a TTY. Calling
grabchars in a non-TTY context silently fails or produces garbage.

```bash
if ! [[ -t 0 ]]; then
    echo "This script requires an interactive terminal." >&2
    exit 1
fi
```

---

### The `set -e` / `errexit` gotcha

grabchars exit codes are **counts, not success/failure flags**. Exit code 1
means "one character was read successfully". In a script using `set -e`
(exit on any non-zero status), a successful single-character read will
terminate the script.

```bash
set -e

# WRONG — this kills the script on a successful single-char read
CHOICE=$(grabchars -c yn -q "Continue? ")

# CORRECT — capture first, protect the exit code check
CHOICE=$(grabchars -c yn -q "Continue? ") || true
EXIT_CODE=$?
```

Or disable `errexit` around the call:

```bash
set +e
CHOICE=$(grabchars -c yn -q "Continue? ")
EXIT_CODE=$?
set -e
```

Or avoid `set -e` entirely for scripts that use grabchars heavily — it is a
blunt instrument and its interaction with subshells is notoriously subtle.

---

### Always capture the exit code immediately

The exit code of `$()` substitution is discarded once any other command runs.
Capture it on the very next line:

```bash
CHOICE=$(grabchars -c yn -d n -t 10 -q "Continue? [y/N] ")
EXIT_CODE=$?   # capture NOW, before anything else

if   [[ $EXIT_CODE -eq 255 ]]; then
    echo "Cancelled." >&2; exit 1
elif [[ $EXIT_CODE -eq 254 ]]; then
    echo "Timed out — using default." >&2
elif [[ $EXIT_CODE -eq 0 ]];  then
    echo "No input received." >&2; exit 1
fi
# EXIT_CODE 1–253: that many characters were read
```

The full exit code convention:

| Code | Meaning |
|------|---------|
| 0 | No input (e.g. `-r` then Enter immediately with no chars and no `-d`) |
| 1–253 | That many characters (or bytes in `-R` mode) were successfully read |
| 254 | Timeout with no default set |
| 255 | Escape pressed, bad flags, or other error |

---

### Use `-c` and `-m` as input validation, not just UX

`-c` and `-m` are commonly used to improve user experience (only accept
vowels, auto-insert phone number punctuation), but they are also the only
validation layer between keystroke input and the rest of your script. A
character that passes `-c` is guaranteed to match your character class.

```bash
# Without -c: CHOICE could be anything, including newlines or control chars
CHOICE=$(grabchars -q "Choice: ")

# With -c: CHOICE is guaranteed to be one of a, b, or c
CHOICE=$(grabchars -c abc -q "Choice [a/b/c]: ")
```

Similarly, mask mode guarantees the output format:

```bash
# Output is guaranteed to be "NNN-NN-NNNN" (digits only, no other characters)
SSN=$(grabchars -m "nnn-nn-nnnn" -q "SSN: ")
```

This lets you pass the output to other tools with more confidence.

---

### Always quote grabchars output

grabchars output may contain spaces, glob characters, or (in raw mode)
arbitrary bytes. Unquoted variables are subject to word splitting and
pathname expansion.

```bash
INPUT=$(grabchars -n20 -r -q "Filename: ")

# Dangerous — word splitting, glob expansion
cp $INPUT /backup/

# Safe
cp "$INPUT" /backup/
```

This applies everywhere the variable is used: `[[ ]]` tests, command
arguments, assignments to other variables, and here-documents.

---

### Never `eval` grabchars output

```bash
# Never do this — arbitrary code execution if user types e.g. "; rm -rf ~"
eval "$(grabchars -n50 -r -q "Command: ")"

# Never do this either
CMD=$(grabchars -n50 -r -q "Command: ")
eval "$CMD"
```

If you need the user to select a command to run, use `select` mode with a
fixed list of options and dispatch on the exit code or a pre-approved string:

```bash
grabchars select "deploy,rollback,status" -q "Action: " > /dev/null
case $? in
    0) deploy ;;
    1) rollback ;;
    2) status ;;
    *) echo "Cancelled." ;;
esac
```

---

### Validate the length and content of captured output

Even with `-n`, check that you got what you expected before acting on it.
Grabchars may exit before collecting all characters (timeout, escape, EOF),
and the character count exit code is the definitive indicator — but verifying
the output itself adds a second layer.

```bash
PIN=$(grabchars -n4 -E0 -q "PIN: ")
EXIT_CODE=$?

# Verify we got exactly 4 chars and they are all digits
if [[ $EXIT_CODE -ne 4 || ! "$PIN" =~ ^[0-9]{4}$ ]]; then
    echo "Invalid PIN." >&2
    exit 1
fi
```

---

### Be careful with shell and environment variables in flag arguments

Flags like `-c`, `-C`, `-d`, `-m`, `-p`, `-q`, and `-n` take arguments.
If those arguments come from variables, they must be quoted and validated.

**Word splitting on unquoted variables:**

```bash
VALID="a b c"  # spaces in the value
grabchars -c $VALID   # becomes: grabchars -c a b c — three separate args, wrong
grabchars -c "$VALID" # becomes: grabchars -c "a b c" — one arg, correct
```

**Injection via unquoted variable in a flag argument:**

```bash
# If FILTER is externally controlled and contains " -n 1 -s"
grabchars -c $FILTER -n5   # may parse as: -c "" -n 1 -s -n5
grabchars -c "$FILTER" -n5 # safe: FILTER passed as one argument to -c
```

Even with quoting, do not pass externally-controlled input directly to `-m`
(mask) or `-c` (filter). Validate or whitelist the value first:

```bash
# Validate that MASK only contains known safe characters before using it
if [[ ! "$MASK" =~ ^[UlcnxpW.*?+\[\]-]+$ ]]; then
    echo "Invalid mask." >&2; exit 1
fi
grabchars -m "$MASK" -q "Input: "
```

**Environment variable leakage:**

If your script exports variables into the environment and then calls grabchars
via a wrapper, those variables are visible to the wrapper. This is standard
Unix behaviour but worth keeping in mind in privilege-sensitive contexts.

---

### Sanitize output before displaying it to others or using it in commands

If the output of grabchars will be displayed in a context other than the
user's own terminal (logged, sent to another user, used in a filename or URL),
sanitize it first. Raw mode (`-R`) in particular can produce arbitrary bytes
including ANSI escape sequences.

```bash
INPUT=$(grabchars -R -n20 -r -q "Key: ")

# Sanitize to printable ASCII before logging or displaying
SAFE_INPUT=$(printf '%s' "$INPUT" | tr -cd '[:print:]')

# Or for filenames — keep only safe characters
FILENAME=$(printf '%s' "$INPUT" | tr -cd 'A-Za-z0-9._-')
```

Normal mode with `-c` already constrains the character set, making this
sanitization largely unnecessary for well-filtered input.

---

### Protect terminal state with a trap

If your script might be interrupted (SIGTERM, SIGHUP, unexpected exit),
add a trap to restore the terminal in case grabchars was mid-execution:

```bash
cleanup() {
    stty sane 2>/dev/null
}
trap cleanup EXIT HUP TERM INT

# ... rest of script
```

This is belt-and-suspenders: grabchars already restores the terminal on
SIGINT/SIGQUIT/SIGTSTP, but does not handle SIGHUP or SIGTERM.

---

### A complete example: secure y/n prompt

Pulling it all together:

```bash
#!/usr/bin/env bash
set -uo pipefail

# Ensure grabchars is available
command -v grabchars >/dev/null 2>&1 || { echo "grabchars required" >&2; exit 1; }

# Ensure we have a terminal
[[ -t 0 ]] || { echo "Interactive terminal required" >&2; exit 1; }

# Restore terminal on any exit
trap 'stty sane 2>/dev/null' EXIT HUP TERM

# Prompt — capture exit code immediately, protect against set -e with || true
ANSWER=$(grabchars -c yn -d n -t 30 -q "Delete all logs? [y/N] " 2>/dev/tty) || true
EXIT_CODE=$?

# Handle special exits
if   [[ $EXIT_CODE -eq 255 ]]; then
    echo "Cancelled." >&2; exit 1
elif [[ $EXIT_CODE -eq 254 ]]; then
    echo "Timed out — defaulting to 'n'." >&2
    ANSWER="n"
fi

# Validate the captured value regardless
if [[ "$ANSWER" != "y" && "$ANSWER" != "n" ]]; then
    echo "Unexpected input." >&2; exit 1
fi

if [[ "$ANSWER" == "y" ]]; then
    echo "Deleting logs..."
    rm -f /var/log/myapp/*.log
else
    echo "Cancelled."
fi
```

---

## Reporting issues

Please report security concerns via
[GitHub Issues](https://github.com/DanielSmith/grabchars/issues).
For sensitive issues, use the private vulnerability reporting feature on the
GitHub repository page.
