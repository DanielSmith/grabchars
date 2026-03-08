# Changelog

All notable changes to grabchars are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

---

## [2.1.0] — 2026-03-07

### Added
- **JSON output (`-J`)** — structured JSON with value, exit code, status, mode,
  and metadata fields. Compact (`-J` / `-J1`) or pretty-printed (`-Jp`).
  Replaces boilerplate `$?` juggling in scripts. See `docs/JSON-OUTPUT.md`.
- **ESC bail flag (`-B`)** — configurable exit code on Escape: `-B0` disables
  ESC entirely, `-B1`–`-B253`/`-B255` exit with the given code. Lets scripts
  distinguish "user cancelled" from "bad invocation" (both 255 by default).
- **Select filter styles (`-F`)** — fuzzy/subsequence (`-Ff`) and contains
  (`-Fc`) matching in addition to the default prefix (`-Fp`). All three are
  case-insensitive.
- **Flush flag (`-f`) documented** — flushes type-ahead input before reading.
  Present since the original 1988 code but never documented until now.
- `docs/JSON-OUTPUT.md` — full JSON output reference
- `docs/FILTER-FLAG.md` — filter style reference
- `tests/13_escape.sh` — ESC bail flag tests
- `tests/14_json.sh` — JSON output tests

### Changed (internal)
- **Code refactoring** — four extract-function refactors reducing ~155 lines of
  duplicated code with no behavior changes:
  - Output routing (`output.rs`): extracted `write_routed` helper, collapsing
    repeated stderr/stdout/both branching in `output_char`, `output_str`,
    `output_bytes`, and `emit_json`.
  - Character filtering & case mapping (`main.rs`): extracted `apply_char_filters()`
    shared by normal, mask, and select modes. Unified an ordering inconsistency —
    all modes now apply filter-first, then case mapping.
  - Filter recompute & re-render (`select.rs`): extracted `recompute_and_render`
    with a render closure, replacing 10 duplicated call sites across vertical
    and horizontal select.
  - Default option search (`select.rs`): extracted `find_default_match` and
    `find_default_option`, replacing 4 inline search loops.
- See `docs/REFACTOR.md` for the full plan-vs-outcome breakdown.

### Fixed
- Test suite improvements: fixed output capture in mask tests (`-b` flag),
  corrected select exit code expectations (0-based index), fixed `-Z0` test
  to use byte-count comparison, bumped raw-mode timeouts, added fuzzy matching
  to test menu.

---

## [2.0.1] — 2026-02-28

### Fixed
- Signal handler casts updated for Rust 2024 edition lint.
- `select-lr` Left/Right navigation fix.
- Non-edit mode (`-E0`) backspace handling fix.

### Added
- `--file` flag for `select-lr` mode (load options from file, one per line).
- Pre-built binary for armv7 (Raspberry Pi).
- Homebrew tap: `brew install DanielSmith/grabchars/grabchars`.
- AUR packages: `grabchars` (source) and `grabchars-bin` (pre-built).
- GitHub Actions release workflow (builds 5 binaries on tag push).
- Interactive forms system (`forms/`) for Claude Code integration.

### Changed
- Release binaries are now stripped (`strip = true` in Cargo.toml).

---

## [2.0.0] — 2026-02-26

### Added
- Complete Rust rewrite of the 1988 C utility.
- Single/multi-character capture with character filtering (`-c`, `-C`).
- Line editing with Emacs keybindings (auto-enabled for `-n > 1`).
- Mask mode (`-m`) — positional input validation with auto-inserted literals
  and quantifiers (`*`, `+`, `?`).
- Vertical select (`select`) — filter-as-you-type list selection.
- Horizontal select (`select-lr`) — inline left/right selection with
  configurable highlight styles (`-H`).
- Raw byte mode (`-R`) — capture bytes as-is, no escape-sequence parsing.
- Case mapping (`-U` / `-L`), silent mode (`-s`), output routing (`-e` / `-b`).
- Trailing newline control (`-Z0` / `-Z1`).
- Timeout (`-t`) with optional default (`-d`).
- POSIX signal handling (SIGALRM, SIGINT, SIGQUIT, SIGTSTP).

[2.1.0]: https://github.com/DanielSmith/grabchars/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/DanielSmith/grabchars/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/DanielSmith/grabchars/releases/tag/v2.0.0
