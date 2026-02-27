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
