## Mask Input (`-m`)

Positional input validation for grabchars. Each position in the input
is validated against a corresponding element in the mask pattern.
Characters that don't match the mask at the current position are
rejected (not echoed, not added to the buffer).

### Status

**Phase 1 (implemented):** Fixed-position masks. Each mask element
corresponds to exactly one input position.

**Phase 2 (implemented):** Quantifier support — `*`, `+`, `?` applied
to the preceding mask element. Greedy matching with automatic advancement
when the current element can't accept a character.

### Usage

    grabchars -m "Ulllnnn"          # uppercase, 3 lower, 3 digits
    grabchars -m "nnn" -q "Area code: "
    grabchars -m "[aeiou]ccc"       # vowel then 3 alpha chars

The mask length determines the character count (like an implicit `-n`).

### Mask Characters

    U       uppercase letter         [A-Z]
    l       lowercase letter         [a-z]
    c       alphabetic character     [A-Za-z]
    n       digit                    [0-9]
    x       hex digit                [0-9A-Fa-f]
    p       punctuation              [!-/:-@[-`{-~]
    W       whitespace               space or tab
    .       any character
    [...]   custom character class   same syntax as -c

### Literal Characters in Masks

Characters in the mask that are not mask codes are treated as
literals. They are automatically inserted into the buffer when
reached (the user does not type them). This enables patterns like
phone numbers and dates where the punctuation is fixed:

    grabchars -m "(nnn) nnn-nnnn" -q "Phone: "

The user types `2125551212` and sees `(212) 555-1212`. The parens,
space, and hyphen are inserted automatically.

Mask codes are single characters: `U`, `l`, `c`, `n`, `x`, `p`,
`W`, and `.` (dot). A `[` begins a character class. Everything else
is a literal.

To use a mask code character as a literal, escape it with `\`:

    grabchars -m "\null"           # literal 'n', then 'u', then 2 lowercase

### Input Model

Mask mode uses append-only input (no cursor movement):

- **Characters**: case-mapped, filtered by `-c`/`-C`, then validated
  against the mask at the current position. If valid, appended to
  buffer and any trailing literals auto-inserted.
- **Backspace**: removes last character. Automatically backs up over
  adjacent literals (and leading literals if nothing typed remains).
- **Enter**: if `-d` set and buffer empty, returns default. If `-r`
  set, accepts partial input. Otherwise ignored.
- **Escape**: erases displayed input, returns exit code 255 (no output).
- **Timeout**: if `-d` set and buffer empty, returns default. Otherwise
  outputs partial buffer, returns exit code 254.
- **All other keys** (arrows, Home/End, Ctrl-K/U/W, Tab): ignored.

On completion (buffer fills the mask, or Enter with `-r`):
- Output buffer to stdout (or stderr with `-e`, both with `-b`).
- Exit code = number of characters in buffer.

### Examples

    Mask                Accepts                     User types
    ----                -------                     ----------
    "Ulll"              Uppercase + 3 lowercase     Fred
    "nnn"               3 digits                    867
    "nnn-nnnn"          phone (local)               5551212
    "(nnn) nnn-nnnn"    phone (full)                2125551212
    "nn/nn/nnnn"        date                        01151988
    "[yn]"              y or n                      y
    "#xxxxxx"           hex color with literal #    1a2b3c
    "UUU-nnnnnn"        serial number               ABC123456
    "nnnnn-nnnn"        US zip+4                    902101234

### Interaction with Other Flags

    -m "..."    sets the mask
    -r          Enter accepts partial input
    -d <str>    default returned on Enter (if buffer empty) or timeout
    -c <chars>  additional include filter (applied AFTER mask check)
    -C <chars>  exclusion filter (applied AFTER mask check)
    -U / -L     case mapping (applied BEFORE mask check)
    -q <str>    prompt (to stderr)
    -s          silent mode (no echo)
    -e          output to stderr instead of stdout
    -b          output to both stdout and stderr

### Quantifiers

    *       zero or more
    +       one or more
    ?       zero or one (optional)

A quantifier modifies the preceding mask element to accept a variable
number of characters instead of exactly one. Matching is **greedy** —
the current element consumes as many characters as it can before
advancing.

When a quantifier is active, the current mask element stays in effect
until either:
- a character arrives that doesn't match the current element but
  does match the NEXT element in the mask (greedy advance), or
- the minimum count is satisfied and the user moves on naturally

For `*` and `?`, because zero matches are valid, input that matches
the next mask element advances the mask position immediately.

Masks with unbounded quantifiers (`*`, `+`) require Enter to complete
(the mask never auto-completes). Use `-r` for partial-input acceptance
or Enter when `mask_satisfied` (all required elements have their
minimums met).

Quantifier examples:

    Mask            Accepts                     User types
    ----            -------                     ----------
    "c+"            one or more letters         hello
    "c+n+"          letters then digits         abc123
    "c+-n+"         letters, dash, digits       abc-123 (dash auto-inserted)
    "c?nnn"         optional letter + 3 digits  A123 or 123
    "[aeiou]+"      one or more vowels          aeiou
    "Uc+, Uc+"      two capitalized names       Dan, Smith (comma+space auto)

Quantifiers cannot be applied to literal characters:

    $ grabchars -m "(-*nnn)"
    -m option: quantifier '*' cannot be applied to a literal character

**Known limitation:** adjacent elements of the same class with a
quantifier on the first one will starve the second (greedy consumes
all). E.g., `c+c` — the `c+` takes every letter, leaving none for
the final `c`.


## Character Exclusion (`-C`)

The inverse of `-c`. Rejects characters that match the pattern;
accepts everything else.

### Usage

    grabchars -C aeiou              # accept anything except vowels
    grabchars -C 0123456789         # accept anything except digits
    grabchars -C "[A-Z]"           # accept anything except uppercase

### Syntax

Same character/class syntax as `-c`:

    -C aeiou            any single char in the string excludes
    -C "[A-Z]"          regex character class

### Interaction with `-c`

`-c` and `-C` can be combined. A character must match `-c` AND must
not match `-C`:

    grabchars -c "a-z" -C "aeiou"   # lowercase consonants only

### Interaction with `-m`

When used with `-m`, the exclusion filter is applied after the mask
check. A character must pass the mask for its position AND must not
be excluded by `-C`.
