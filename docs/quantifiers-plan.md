# Phase 2: Mask Quantifiers (`*`, `+`, `?`)

## Summary

Add quantifier support to mask input. A quantifier modifies the
preceding mask element to accept a variable number of characters
instead of exactly one.

    *   zero or more
    +   one or more
    ?   zero or one (optional)

## File to modify

`src/mask.rs`

Only `mask.rs` needs changes. The main.rs wiring is already in place.

## Current state (Phase 1)

- `MaskElement` has only `class: MaskClass`
- `parse_mask` rejects quantifiers with an error message
- `run_mask_mode` uses `buffer.len()` as the mask index — this works
  because every element is exactly 1 character wide
- `mask_auto_insert_literals` walks forward from `buffer.len()`

## The core problem

With quantifiers, buffer position no longer maps 1:1 to mask element
index. Element 0 might consume 0 characters (`*`, `?`) or 5 characters
(`+`). We need separate tracking of "which mask element are we on" and
"how many characters has this element consumed."

## Design

### 1. Add Quantifier to MaskElement

```rust
#[derive(Clone, Copy, PartialEq)]
pub enum Quantifier {
    One,      // exactly one (default, current behavior)
    Star,     // zero or more
    Plus,     // one or more
    Optional, // zero or one
}

pub struct MaskElement {
    pub class: MaskClass,
    pub quantifier: Quantifier,
}
```

### 2. Update parse_mask

After parsing each element, peek at the next character. If it's
`*`, `+`, or `?`, set the quantifier and consume it. Remove the
quantifier error exit.

```
"c+"  → [MaskElement { class: Alpha, quantifier: Plus }]
"n*"  → [MaskElement { class: Digit, quantifier: Star }]
"c?"  → [MaskElement { class: Alpha, quantifier: Optional }]
"Uc+" → [MaskElement { class: Upper, quantifier: One },
         MaskElement { class: Alpha, quantifier: Plus }]
```

Literals cannot have quantifiers (reject with error):
```
$ grabchars -m "(-nnn)"    # fine — parens are literals
$ grabchars -m "(-*nnn)"   # error: quantifier on literal
```

Wait — actually literals with quantifiers could make sense eventually
but for now reject them. Quantifiers on `[...]` custom classes are fine.

### 3. Track mask position separately from buffer position

Add a parallel vector `mask_map` that records which mask element each
buffer character belongs to:

```rust
let mut buffer: Vec<u8> = Vec::new();
let mut mask_map: Vec<usize> = Vec::new();  // mask_map[i] = mask element index for buffer[i]
```

The "current mask element" is:
- If buffer is empty: 0 (or first non-skippable element)
- Otherwise: derived from `mask_map.last()`

Helper to get current element index and its count:

```rust
fn current_mask_state(mask_map: &[usize]) -> (usize, usize) {
    // Returns (current_element_index, count_at_that_element)
    if mask_map.is_empty() {
        return (0, 0);
    }
    let idx = *mask_map.last().unwrap();
    let count = mask_map.iter().rev().take_while(|&&x| x == idx).count();
    (idx, count)
}
```

### 4. Character acceptance algorithm

When char `ch` arrives and current state is element `idx` with `count`
chars already consumed:

```
let can_accept_more = match mask[idx].quantifier {
    One      => count < 1,
    Star     => true,
    Plus     => true,
    Optional => count < 1,
};

let matches_current = can_accept_more && mask_char_matches(&mask[idx].class, ch);

// Try to find next accepting element if current can't/shouldn't take it
let min_satisfied = match mask[idx].quantifier {
    One      => count >= 1,
    Star     => true,      // min is 0
    Plus     => count >= 1, // min is 1
    Optional => true,      // min is 0
};
```

**Decision logic:**

```
if matches_current:
    if min_satisfied AND next element exists AND ch matches next element:
        // Ambiguous: current could take it, but so could next.
        // Use GREEDY: stay at current.
        // (See "Greedy vs eager" section below)
        → accept at current element
    else:
        → accept at current element

else if min_satisfied:
    → try_advance(idx + 1, ch)
    // Walk forward, skipping zero-min elements, looking for a match

else:
    → reject (beep / ignore keystroke)
```

**try_advance(from_idx, ch):**

```rust
fn try_advance(mask: &[MaskElement], from_idx: usize, ch: char) -> Option<usize> {
    let mut idx = from_idx;
    while idx < mask.len() {
        // Skip literals — they get auto-inserted, not typed
        if let MaskClass::Literal(_) = mask[idx].class {
            idx += 1;
            continue;
        }
        if mask_char_matches(&mask[idx].class, ch) {
            return Some(idx);
        }
        // Can we skip this element? Only if min is 0
        let can_skip = matches!(mask[idx].quantifier, Quantifier::Star | Quantifier::Optional);
        if can_skip {
            idx += 1;
        } else {
            return None; // blocked by a required element
        }
    }
    None // past end of mask
}
```

When advancing, auto-insert any literals between the old position
and the new one.

### 5. Greedy vs eager advancement

**Greedy** (stay at current as long as it matches) is the right default
for most real-world cases:

    Mask: "c+n+"   Input: "abc123"
    c+ takes a, b, c (greedy — keeps taking letters)
    When "1" arrives, doesn't match c, advance to n+
    n+ takes 1, 2, 3

    Mask: "c+-n+"  Input: "abc123"
    c+ takes a, b, c
    "-" is literal, auto-inserted
    n+ takes 1, 2, 3

**Known limitation — same-class adjacency:**

    Mask: "c+c"   (letters, then a letter)

    Greedy makes the first c+ consume ALL letters. The final c never
    gets a chance. This mask is degenerate — don't write it.

    Document this: adjacent elements of the same class with a
    quantifier on the first one will starve the second.

### 6. Completion detection

The mask is "satisfied" when all required elements have their minimums:

```rust
fn mask_satisfied(mask: &[MaskElement], mask_map: &[usize]) -> bool {
    for (idx, elem) in mask.iter().enumerate() {
        if let MaskClass::Literal(_) = elem.class {
            continue; // literals are auto-inserted
        }
        let count = mask_map.iter().filter(|&&x| x == idx).count();
        let min = match elem.quantifier {
            Quantifier::One => 1,
            Quantifier::Plus => 1,
            Quantifier::Star => 0,
            Quantifier::Optional => 0,
        };
        if count < min {
            return false;
        }
    }
    true
}
```

The mask is "full" (auto-complete, no more input needed) when:
- Current element is past the end of the mask, AND
- All elements are satisfied

For unbounded quantifiers (`*`, `+`), the mask is never "full" —
input continues until the user presses Enter (requires `-r`).

**Enter handling changes:**
- Without `-r`: Enter only works if `mask_satisfied()` is true
  (and buffer is non-empty, or `-d` is set)
- With `-r`: Enter always accepts (partial input is OK)

### 7. Backspace

Backspace is simpler than it might seem thanks to `mask_map`:

```
buffer.pop();
mask_map.pop();
```

The current element index is now `mask_map.last()` (or 0 if empty).

We still need the literal-backspace logic: if the character we just
removed was preceded by auto-inserted literals, keep backing up over
them. The `mask_map` tells us which chars are literals vs typed:

Actually — literals are not typed, so they shouldn't be in `mask_map`
the same way. Two options:

**Option A**: Literals ARE in the buffer and mask_map. mask_map entries
for literals point to the literal's mask index. Backspace pops them
like any other character, and we chain-delete literals as in phase 1.

**Option B**: Track literals separately.

**Option A is simpler and consistent with phase 1.** The existing
literal-backspace logic already handles chaining. We just need to
update it to use mask_map instead of checking `mask[buffer.len()-1]`.

Updated backspace logic:
```
while !buffer.is_empty() {
    buffer.pop();
    mask_map.pop();
    // erase on screen...

    // If the new last char is a literal, keep backing up
    if buffer.is_empty() { break; }
    let prev_mask_idx = mask_map.last().unwrap();
    if !matches!(mask[*prev_mask_idx].class, MaskClass::Literal(_)) {
        break;
    }
    // Also check leading-literals-only edge case (same as phase 1)
}
```

### 8. Auto-insert literals with quantifiers

The existing `mask_auto_insert_literals` walks from `buffer.len()`
forward. With quantifiers, we need to walk from the current mask
element index forward instead.

New version:

```rust
fn mask_auto_insert_literals(
    mask: &[MaskElement],
    buffer: &mut Vec<u8>,
    mask_map: &mut Vec<usize>,
    current_idx: usize,
    silent: bool,
) -> usize {
    let mut count = 0;
    let mut idx = current_idx;
    while idx < mask.len() {
        if let MaskClass::Literal(l) = mask[idx].class {
            buffer.push(l as u8);
            mask_map.push(idx);
            count += 1;
            if !silent {
                eprint!("{}", l);
            }
            idx += 1;
        } else {
            break;
        }
    }
    if count > 0 && !silent {
        let _ = io::stderr().flush();
    }
    count
}
```

### 9. Escape handling

Same as phase 1: erase displayed buffer, return -1. No changes needed
(buffer.len() still gives the display width for cursor positioning).

### 10. Timeout handling

Same as phase 1. Output partial buffer, return -2.

## Implementation order

1. Add `Quantifier` enum and update `MaskElement` struct
2. Update `parse_mask` to detect quantifiers (remove error, set field)
   - All existing fixed-position masks get `Quantifier::One`
   - Add validation: no quantifier on Literal elements
3. Add `mask_map: Vec<usize>` to `run_mask_mode`
4. Add helper: `current_mask_state(mask_map) -> (idx, count)`
5. Add helper: `try_advance(mask, from_idx, ch) -> Option<usize>`
6. Add helper: `mask_satisfied(mask, mask_map) -> bool`
7. Rewrite char-acceptance logic in the `KeyInput::Char` arm
8. Update `mask_auto_insert_literals` to take mask_map and current_idx
9. Update backspace logic to use mask_map
10. Update Enter logic: without `-r`, require `mask_satisfied()`
11. Test with fixed masks (regression — should work identically)
12. Test with quantifier masks

## Test cases

```bash
# Regression: all phase 1 tests should still pass
./target/release/grabchars -m "(nnn) nnn-nnnn" -q "Phone: "
./target/release/grabchars -m "nn/nn/nnnn" -q "Date: "
./target/release/grabchars -m "Ulll" -q "Name: "

# Plus: one or more letters, then enter
./target/release/grabchars -m "c+" -q "Word: " -r

# Plus with literal separator: word-word
./target/release/grabchars -m "c+-c+" -q "Hyphenated: " -r

# Plus with different classes: letters then digits
./target/release/grabchars -m "c+n+" -q "Code: " -r

# Star: optional middle name
./target/release/grabchars -m "c+ c* c+" -q "Full name: " -r
# Note: spaces are literals between the groups

# Optional: with or without area code
# Fixed part: nnn-nnnn, optional prefix: (nnn)
# This one is tricky — might need escaping or rethinking

# Optional single char
./target/release/grabchars -m "c?nnn" -q "Optional letter + 3 digits: "
# Type "A123" or just "123" (second char matches n, advances past c?)

# Star at end: fixed prefix, variable suffix
./target/release/grabchars -m "UUU-n+" -q "Serial: " -r
# Type ABC then auto-dash, then digits, Enter to finish

# Backspace through quantified groups
./target/release/grabchars -m "c+-n+" -q "Test BS: " -r
# Type "abc-12", backspace several times, should back through
# digits, then literal dash, then into letters

# Same-class adjacency (known limitation — greedy starves second)
./target/release/grabchars -m "c+c" -q "Degenerate: " -r
# Documents that this doesn't work well

# Quantifier on custom class
./target/release/grabchars -m "[aeiou]+" -q "Vowels: " -r

# Mixed fixed and quantified
./target/release/grabchars -m "Uc+, Uc+" -q "Two names: " -r
# Uppercase, letters, literal comma+space, uppercase, letters

# Enter without -r: should only accept when mask is satisfied
./target/release/grabchars -m "c+n+" -q "Need letters+digits: "
# Enter after just "abc" should be ignored (n+ not satisfied)
# Enter after "abc1" should work (both have min 1)
```

## Edge cases to handle

1. **Mask is ALL quantified with min 0**: `c*n*` — mask is immediately
   satisfied. Enter on empty input should... do what? Probably return
   empty string with exit code 0. Or use default if `-d` set.

2. **Leading zero-min elements**: `n?c+` — if first char is a letter,
   skip past n? and accept at c+.

3. **Trailing zero-min elements**: `c+n*` with `-r` — user types
   "abc" then Enter. n* is satisfied (0 matches). Accept.

4. **Multiple consecutive zero-min elements**: `n?c?x+` — first char
   could skip n? and c? if it's a hex digit.

5. **Literal between quantified elements can't be skipped**: `c+-n+`
   — the dash is required. Unlike `n?`, a literal has no quantifier
   and must be present. (Literals are always auto-inserted when
   reached, so this works naturally.)

6. **Empty mask after quantifier removal**: shouldn't happen, but
   validate.

## What NOT to change

- `main.rs` — no changes needed, wiring is already correct
- `input.rs`, `output.rs`, `select.rs`, `term.rs` — untouched
- The `MaskClass` enum — no changes
- The `-m` flag parsing in main — no changes
- External behavior of fixed-position masks — must be identical
