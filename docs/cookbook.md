# grabchars Cookbook

Runnable examples covering every feature of grabchars. Each recipe is
a terminal command you can copy-paste, followed by what to type and
what to expect.

All examples assume you've built the binary:

```bash
cd grabchars
cargo build --release
export PATH=$PWD/target/release:$PATH
```

---

## Version

```bash
grabchars --version
```

Prints the version string and exits. No input required.

---

## 1. Single Character

The simplest use: grab exactly one keystroke.

```bash
grabchars
```

Type any key. It's echoed and returned immediately — no Enter needed.
Exit code is 1 (one character read).

### Capture it in a script

```bash
ANSWER=$(grabchars -q "Continue? " -c yn)
echo "You said: $ANSWER"
```

Type `y` or `n`. Any other key is ignored.

---

## 2. Character Filtering (-c)

Only accept specific characters.

### Accept only vowels

```bash
grabchars -c aeiou -q "Vowel: "
```

Type `b` — nothing happens. Type `a` — accepted and returned.

### Accept a character class

```bash
grabchars -c "[A-Z]" -q "Uppercase letter: "
```

Only uppercase letters are accepted.

### Accept only digits

```bash
grabchars -c 0123456789 -q "Digit: "
```

---

## 3. Character Exclusion (-C)

Reject specific characters; accept everything else.

### Exclude vowels

```bash
grabchars -C aeiou -q "Consonant: "
```

Vowels are silently rejected. Any consonant, digit, or punctuation is accepted.

### Combine -c and -C

```bash
grabchars -c "[a-z]" -C aeiou -q "Lowercase consonant: "
```

Must be lowercase (`-c`) AND not a vowel (`-C`).

---

## 4. Case Mapping (-U, -L)

Force input to upper or lower case.

### Force uppercase

```bash
grabchars -U -q "Letter (forced upper): "
```

Type `a` — you see `A`. Output is `A`.

### Force lowercase

```bash
grabchars -L -q "Letter (forced lower): "
```

Type `A` — you see `a`. Output is `a`.

### Combine with -c

```bash
grabchars -U -c yn -q "Yes/No? "
```

Type `y` — mapped to `Y`, then checked against `yn`. Accepted
because `-c yn` includes both cases? No — `-U` maps first, then
`Y` is checked against `[yn]`. `Y` doesn't match `y` or `n`.

To make this work as expected:

```bash
grabchars -U -c yYnN -q "Yes/No? "
```

Or use a case-insensitive class:

```bash
grabchars -U -c "[ynYN]" -q "Yes/No? "
```

---

## 5. Multiple Characters (-n)

Read a fixed number of characters.

### Read exactly 4 characters

```bash
grabchars -n 4 -q "PIN: "
```

Type 4 characters — grabchars returns immediately after the 4th.
No Enter needed. Exit code is 4.

### Read up to 10, Enter to finish early (-r)

```bash
grabchars -n 10 -r -q "Name (up to 10 chars): "
```

Type some characters, then press Enter. Exit code = number of
characters typed (not counting Enter).

---

## 6. Line Editing (-E)

When `-n` is greater than 1, editing is enabled by default: arrow
keys, Home/End, Backspace, Delete, Ctrl-K, Ctrl-U, Ctrl-W all work.

### Edit mode on (default for -n > 1)

```bash
grabchars -n 20 -r -q "Edit me: "
```

Type `hello`, press Left arrow twice, type `XX`. You see `helXXlo`.
Press Home, then Ctrl-K to kill to end of line. Retype. Press Enter.

### Force edit mode off

```bash
grabchars -n 5 -E0 -q "No editing: "
```

Arrow keys and backspace are ignored. Characters accumulate until 5 are typed.

### Force edit mode on for single char

```bash
grabchars -n 1 -E -r -q "Editable single: "
```

Backspace works even for a single character slot.

---

## 7. Default Value (-d)

Return a default when the user presses Enter without typing.

### Single character default

```bash
grabchars -c yn -d y -q "Continue? [Y/n] "
```

Press Enter — returns `y` with exit code 1.
Type `n` — returns `n`.

### Multi-character default

```bash
grabchars -n 20 -r -d "localhost" -q "Host [localhost]: "
```

Press Enter — returns `localhost`.
Type something else — returns what you typed.

---

## 8. Timeout (-t)

Auto-return after a timeout.

### Timeout with default

```bash
grabchars -t 3 -d y -c yn -q "Continue? (3s timeout) "
```

Wait 3 seconds without typing — returns `y` (the default).
Type within 3 seconds — returns what you typed.

### Timeout without default

```bash
grabchars -t 5 -n 10 -r -q "Quick, type something (5s): "
```

If you type `hel` and the timeout fires, returns `hel` (partial input)
with exit code 254.

---

## 9. Silent Mode (-s)

Don't echo keystrokes. Output still goes to stdout.

```bash
grabchars -n 8 -s -q "Password: "
```

Type 8 characters — nothing is echoed. The password goes to stdout.

### Capture silently

```bash
PASSWORD=$(grabchars -n 20 -r -s -q "Password: ")
echo ""  # newline after invisible input
echo "Got ${#PASSWORD} chars"
```

---

## 10. Output Routing (-e, -b)

Control where output goes.

### Output to stderr instead of stdout

```bash
grabchars -e -q "This goes to stderr: "
```

The character goes to stderr, not stdout. Useful when stdout is
piped elsewhere.

### Output to both stdout and stderr

```bash
grabchars -b -q "Both streams: "
```

Output appears on stderr (visible) and stdout (capturable).

---

## 11. Trailing Newline (-Z)

By default, grabchars prints a trailing newline to stderr after the
input is complete (so the next shell prompt appears on a new line).

### Suppress the trailing newline

```bash
grabchars -Z0 -q "No newline after: "
```

The shell prompt appears immediately after your input on the same line.

---

## 12. Prompt (-p vs -q)

### Prompt to stdout (-p)

```bash
grabchars -p "stdout prompt: "
```

The prompt goes to stdout. If stdout is captured, the prompt is
captured too — usually not what you want.

### Prompt to stderr (-q)

```bash
RESULT=$(grabchars -q "stderr prompt: ")
echo "Got: $RESULT"
```

The prompt goes to stderr (visible), the result to stdout (captured).
This is almost always the right choice in scripts.

---

## 13. Select Mode

Choose from a list using arrow keys.

### Basic select

```bash
grabchars select "red,green,blue,yellow" -q "Color: "
```

Use Up/Down arrows to navigate. Type to filter. Enter to confirm.
Returns the selected option text.

### Select from a file

```bash
echo -e "apple\nbanana\ncherry\ndate" > /tmp/fruits.txt
grabchars select --file /tmp/fruits.txt -q "Fruit: "
```

### Select with default

```bash
grabchars select "small,medium,large" -d medium -q "Size: "
```

Opens with `medium` pre-selected.

### Select with timeout

```bash
grabchars select "yes,no" -d yes -t 5 -q "Confirm (5s): "
```

Auto-selects `yes` after 5 seconds.

---

## 14. Select-LR Mode

Horizontal selection — all options visible at once.

```bash
grabchars select-lr "red,green,blue" -q "Color: "
```

Use Left/Right arrows to highlight an option. Enter to confirm.

### Highlight styles (-H)

```bash
# Reverse video (default)
grabchars select-lr "a,b,c" -Hr -q "Reverse: "

# Bracket style
grabchars select-lr "a,b,c" -Hb -q "Bracket: "

# Arrow style
grabchars select-lr "a,b,c" -Ha -q "Arrow: "
```

---

## 15. Mask Mode — Fixed Position (-m)

Positional input validation. Literal characters (parens, dashes,
slashes) are auto-inserted as you type.

### Phone number

```bash
grabchars -m "(nnn) nnn-nnnn" -q "Phone: "
```

Type 10 digits. You see: `(212) 555-1212`. The parens, space,
and dash are inserted automatically.

### Date

```bash
grabchars -m "nn/nn/nnnn" -q "Date: "
```

Type 8 digits: `01152026`. You see: `01/15/2026`.

### Name (uppercase + lowercase)

```bash
grabchars -m "Ulll" -q "Name: "
```

First character must be uppercase, next three must be lowercase.
Type `Fred` — accepted. Type `fred` — the `f` is rejected.

### Hex color

```bash
grabchars -m "#xxxxxx" -q "Color: "
```

The `#` is auto-inserted. Type 6 hex digits.

### Serial number

```bash
grabchars -m "UUU-nnnnnn" -q "Serial: "
```

Type 3 uppercase letters, then the dash appears, then type 6 digits.

### ZIP+4

```bash
grabchars -m "nnnnn-nnnn" -q "ZIP+4: "
```

Type 9 digits. The dash is auto-inserted after the 5th.

### Yes/No with custom class

```bash
grabchars -m "[yn]" -q "Continue? "
```

Only `y` or `n` is accepted.

### Mask with case mapping

```bash
grabchars -m "cccc" -U -q "Code (forced upper): "
```

Type lowercase — it's mapped to uppercase, then validated against
the mask. All 4 letters come out uppercase.

### Escape to cancel

In any mask prompt, press Escape to cancel. Nothing is output,
exit code is 255.

### Backspace in masks

```bash
grabchars -m "(nnn) nnn-nnnn" -q "Phone: "
```

Type `21255`, then Backspace. The `5` is removed. Backspace again —
the `) ` literal pair is removed automatically and you're back to
editing the area code.

---

## 16. Mask Mode — Quantifiers

Variable-length input positions using `*`, `+`, `?`.

### One or more letters (c+)

```bash
grabchars -m "c+" -r -q "Word: "
```

Type letters, press Enter. At least one letter is required.

### Letters then digits (c+n+)

```bash
grabchars -m "c+n+" -r -q "Code: "
```

Type letters — they accumulate. Type a digit — grabchars
automatically advances to the digit group. Enter to finish.
Both groups require at least one character.

### Hyphenated words (c+-c+)

```bash
grabchars -m "c+-c+" -r -q "Hyphenated: "
```

Type letters for the first word. When you type a digit or stop
typing letters and the next mask element is a literal `-`, the
dash is auto-inserted. Then type the second word. Enter to finish.

### Optional prefix (c?nnn)

```bash
grabchars -m "c?nnn" -q "Optional letter + 3 digits: "
```

Type `A123` — the letter is accepted, then 3 digits. Or type `123` —
the `c?` is skipped (zero matches is OK), digits go to `nnn`.
Auto-completes after 3 or 4 characters.

### Variable digits with fixed prefix (UUU-n+)

```bash
grabchars -m "UUU-n+" -r -q "Serial: "
```

Type 3 uppercase letters — dash auto-inserted — then type as many
digits as you want. Enter to finish.

### Vowels only ([aeiou]+)

```bash
grabchars -m "[aeiou]+" -r -q "Vowels: "
```

Custom character class with a quantifier. Only vowels accepted.
Enter to finish.

### Two capitalized names (Uc+, Uc+)

```bash
grabchars -m "Uc+, Uc+" -r -q "Full name: "
```

Type an uppercase letter, then lowercase letters for the first name.
When you type an uppercase letter and the first group's quantifier
is satisfied, the `, ` literal is auto-inserted and the second
name begins. Enter to finish.

### Zero-or-more (c*n+)

```bash
grabchars -m "c*n+" -r -q "Optional prefix + digits: "
```

Type letters (optional), then digits (required). Or just type
digits immediately — the `c*` is skipped.

---

## 17. Mask Mode — Error Cases

### Quantifier on a literal

```bash
grabchars -m "(-*nnn)"
```

Error: `quantifier '*' cannot be applied to a literal character`.
Exit code 255.

### Unclosed bracket

```bash
grabchars -m "[abc"
```

Error: `unclosed '[' in mask`. Exit code 255.

### Empty mask

```bash
grabchars -m ""
```

Error: `mask is empty`. Exit code 255.

---

## 18. Flush (-f)

Discard any buffered input before reading.

```bash
grabchars -f -q "Clean read: "
```

If keys were pressed before grabchars started (typeahead), they're
discarded. Without `-f`, they'd be read immediately.

---

## 19. Exit Codes

| Scenario | Exit Code |
|---|---|
| N characters read | N |
| Escape pressed (mask mode) | 255 (-1) |
| Timeout (partial input) | 254 (-2) |
| Error (bad flags, bad mask) | 255 |
| Default returned | 1 (single) or string length |
| `--version` | 0 |
| `-h` | 255 |

### Test exit codes in a script

```bash
grabchars -c yn -q "Continue? "
case $? in
    1) echo "Got one character" ;;
    255) echo "Error or help" ;;
    254) echo "Timed out" ;;
esac
```

---

## 20. Real-World Script Patterns

### Confirm before destructive action

```bash
echo "This will delete all logs."
CONFIRM=$(grabchars -c yn -d n -q "Are you sure? [y/N] ")
if [ "$CONFIRM" = "y" ]; then
    echo "Deleting..."
else
    echo "Cancelled."
fi
```

### Read a date with validation

```bash
DATE=$(grabchars -m "nn/nn/nnnn" -q "Enter date (MM/DD/YYYY): ")
echo "You entered: $DATE"
```

### Menu selection

```bash
ACTION=$(grabchars select "deploy,rollback,status,quit" -q "Action: ")
echo "Selected: $ACTION"
```

### Silent password with confirmation

```bash
P1=$(grabchars -n 30 -r -s -q "Password: "); echo ""
P2=$(grabchars -n 30 -r -s -q "Confirm:  "); echo ""
if [ "$P1" = "$P2" ]; then
    echo "Passwords match."
else
    echo "Mismatch!"
fi
```

### Timed prompt with fallback

```bash
MODE=$(grabchars select "fast,normal,careful" -d normal -t 10 -q "Build mode (10s): ")
echo "Using: $MODE"
```
