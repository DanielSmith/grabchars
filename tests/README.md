# grabchars Test Suite

## Why these tests are interactive

grabchars reads raw keystrokes **directly from the terminal** — it opens
`/dev/tty`, puts it into raw mode, and reads bytes before the OS line
discipline sees them. There is no stdin pipe to feed, no key-event API
to call, and no way to inject synthetic keystrokes through a normal file
descriptor.

Automated approaches exist (pseudo-terminals via `openpty`, `expect`,
`pexpect`, the `pty` crate) but they add significant complexity: the
pseudo-terminal must correctly emulate the terminal the binary expects,
signal delivery through the pty is tricky, and subtle timing issues
arise with escape-sequence timeouts. For a utility this size, that
overhead is not justified.

These tests are therefore **interactive acceptance tests**. Each test:

1. Describes what it is testing and what behavior to expect.
2. Shows the exact `grabchars` command being run — copy-paste friendly.
3. Tells you precisely what to type (or not to type).
4. Captures the output and exit code, then checks them automatically.

A human provides the input; the script does the verification. The tests
double as a live demo of every feature.

## What gets tested automatically

Some behaviors require no keystrokes at all and are fully automated:

- `--version` flag output
- `-h` help flag exit code
- `-t` timeout with `-d` default (fires on its own)
- `-Z0` trailing-newline suppression (compares two automated runs)

These still live in the interactive test files so everything is in one
place and runs in the same harness.

## Running the tests

Build the release binary first:

```bash
cargo build --release
```

**Option 1 — interactive menu (recommended)**

`menu.sh` uses `grabchars select-lr` to let you pick which test group
to run. Use ← → to move through the list, type to jump to a group by
name, and press Enter to launch it. This is also a live demonstration
that grabchars is useful as a menu driver in real shell scripts.

```bash
bash tests/menu.sh
```

**Option 2 — run everything manually**

`run_tests.sh` walks through all test groups in order, pausing between
each one so you can read the results. Pass numeric prefixes to run
specific groups only.

```bash
bash tests/run_tests.sh           # all groups
bash tests/run_tests.sh 01 05 09  # only groups 01, 05, and 09
```

**Option 3 — run a single group directly**

```bash
bash tests/09_mask.sh
```

## Test file layout

| File              | What it covers                                                |
| ----------------- | ------------------------------------------------------------- |
| `01_basic.sh`     | Default single-char capture, version/help flags               |
| `02_filter.sh`    | `-c` include filter, `-C` exclude filter                      |
| `03_count.sh`     | `-n` multi-char count, `-r` return-exits                      |
| `04_default.sh`   | `-d` default value on Enter                                   |
| `05_timeout.sh`   | `-t` timeout, with and without default                        |
| `06_case.sh`      | `-U` uppercase, `-L` lowercase mapping                        |
| `07_output.sh`    | `-e` stderr, `-b` both, `-s` silent, `-p`/`-q` prompts, `-Z0` |
| `08_editing.sh`   | `-E0`/`-E1` editing, backspace, cursor keys, Ctrl-K/W         |
| `09_mask.sh`      | `-m` mask mode: classes, literals, quantifiers, backspace     |
| `10_select.sh`    | Vertical `select` mode: filter, default, timeout, `--file`    |
| `11_select_lr.sh` | Horizontal `select-lr` mode: arrows, wrap, highlight styles   |
| `12_raw.sh`       | `-R` raw mode: byte capture, escape sequences, `-r`/`-d`/`-s`/`-e`/`-b`, ignored flags |

## Helper infrastructure

`helpers.sh` — sourced by every test file. Provides:

- Color variables (`RED`, `GREEN`, `CYAN`, `BOLD`, `DIM`, `RESET`)
- `test_start` / `pass` / `fail` / `skip` — test lifecycle
- `show_command` — prints the `grabchars` command being run
- `instruct` — tells the human what to type
- `watch_note` — notes for automated/watch-only tests
- `check_output` / `check_exit` / `run_and_check` — assertion helpers
- `print_summary` — tallies and machine-readable `GRABCHARS_TOTALS` line

`run_tests.sh` / `menu.sh` — two ways to drive the suite; use whichever
fits your workflow:

- `run_tests.sh` runs groups sequentially with a pause between each.
  Pass numeric prefixes to run a subset (`01 05 09`), or no arguments
  for all groups. Tallies results into a grand summary at the end.
- `menu.sh` presents an interactive `grabchars select-lr` list so you
  can pick one group at a time. Also a live demo of grabchars as a
  menu driver in shell scripts.
