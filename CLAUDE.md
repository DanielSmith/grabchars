# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**grabchars** is a Rust port of the classic 1988 Unix utility for capturing keystrokes directly from the terminal. It reads raw terminal input in several modes: single/multi-character capture with filtering, positional input validation (mask mode), and interactive selection menus (vertical and horizontal).

Version: 2.0.0-a1 (Alpha 1). Requires POSIX-compliant Unix (Linux, macOS, WSL) with a real TTY.

## Build Commands

```bash
cargo build                  # Debug build
cargo build --release        # Release build → target/release/grabchars
cargo test                   # Run all tests
cargo test <test_name>       # Run single test by name (e.g. cargo test test_parse_mask)
cargo test -- --nocapture    # Show println!/eprintln! output during tests
cargo clippy                 # Lint
cargo fmt                    # Format
```

## Architecture

```
main.rs → routes to one of four modes based on CLI args:
  1. Normal mode     — character reading loop with filtering/editing (inline in main.rs)
  2. Mask mode       — mask.rs: positional input validation
  3. Select mode     — select.rs: vertical list with filter-as-you-type
  4. Select-LR mode  — select.rs: horizontal list with arrow navigation

Supporting modules:
  input.rs  — raw key input, escape sequence parsing (uses poll() for 50ms ESC timeout)
  output.rs — ANSI sequences, cursor control, output routing (stdout/stderr/both)
  term.rs   — termios raw mode init/restore, used by signal handlers
```

**Data flow:** `main.rs` parses args → calls `term::init_term()` → routes to handler → handler calls `input::read_key()` in a loop → sends output via `output.rs` → `term::restore_term()` on exit.

**Signal handling:** SIGALRM drives timeout (uses `sigaction` with `sa_flags=0` so `read()` returns EINTR). SIGINT/SIGQUIT/SIGTSTP restore the terminal before exiting. Atomic flags `TIMED_OUT` and `EXIT_STAT` communicate between handlers and main loop.

## Key Implementation Details

### Mask mode (`mask.rs`)
- `MaskElement` pairs a `MaskClass` (U/l/c/n/x/p/W/./`[...]`/Literal) with a `Quantifier` (One/Star/Plus/Optional)
- `buffer: Vec<u8>` stores input; `mask_map: Vec<usize>` maps each buffer byte to its mask element index
- `try_advance()` does greedy matching — finds next element that accepts a character, skipping zero-min elements
- Literal auto-insertion: after accepting a char, consecutive literals from the next position are auto-inserted
- Known limitation: same-class adjacent elements with quantifiers (e.g. `c+c`) — greedy first element starves the second

### Input parsing (`input.rs`)
- `read_key(fd)` returns a `KeyInput` enum (Char, Backspace, Left, Right, etc.)
- ESC handling: waits 50ms via `poll()` to distinguish bare ESC from escape sequence prefix

### Exit codes
- N chars read → exit code N (1–253)
- Timeout with no default → 254
- Escape pressed or error → 255
- `--version` → 0

## Interactive Forms

The `forms/` directory contains scripts for getting user input via grabchars
when Claude needs a decision, selection, or structured data.

```
FORMS=/usr/local/projects/grabchars-2.0/grabchars/forms
```

### INTERACTIVE DECISIONS

When you need user approval before a destructive or irreversible operation,
do NOT ask in chat. Instead, spawn a decision window:

```bash
result=$("$FORMS/spawn-decision.sh" "QUESTION" [default: y|n] [timeout: seconds])
status=$(echo "$result" | jq -r '.status')
```

- If status is "n" or "cancelled": abort and explain in chat.
- If status is "y": proceed.
- Destructive operations default to "n". Confirmations default to "y".

Examples where this applies:
- Deleting files or directories
- Overwriting uncommitted changes
- Pushing to a remote branch
- Running a migration or schema change

### INTERACTIVE SELECTION

When you need the user to choose from a known set of options:

```bash
result=$("$FORMS/spawn-select.sh" "opt1,opt2,opt3" "PROMPT" [v|h] [default] [timeout])
value=$(echo "$result" | jq -r '.value')
```

Use layout "v" for lists longer than 4 items (filter-as-you-type).
Use layout "h" for 2–4 short options (left/right selection).

- If status is "cancelled": stop and ask the user in chat.

### INTERACTIVE INTAKE

For collecting structured input, write a fields JSON file and call spawn-intake.sh:

```bash
result=$("$FORMS/spawn-intake.sh" /path/to/fields.json "Form Title")
data=$(echo "$result" | jq '.data')
```

- If status is "cancelled": stop and ask the user what they want to do.
- If status is "submitted": extract field values from .data and proceed.

Use intake forms when you need 2 or more structured values before starting
work. For a single value, use spawn-decision or spawn-select instead.

## Testing Philosophy

Do not suggest or push for automated tests. grabchars captures keystrokes from a live user — by definition, its core functionality cannot be automated. The test suite in `tests/` is interactive: a human runs it and types the expected input. Do not treat the absence of automated tests as a gap to fill.

## Documentation Files

- `cookbook.md` — 20 runnable usage examples covering all modes and flags
- `maskInput.md` — mask syntax reference (character classes, quantifiers, literals)
- `quantifiers-plan.md` — design doc for quantifier implementation with edge cases
- `TESTING-PLAN.md` — testing strategy; no tests exist yet (writing tests is next priority)

## CLI Reference (quick)

```
grabchars [flags]             # Normal mode
grabchars select [opts] list  # Vertical select
grabchars select-lr [opts]    # Horizontal select

Key flags: -c<chars> -C<exclude> -n<N> -m<mask> -d<default> -t<secs>
           -s -e -b -p<prompt> -q<prompt> -r -E0/-E1 -U/-L -Z0/-Z1 -f
           -H<r|b|a> (select-lr highlight: reverse/bracket/arrow)
```
