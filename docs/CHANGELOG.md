# Changelog

All notable changes to grabchars are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

---

## [Unreleased] (v2.1 branch)

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
- `docs/JSON-OUTPUT.md` — full JSON output reference
- `docs/FILTER-FLAG.md` — filter style reference
- `tests/13_escape.sh` — ESC bail flag tests
- `tests/14_json.sh` — JSON output tests

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

[Unreleased]: https://github.com/DanielSmith/grabchars/compare/v2.0.1...HEAD
[2.0.1]: https://github.com/DanielSmith/grabchars/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/DanielSmith/grabchars/releases/tag/v2.0.0
