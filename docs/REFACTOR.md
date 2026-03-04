# grabchars Refactoring Plan

Repeated code patterns identified for cleanup in a future pass.
None of these change behavior — they are pure extract-function refactors.

**Estimated reduction:** ~200–300 lines

---

## 1. Output routing boilerplate (HIGH)

**File:** `output.rs` — `output_char`, `output_str`, `output_bytes`, `emit_json`

The same stderr/stdout/both branching logic is copy-pasted across all four
functions. Each one repeats: if `to_stderr`, write to stderr and flush; if
`both`, also write to stdout and flush; else vice versa.

**Fix:** Extract a helper that takes a write closure and the routing flags:

```rust
fn write_to_output(data: &[u8], to_stderr: bool, both: bool)
```

~120 lines → ~30.

---

## 2. Timeout + default fallback (HIGH)

**Files:** `main.rs` (×2), `mask.rs` (×1), `select.rs` (×2) — 7 occurrences total

A 10–12 line block that:
1. Checks `TIMED_OUT`
2. If default is set and buffer is empty, outputs the default and exits
3. Otherwise outputs partial result and exits with code 254

**Fix:** Extract a shared function:

```rust
fn handle_timeout(
    buffer: &[u8], flags: &Flags, default: &Option<String>,
    output_to_stderr: bool, orig_termios: &libc::termios,
) -> !
```

~70+ lines eliminated.

---

## 3. Character filtering & case mapping (MEDIUM)

**Files:** `main.rs` (×2), `mask.rs` (×1), `select.rs` (×2) — 4–5 occurrences

The `-c`/`-C` include/exclude filter check plus `-U`/`-L` case conversion
is near-identical everywhere a character is accepted.

**Fix:** Extract:

```rust
fn apply_char_filters(
    ch: char, flags: &Flags,
    valid_pattern: &Option<Regex>, exclude_pattern: &Option<Regex>,
) -> Option<char>  // None = rejected, Some(ch) = accepted (with case applied)
```

~40 lines eliminated.

---

## 4. Filter recompute + re-render in select modes (MEDIUM)

**File:** `select.rs` — appears ~10 times between `run_select` and `run_select_lr`

The block that recomputes filtered matches, clamps `match_idx`, and
re-renders the list is repeated after every input event that changes state.

**Fix:** Extract:

```rust
fn recompute_and_render(
    filter: &[u8], options: &[String], match_idx: &mut usize,
    flags: &Flags, prev_width: &mut usize, is_lr: bool,
)
```

~30 lines eliminated.

---

## 5. Default-on-Enter exit (MEDIUM)

**File:** `main.rs` — 4 occurrences

When Enter is pressed (or first char arrives) with a default set and an
empty buffer, the code outputs the default and exits. Same ~10-line block
repeated four times.

**Fix:** Extract:

```rust
fn try_default_exit(
    flags: &Flags, default: &Option<String>, num_read: usize,
    output_to_stderr: bool, orig_termios: &libc::termios,
) -> bool
```

Returns `true` if it handled the exit, `false` to continue.

---

## 6. Default option search in select lists (MEDIUM)

**File:** `select.rs` — 3 occurrences

The loop that finds a default option by case-insensitive match against
the options list is repeated in `run_select` (×1) and `run_select_lr` (×2).

**Fix:** Extract:

```rust
fn find_default_index(
    default: &Option<String>, options: &[String], matches: &[usize],
) -> usize
```

~15 lines eliminated.

---

## 7. Escape key handling (LOW)

**Files:** `main.rs` (×2), `mask.rs` (×1), `select.rs` (×2)

The `KeyInput::Escape` match arm checks `flags.esc_code` and either
continues, exits, or does nothing. The core structure repeats with minor
variation per mode.

**Fix:** Extract a helper returning `Option<i32>` (exit code) or `None`
(continue the loop).

~20 lines eliminated.
