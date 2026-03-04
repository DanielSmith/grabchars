# grabchars(1) — get keystrokes directly from user

## SYNOPSIS

```
grabchars [options]
grabchars select [options] list
grabchars select-lr [options] list
```

## DESCRIPTION

**grabchars** gets characters from the user as they are typed in, without
having to wait for the return key to be pressed. Among other things, this
allows shell scripts to be written with highly interactive menus.

By default, grabchars will obtain one character from stdin, echo that
character to stdout, and return with a status of one; meaning one character
read.

In addition to the basic character-reading mode, grabchars provides a
positional mask mode (`-m`), a filter-as-you-type vertical selection menu
(`select`), and a horizontal selection menu (`select-lr`).

## OPTIONS

**`-b`**
: Output to both stdout and stderr. Useful for setting a variable in a
  shell script and echoing a keystroke to the screen at the same time.

**`-c<valid characters>`**
: Only characters in *valid characters* are accepted. Regular expressions
  such as `[a-z]` may be used to specify ranges. All other characters are
  ignored.

**`-C<excluded characters>`**
: The inverse of `-c`. Rejects characters that match the pattern; accepts
  everything else. Uses the same character class syntax as `-c`. Both flags
  may be combined: a character must match `-c` AND not match `-C`.

**`-d<char(s)>`**
: Default char or string to output if the user hits RETURN or lets
  grabchars timeout. The status that is returned is the same as if the user
  had typed in the character or string, so this option may be used with `-s`
  (silent).

**`-e`**
: Output goes to stderr rather than stdout.

**`-E` / `-E1`**
: Enable line editing. Arrow keys, Home, End, Backspace, Delete, Ctrl-K,
  Ctrl-U, and Ctrl-W are active. When `-n` is greater than 1, editing is on
  by default. See [LINE EDITING](#line-editing).

**`-E0`**
: Disable line editing. Backspace and arrow keys are treated as raw bytes,
  not editing commands. Useful when you want to capture every keystroke
  exactly as typed.

**`-f`**
: Flush any previous input. By default, grabchars will see any characters
  present in stdin, which allows for some typeahead in shell scripts.

**`-h`**
: Help/usage screen.

**`-J` / `-J1`**
: Emit a single compact JSON object to stdout instead of the plain value.
  Contains fields: `value`, `exit`, `status`, `mode`, `timed_out`,
  `default_used`, `index`, and `filter`. See [JSON OUTPUT](#json-output).

**`-Jp`**
: Pretty-printed JSON (indented). Useful for debugging or piping to `jq`.

**`-J0`**
: Explicit off — normal behavior (the default).

**`-H<r|b|a>`**
: Highlight style for `select-lr` mode. `-Hr` uses reverse video (default);
  `-Hb` uses bracket style (`[option]`); `-Ha` uses arrow style (`>option<`).
  Bracket and arrow styles are useful on terminals where reverse video is
  unavailable or hard to see.

**`-F<p|f|c>`**
: Filter style for `select` and `select-lr` modes. `-Fp` (default) matches
  options whose names *start with* the typed text. `-Ff` uses fuzzy
  (subsequence) matching — each typed character must appear in the option *in
  order* with any characters in between; typing `so` is equivalent to the
  pattern `s.*o`. `-Fc` matches any option that *contains* the typed text as
  a contiguous substring. All three styles are case-insensitive.

**`-B<n>`**
: Controls the exit code when the user presses Escape. Without this flag,
  ESC is a no-op in normal mode and exits 255 in mask and select modes.
  `-B0` makes ESC a no-op in all modes (useful for kiosk or embedded
  workflows where the user should not be able to cancel mid-prompt). `-B1`
  through `-B253` and `-B255` cause ESC to exit with the given code, letting
  scripts distinguish "user pressed Escape" from "bad invocation" (which
  also exits 255). `-B254` is disallowed because 254 is already the
  timeout-with-no-default exit code.

**`-L`**
: Map characters to lower case.

**`-m<mask>`**
: Positional input validation. Each character position is validated against
  a corresponding element in the mask pattern. Characters that do not match
  the mask at the current position are silently rejected. Literal characters
  in the mask (parens, dashes, slashes, etc.) are auto-inserted into the
  display as the user types. The mask length determines the character count
  (like an implicit `-n`). See [MASK SYNTAX](#mask-syntax).

**`-n<number>`**
: Number of characters to read. By default, grabchars looks for one
  character.

**`-p<prompt>`**
: Sets up a prompt for the user, printed to stdout.

**`-q<prompt>`**
: Sets up a prompt for the user, printed to stderr rather than stdout. This
  is almost always the right choice in scripts, because stdout can then be
  captured with `$()`.

**`-r`**
: The RETURN key exits. Use this with the `-n` option to allow for variable
  numbers of characters to be typed in. In mask mode with quantifiers, Enter
  also accepts partial input when all required mask elements have their
  minimum counts satisfied.

**`-R`**
: Raw byte mode. Every byte read from the terminal is collected as-is,
  without escape-sequence parsing. This means arrow keys and other
  multi-byte sequences count as multiple bytes toward `-n`. The flags `-c`,
  `-C`, `-U`, `-L`, and `-E` are silently ignored in raw mode. See
  [RAW MODE](#raw-mode).

**`-s`**
: Silent. Do not output anything. Just return a status.

**`-t<seconds>`**
: Time to allow the user to respond. By default, the user can take as long
  as they want. The timeout option allows you to write shell scripts where
  you can offer some assistance if it's obvious that the user might be
  stuck. If a default (`-d`) is set and the user has typed nothing, the
  default is returned on timeout; otherwise the exit code is 254.

**`-U`**
: Map characters to upper case. If `-U` and `-L` are both specified, the
  last one wins.

**`-Z0`**
: Suppress the trailing newline that grabchars normally prints to stderr
  after input is complete.

**`-Z1`**
: Re-enable the trailing newline (the default).

**`--version`**
: Print the version string and exit with code 0.

## SUBCOMMANDS

### grabchars select *list* [options]

Choose from a comma-separated list with filter-as-you-type narrowing. The
selected option text is written to stdout. The exit code is the 0-based
position of the chosen option in the original list.

*list* is a comma-separated string of options, e.g. `"red,green,blue"`. To
load options from a file, use `--file` *filename*.

Controls:

| Key | Action |
|-----|--------|
| type | Narrow the list (filter-as-you-type) |
| Backspace | Widen the filter |
| Up / Down | Cycle through matching options |
| Tab | Fill filter with full name of current match |
| Enter | Confirm selection; output to stdout |
| Escape | Cancel; no output; exit code 255 |

Options `-d`, `-t`, `-q`, `-e`, `-b`, `-f`, `-Z0`/`-Z1`, and `-F<p|f|c>`
all apply in select mode.

### grabchars select-lr *list* [options]

Horizontal selection. All matching options are shown on one line, with the
current selection highlighted. Type to filter, Left/Right (or Up/Down) to
move, Enter to confirm, Escape to cancel.

*list* is a comma-separated string of options, e.g. `"red,green,blue"`. To
load options from a file, use `--file` *filename* (one option per line),
the same as in `select` mode.

Accepts the same options as `select`, plus `-H<r|b|a>` for highlight style
and `-F<p|f|c>` for filter style.

## LINE EDITING

When `-n` is greater than 1, line editing is active by default (equivalent
to `-E1`). Disable with `-E0`. Force on for a single character with `-E`.

| Key | Action |
|-----|--------|
| Left / Ctrl-B | Move cursor left one character |
| Right / Ctrl-F | Move cursor right one character |
| Home / Ctrl-A | Move to beginning of line |
| End / Ctrl-E | Move to end of line |
| Backspace | Delete character before cursor |
| Delete / Ctrl-D | Delete character under cursor |
| Ctrl-K | Kill (delete) from cursor to end of line |
| Ctrl-U | Kill from beginning of line to cursor |
| Ctrl-W | Kill word backward |

## MASK SYNTAX

A mask is specified with `-m"pattern"` and constrains input position by
position. Literal characters in the pattern (parentheses, slashes, dashes,
etc.) are auto-inserted into the display as the user types.

### Mask character classes

| Code | Accepts | Character set |
|------|---------|---------------|
| `U` | Uppercase letter | `[A-Z]` |
| `l` | Lowercase letter | `[a-z]` |
| `c` | Alphabetic character | `[A-Za-z]` |
| `n` | Digit | `[0-9]` |
| `x` | Hexadecimal digit | `[0-9A-Fa-f]` |
| `p` | Punctuation | `[!-/:-@[-`{-~]` |
| `W` | Whitespace | space or tab |
| `.` | Any character | |
| `[...]` | Custom character class | same syntax as `-c` |

Any character not listed above is treated as a literal and will be
auto-inserted. To use a mask code character as a literal, escape it with a
backslash (e.g., `\n` for a literal *n*).

### Quantifiers

Follow the preceding mask element:

| Symbol | Meaning |
|--------|---------|
| `*` | Zero or more (greedy; requires Enter to complete) |
| `+` | One or more (greedy; requires Enter to complete) |
| `?` | Zero or one (optional) |

Quantifiers cannot be applied to literal characters.

## JSON OUTPUT

The `-J` flag replaces the normal value output with a single JSON object.
You get JSON or raw text, never both at the same time. The exit code (`$?`)
is always identical to the `exit` field in the JSON object.

### Fields

All fields are always present:

| Field | Type | Description |
|-------|------|-------------|
| `value` | string | Captured text (what stdout normally contains) |
| `exit` | integer | Exit code (same as `$?`) |
| `status` | string | `ok`, `default`, `timeout`, or `cancelled` |
| `mode` | string | `normal`, `mask`, `select`, `select-lr`, or `raw` |
| `timed_out` | boolean | Whether the timeout fired |
| `default_used` | boolean | Whether the default value (`-d`) was returned |
| `index` | integer or null | 0-based option index (select modes); null otherwise |
| `filter` | string or null | Filter text (select modes); null otherwise |

In raw mode (`-R`), `value` is hex-encoded (space-separated, e.g.
`1b 5b 41`) since the captured bytes may not be valid UTF-8.

`-J` replaces the normal value output with JSON; the `-e` and `-b` flags
route that JSON the same way they route raw text. Prompts (`-q`/`-p`) are
unaffected. In silent mode (`-s`), the JSON object is still written to
stdout.

See [docs/JSON-OUTPUT.md](JSON-OUTPUT.md) for examples and full details.

## RAW MODE

With `-R`, grabchars bypasses its escape-sequence parser. Every byte
received from the terminal is collected as-is; multi-byte sequences such as
arrow keys (ESC [ A = three bytes for Up) count as three bytes toward `-n`.

Raw mode is useful for key-binding capture, debugging what byte sequences a
terminal sends, or any situation where you need the exact bytes that keys
produce.

Output is binary; pipe to `xxd(1)` or `od(1)` to inspect:

```bash
grabchars -R -n 3 | xxd
```

## EXAMPLES

```
grabchars                              gets one keystroke
grabchars -caeiou                      get one of the vowels
grabchars -c i                         get the letter 'i'
grabchars -C aeiou                     get any character except a vowel
grabchars '-penter a letter '          print the prompt "enter a letter "
grabchars '-qenter a letter '          print prompt through stderr
grabchars -n4                          get four characters
grabchars -d a                         default to 'a' on RETURN
grabchars -d gumby                     default to "gumby" on RETURN
grabchars -r                           RETURN key exits
grabchars -n 4 -r -t 10               up to 4 chars, Enter or 10s timeout
grabchars -t2                          timeout after two seconds
grabchars -d gumby -t2                 timeout to "gumby" after 2 seconds
grabchars -n3 -p 'initials: '         prompt and grab three characters
grabchars -c 0123456789 -n2 -t10      get two numbers, 10s timeout
```

### Mask mode

```
grabchars -m "(nnn) nnn-nnnn" -q "Phone: "       phone number
grabchars -m "nn/nn/nnnn" -q "Date: "             date (MM/DD/YYYY)
grabchars -m "#xxxxxx" -q "Hex color: "           hex color code
```

### Select mode

```
grabchars select "yes,no,cancel" -q "Action: "              vertical menu
grabchars select-lr "small,medium,large" -q "Size: "        horizontal menu
grabchars select-lr -Ff "san francisco,san jose" -q "City: " fuzzy filter
grabchars select-lr -Fc "new haven,new york" -q "City: "     contains filter
grabchars select "yes,no" -B200 -q "Confirm: "              ESC exits 200
```

### Raw mode

```
grabchars -R -n 3 -q "Press an arrow key: " | xxd   capture raw bytes
```

### JSON output

```
grabchars -J -cy -q "y/n: " 2>/dev/tty              compact JSON
grabchars -Jp select "yes,no" -q "Choose: " 2>/dev/tty   pretty JSON
```

Note that arguments like `-n4` or `-n 4` are handled the same way.

## DIAGNOSTICS

grabchars returns the number of characters (or bytes, in raw mode)
successfully read — typically 1 for a single keystroke.

Special exit codes:

| Code | Meaning |
|------|---------|
| 254 | Timeout with no input and no default set |
| 255 | Escape pressed, bad arguments, or other error |
| 0 | `--version` flag |

In `select` and `select-lr` modes, the exit code is the 0-based index of
the chosen option in the original list (0 = first option, 1 = second,
etc.). Escape returns 255; timeout without a default returns 254.

## SEE ALSO

sh(1), bash(1), read(1), xxd(1), od(1)

Full documentation is in the source distribution:

- `README.md` — flag reference
- `docs/cookbook.md` — runnable examples covering all features
- `docs/maskInput.md` — mask syntax reference
- `docs/RAW-MODE.md` — raw byte mode reference
- `docs/FILTER-FLAG.md` — select filter styles (`-Fp`/`-Ff`/`-Fc`)
- `docs/JSON-OUTPUT.md` — JSON output mode reference

## AUTHOR

Dan Smith

Originally written in C in 1988 and posted to *comp.sources.misc*.
Rewritten in Rust in 2025-2026 as grabchars 2.0.

Source: https://github.com/DanielSmith/grabchars
