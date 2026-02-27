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

`-U` and `-L` map the character first, then `-c` filters the result.
So the filter must match the post-mapping value.

```bash
grabchars -U -c YN -q "Yes/No? "
```

Type `y` or `Y` — both map to `Y`, which passes `-c YN`. Output is
always `Y` or `N`.

```bash
grabchars -L -c yn -q "Yes/No? "
```

Type `y` or `Y` — both map to `y`, which passes `-c yn`. Output is
always `y` or `n`.

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

Suppress all output — no echo during typing, nothing sent to stdout or
stderr. Only the exit code is returned (number of characters read).

```bash
grabchars -n 8 -s -q "Password: "
echo "Exit code: $?"
```

Type 8 characters — nothing is echoed, nothing is printed. The exit
code tells you how many characters were typed.

### Press any key to continue

```bash
grabchars -s -q "Press any key to continue..."
```

### Gate on character count

```bash
grabchars -n 4 -s -q "Type your 4-digit PIN: "
if [ $? -eq 4 ]; then
    echo "OK"
else
    echo "Wrong number of characters"
fi
```

### Note: capturing without echo

`-s` suppresses the final output, so `$()` capture returns nothing.
To capture what was typed while suppressing on-screen echo, redirect
stderr (where the typing display goes) to `/dev/null` instead:

```bash
CHOICE=$(grabchars -n 1 -q "Choice: " 2>/dev/null)
echo "Got: $CHOICE"
```

Note: if you run `grabchars ... 2>/dev/null` directly at an interactive
zsh prompt (not in `$()`), you'll see a `%` after the output. That's
zsh's partial-line indicator — it appears because the trailing newline
normally goes to stderr, which you've suppressed. It's not grabchars
output. Use `$()` capture or append `; echo` to avoid it.

For multi-character input, the character-by-character echo still appears
via stderr. There is currently no single-flag way to capture silently.

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

Choose from a list with filter-as-you-type.

### Basic select

```bash
grabchars select "red,green,blue,yellow" -q "Color: "
```

The widget shows your filter text, an arrow, the current match, and a
match count. Type to narrow the list; Up/Down to cycle through matches;
Enter to confirm. The selected option text goes to stdout.

**Exit code** is the 0-based position of the chosen option in the
original list (0 = first option, 1 = second, …). Most scripts capture
the text via `$()` and ignore the exit code; but the exit code lets you
branch by position without string comparison (see section 19).

### Tab completion

Tab fills the filter field with the full name of the currently
highlighted match. Useful when options share a long common prefix: type
enough to isolate the one you want, then Tab to fill it in, then Enter.

```bash
grabchars select "configure,build,test,install,clean" -q "Step: "
```

Type `co`, Tab — filter becomes `configure`. Press Enter to confirm.

### Escape to cancel

Escape exits immediately with no output and exit code 255.

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

Horizontal selection — all matching options are shown at once on one
line, with the current selection highlighted.

```bash
grabchars select-lr "red,green,blue" -q "Color: "
```

The display looks like:

```
 → [red] green blue  (3 matches)
```

The selected option text goes to stdout on Enter. **Exit code** is the
0-based position of the chosen option in the original list, same as
select mode.

### Filtering the list

Type characters to narrow which options are shown. Only options whose
names start with the typed prefix remain visible.

```bash
grabchars select-lr "apple,apricot,banana,blueberry,cherry" -q "Fruit: "
```

Type `b` — only `banana` and `blueberry` remain. Type `bl` — only
`blueberry`. Backspace to widen the filter again.

### Navigating with arrow keys

Left/Right (and Up/Down — both pairs work) move the highlight among the
currently visible matches. The list wraps: pressing Left at the first
option jumps to the last, and vice versa.

```bash
grabchars select-lr "small,medium,large,x-large" -q "Size: "
```

### Home and End

Home jumps to the first visible match; End jumps to the last.

### Tab completion

Tab fills the filter field with the full name of the currently
highlighted option. Useful for long option names: type enough to isolate
the one you want, then Tab to lock it in before pressing Enter.

```bash
grabchars select-lr "configure,build,test,install,clean" -q "Step: "
```

Type `co`, Tab — filter becomes `configure`. Press Enter to confirm.

### Escape to cancel

Escape exits immediately with no output and exit code 255.

### Highlight styles (-H)

```bash
# Reverse video (default)
grabchars select-lr "a,b,c" -Hr -q "Reverse: "

# Bracket style  →  a [b] c
grabchars select-lr "a,b,c" -Hb -q "Bracket: "

# Arrow style    →  a >b< c
grabchars select-lr "a,b,c" -Ha -q "Arrow: "
```

Bracket and arrow styles are useful on terminals where reverse video is
hard to see or not supported.

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

### Two capitalized names (Ul+, Ul+)

```bash
grabchars -m "Ul+, Ul+" -r -q "Full name: "
```

Type an uppercase letter, then lowercase letters for the first name.
When you type the second name's uppercase initial, it fails the
lowercase `l+` group — the `, ` literal is auto-inserted and the
second name begins. Enter to finish.

Note: use `l` (lowercase-only) rather than `c` (any letter) for
the letter groups. With `c+`, the greedy match would consume the
second name's uppercase initial, making the mask impossible to complete.

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

**Normal / mask mode:**

| Scenario | Exit Code |
|---|---|
| N characters read | N (1–253) |
| Default returned on Enter | 1 (single char) or length of default string |
| Timeout with partial input | 254 |
| Escape pressed | 255 |
| Error (bad flags, bad mask) | 255 |
| `--version` | 0 |
| `-h` | 255 |

**Select / select-lr mode:**

| Scenario | Exit Code |
|---|---|
| Option selected | 0-based index in the original list |
| Escape pressed | 255 |
| Timeout without default | 254 |

The 0-based index means: first option = 0, second = 1, and so on.
Exit code 0 ("first option chosen") is indistinguishable from the
conventional Unix success code, so prefer capturing stdout for
unambiguous results. Use the exit code only when you own the option
order and know what position 0 means.

### Branch on normal-mode exit code

```bash
grabchars -c yn -q "Continue? "
case $? in
    1) echo "Got one character" ;;
    255) echo "Cancelled or error" ;;
    254) echo "Timed out" ;;
esac
```

### Branch on select exit code (by position)

```bash
grabchars select "deploy,rollback,quit" -q "Action: " > /dev/null
case $? in
    0) echo "deploy" ;;
    1) echo "rollback" ;;
    2) echo "quit" ;;
    255) echo "cancelled" ;;
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

### Menu selection (capture text)

```bash
ACTION=$(grabchars select "deploy,rollback,status,quit" -q "Action: ")
echo "Selected: $ACTION"
```

### Menu selection (branch by exit code)

Select returns the 0-based position of the chosen option as its exit
code. You can use this to dispatch without string comparison — discard
stdout with `> /dev/null` and switch on `$?` instead.

The option order in the argument string defines the exit codes:
`deploy`=0, `rollback`=1, `status`=2, `quit`=3.

```bash
grabchars select "deploy,rollback,status,quit" -q "Action: " > /dev/null
case $? in
    0) deploy ;;
    1) rollback ;;
    2) show_status ;;
    3) exit 0 ;;
    255) echo "Cancelled." ;;
esac
```

This is most useful when the handler is a function or command rather
than a string comparison — the `case` arms can call code directly.

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

### Capture and display simultaneously (-b)

Inside `$()`, stdout is captured by the shell and nothing appears on
screen. Normally that's fine, but for multi-character input the user
can't see what they've typed once the subshell exits. `-b` sends output
to both stdout (captured) and stderr (visible), so the result appears on
the terminal even though it's also being captured.

```bash
FILENAME=$(grabchars -n 40 -r -b -q "Filename: ")
echo "You entered: $FILENAME"
```

Type `report.txt` — it appears on screen as you type (via stderr) and
is captured in `$FILENAME` (via stdout).

Without `-b`, the characters echo during typing (that goes to stderr
regardless), but the final captured value is invisible until `echo`
prints it. With `-b`, it's visible twice — once as typed, once from
`echo`. For a cleaner look, suppress the final echo and rely on what
the user already saw:

```bash
CONFIRM=$(grabchars -c yn -b -q "Really delete? [y/n] ")
# $CONFIRM holds the answer; user already saw it echoed
[ "$CONFIRM" = "y" ] && rm -rf /tmp/scratch
```
