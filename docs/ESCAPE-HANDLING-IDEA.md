# ESC Handling — Design Idea

## Current behavior (inconsistent across modes)

ESC handling is not uniform today:

| Mode | ESC behavior |
|------|-------------|
| Normal | Silently ignored — no-op (`main.rs`, grouped with `Unknown => {}`) |
| Mask | Clears buffer display, exits with code 255 |
| Select | Clears line, exits with code 255 |
| Select-LR | Clears line, exits with code 255 |

Normal mode already does what you might want. The inconsistency mostly affects
mask and select modes, and is likely what prompted the original question.

A secondary problem: exit code 255 is overloaded. It currently means "bad
flags", "other error", and "user pressed ESC" — three distinct situations that
a script cannot distinguish.

---

## Use cases

**1. Kiosk / embedded workflows**

A script that drives a multi-step terminal UI doesn't want ESC to bail out of
any individual step. The user should have to complete (or Ctrl+C) rather than
accidentally escape mid-flow.

**2. Script differentiation**

A script that presents a menu or prompt may want to treat "user pressed ESC" as
a meaningful signal — not an error. With the current fixed 255, there's no way
to tell ESC from a bad invocation.

---

## Proposed flag: `-B<n>`

Follows the existing `-E0`/`-E1` and `-Z0`/`-Z1` pattern: a letter flag with a
numeric modifier that always carries a value.

| Flag | Behavior |
|------|----------|
| *(none)* | Current behavior — ESC exits 255 in mask/select, no-op in normal |
| `-B0` | ESC is a no-op in all modes |
| `-B1`–`-B253` | ESC exits with code n |
| `-B255` | Explicit current behavior (ESC = 255) — redundant but consistent |

`-B0` reads naturally as "bail = off".

`-B254` should probably be disallowed or documented as a special case, since
254 is already the timeout-with-no-default exit code. Colliding with timeout
would make scripts harder to reason about.

### How it fits with existing exit codes

| Code | Current meaning |
|------|----------------|
| 0 | No input received |
| 1–253 | That many characters were read |
| 254 | Timeout with no default set |
| 255 | ESC pressed, bad flags, or other error |

With `-B<n>`, a script can separate "user cancelled with ESC" from "bad flags /
error" for the first time:

```bash
CHOICE=$(grabchars select "yes,no,cancel" -B200 -q "Continue? ")
case $? in
    0)   echo "Selected: yes" ;;
    1)   echo "Selected: no" ;;
    2)   echo "Selected: cancel" ;;
    200) echo "User pressed ESC — treat as cancel" ;;
    255) echo "Error invoking grabchars" ;;
esac
```

---

## The select-mode caveat

In select and select-LR modes, ESC is currently the only graceful cancel key.
If `-B0` disables it, the user has no in-band way to cancel a selection — they
would have to Ctrl+C, which restores the terminal less cleanly and exits the
whole script rather than just the grabchars call.

Options:
- Accept this tradeoff and document it — kiosk use is the explicit intent of `-B0`
- In a future iteration, consider a dedicated "cancel key" flag that can be
  rebound to something other than ESC

For now, document clearly: `-B0` in select modes means the user cannot cancel
the selection without killing the script.

---

## Implementation sketch

The `Flags` struct gains one field:

```rust
pub esc_code: Option<i32>,
// None     = current behavior (255 in mask/select, ignored in normal)
// Some(0)  = ignore ESC everywhere
// Some(n)  = exit with n on ESC
```

Each ESC handler becomes:

```rust
KeyInput::Escape => {
    match flags.esc_code {
        Some(0) => { /* no-op — ignore */ }
        Some(n) => { /* cleanup display, return n */ }
        None    => { /* existing behavior */ }
    }
}
```

Normal mode already ignores ESC unconditionally; its handler would gain the
same pattern for consistency.

---

## What to leave out

`-B` alone without a number — no obvious meaning, and inconsistent with the
existing flag pattern. Every `-B` invocation should carry a value.

A "rebind ESC to another key" feature — out of scope for this flag. If that
need arises it warrants its own design.
