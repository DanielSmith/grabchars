# grabchars Refactoring — Plan vs. Outcome

Repeated code patterns identified for cleanup.
None of these change behavior — they are pure extract-function refactors.

**Original estimate:** ~200–300 lines reduced
**Actual reduction:** ~155 lines across 4 completed refactors

---

## Results

| #  | Refactor                           | Status                                          | Lines saved |
|----|------------------------------------|-------------------------------------------------|-------------|
| 1  | Output routing                     | Done                                            | ~45         |
| 2  | Timeout + default fallback         | Skipped — blocks too different per mode          | —           |
| 3  | Character filtering & case mapping | Done                                            | ~45         |
| 4  | Filter recompute + re-render       | Done                                            | ~50         |
| 5  | Default-on-Enter exit              | Skipped — not worth the parameter complexity     | —           |
| 6  | Default option search              | Done                                            | ~15         |
| 7  | Escape key handling                | Skipped — per-mode differences too significant   | —           |

---

## Completed

### 1. Output routing boilerplate (HIGH) — DONE

**File:** `output.rs` — `output_char`, `output_str`, `output_bytes`, `emit_json`

The same stderr/stdout/both branching logic was copy-pasted across all four
functions. Extracted a `write_routed` helper that takes a write closure and
the routing flags:

```rust
fn write_routed(to_stderr: bool, both: bool, emit: impl Fn(&mut dyn Write))
```

Each public function became a one-liner. `emit_json` routing collapsed from
14 lines to 1.

### 3. Character filtering & case mapping (MEDIUM) — DONE

**Files:** `main.rs` (×3), `mask.rs` (×1), `select.rs` (×2) — 6 call sites

Extracted `apply_char_filters()` in `main.rs` to handle the `-c`/`-C`
include/exclude filter check plus `-U`/`-L` case conversion:

```rust
pub fn apply_char_filters(
    ch: char, flags: &Flags,
    valid_pattern: &Option<Regex>, exclude_pattern: &Option<Regex>,
) -> Option<char>  // None = rejected, Some(ch) = accepted (with case applied)
```

**Note:** This unified an inconsistency — `mask.rs` originally applied case
mapping *before* the filter, while `main.rs` did filter first. The extracted
function uses filter-first-then-case for all modes, matching `main.rs`
behavior and the existing test expectations (`-U -c'[a-z]'`).

### 4. Filter recompute + re-render in select modes (MEDIUM) — DONE

**File:** `select.rs` — 10 call sites (6 in `run_select`, 4 in `run_select_lr`)

Extracted `recompute_and_render` with a render closure parameter to handle
the difference between vertical and horizontal rendering:

```rust
fn recompute_and_render(
    filter: &[u8], options: &[String],
    matches: &mut Vec<usize>, match_idx: &mut usize,
    flags: &Flags,
    render: impl FnOnce(&[u8], &[String], &[usize], usize),
)
```

The Tab handler in both modes was left inline because it does custom
`match_idx` logic (finding the same option in the recomputed match list).

### 6. Default option search in select lists (MEDIUM) — DONE

**File:** `select.rs` — 4 call sites (2 initial-highlight, 2 timeout)

Two patterns existed: searching within filtered matches (initial highlight)
and searching the full options list (timeout default). Extracted both:

```rust
fn find_default_match(default: &str, options: &[String], matches: &[usize]) -> usize
fn find_default_option(default: &str, options: &[String]) -> Option<usize>
```

---

## Skipped (with rationale)

### 2. Timeout + default fallback (HIGH) — SKIPPED

On inspection, the "repeated" timeout blocks diverge significantly per mode:
- Different return types (`process::exit` vs `return MaskResult` vs `return SelectResult`)
- Different mode strings for JSON output ("raw", "normal", "select")
- Different partial-buffer handling (raw hex-encodes, normal outputs as-is, select clears display)
- Select modes do a default-option search loop that normal/mask don't

The shared core is only ~3 lines; the surrounding logic is mode-specific.
A helper would need a complex enum return type or many parameters, making it
harder to read than the inline code.

### 5. Default-on-Enter exit (MEDIUM) — SKIPPED

Each block is ~8 lines, but a helper would require 7 parameters (flags,
default_string, num_read, mode, timed_out, output_to_stderr, orig_termios)
plus the awkward pattern of "returns false but sometimes calls process::exit
and never returns." The call sites would shrink from 8 lines to 1, but the
function itself would be 15+ lines. Net readability: worse.

### 7. Escape key handling (LOW) — SKIPPED

The `KeyInput::Escape` arms differ enough per mode that a shared helper
would need mode-specific callbacks:
- Mask mode erases the displayed buffer before exiting
- Select modes clear the select line
- Normal mode just exits

Each block is only 6–8 lines. Not worth the abstraction overhead.
