# Filter Style Flag (-F)

The `-F` flag controls how the text the user types is matched against the
option list in `select` and `select-lr` modes. Three styles are available:

| Flag  | Style    | Matches when…                                         |
|-------|----------|-------------------------------------------------------|
| `-Fp` | prefix   | option **starts with** the filter (default)           |
| `-Ff` | fuzzy    | every filter character appears in the option **in order**, with anything in between |
| `-Fc` | contains | option **contains** the filter as a substring anywhere |

The default is `-Fp` (prefix). Existing scripts that do not pass `-F` are
unaffected.

Matching is always case-insensitive.

---

## Prefix mode (`-Fp`, default)

The filter text must match the **beginning** of an option. This is the
tightest filter: typing three characters narrows to options that literally
start with those three characters.

```
grabchars select-lr 'san francisco, santa maria, san jose, san luis obispo, san diego'
```

| Filter typed | Matches                                              |
|--------------|------------------------------------------------------|
| _(empty)_    | all five                                             |
| `s`          | all five (all start with `s`)                        |
| `sa`         | all five (all start with `sa`)                       |
| `san`        | san francisco, san jose, san luis obispo, san diego  |
| `san f`      | san francisco                                        |
| `santa`      | santa maria                                          |
| `ny`         | _(no matches)_                                       |

Use prefix mode when your option list has a natural hierarchical structure
(e.g. command names, file path prefixes, country codes).

---

## Fuzzy mode (`-Ff`)

Each character of the filter must appear somewhere in the option, **in
order**, but any number of other characters may appear between them. This
is equivalent to putting `.*` between every character of the filter — the
regex for filter `so` would be `s.*o`.

```
grabchars select-lr -Ff 'san francisco, santa maria, san jose, san luis obispo, san diego, new haven, new york, saint louis'
```

| Filter typed | Matches                                                              | Why                                                        |
|--------------|----------------------------------------------------------------------|------------------------------------------------------------|
| `s`          | san francisco, santa maria, san jose, san luis obispo, san diego, saint louis | contain `s`                                  |
| `so`         | san francisco, san jose, san luis obispo, san diego                  | `s` then `o` found in order                                |
| `sf`         | san francisco                                                        | `s` then `f`                                               |
| `sl`         | san luis obispo, saint louis                                         | `s` then `l`                                               |
| `nek`        | new york                                                             | `n`·`e`·`k` all present in order (`n`ew·`y`or`k`)         |
| `nh`         | new haven                                                            | `n`ew·`h`aven                                              |
| `nk`         | new york                                                             | `n`ew·yor`k`                                               |
| `xyz`        | _(no matches)_                                                       |                                                            |

### How fuzzy matching works

The algorithm is a standard **subsequence check**. It walks through the
option string with a single forward pass, consuming one filter character
each time a match is found:

```
filter = "so"
option = "san francisco"

step 1: look for 's' → found at position 0
step 2: from position 1 onward, look for 'o' → found in "francisco"
all filter chars found → match
```

```
filter = "so"
option = "santa maria"

step 1: look for 's' → found at position 0
step 2: from position 1 onward, look for 'o' → not found
→ no match
```

The key property: once a character is matched at position N, the next
filter character must appear at position N+1 or later. The relative order
of the filter characters is always preserved.

Fuzzy mode is most useful when options have long names and you want to
narrow the list by typing a short mnemonic rather than a full prefix.

---

## Contains mode (`-Fc`)

The filter text must appear as a **contiguous substring** somewhere inside
the option. Position does not matter — it can be at the start, middle, or
end.

```
grabchars select-lr -Fc 'new haven, new york, newest first, renew annually'
```

| Filter typed | Matches                                          |
|--------------|--------------------------------------------------|
| `new`        | new haven, new york, newest first, renew annually |
| `ew`         | new haven, new york, newest first, renew annually |
| `ork`        | new york                                         |
| `aven`       | new haven                                        |
| `xyz`        | _(no matches)_                                   |

Contains mode is useful when you know a word or fragment that appears
somewhere in the option but not necessarily at the start — for example,
filtering a list of city names by state abbreviation that appears at the
end, or searching descriptions that start with a category prefix.

---

## Comparison of the three modes

Using the list `'ant, antenna, can, scan, plan, planet'`:

| Filter | Prefix          | Fuzzy                          | Contains              |
|--------|-----------------|--------------------------------|-----------------------|
| `an`   | ant, antenna    | ant, antenna, can, scan, plan, planet | ant, antenna, can, scan, plan |
| `can`  | can             | can, scan, plan                | can, scan             |
| `pl`   | plan, planet    | plan, planet                   | plan, planet          |
| `pln`  | _(none)_        | plan, planet                   | _(none)_              |
| `net`  | _(none)_        | antenna, planet                | antenna, planet       |

Note that fuzzy is the most permissive: it matches anything that contains
the filter characters in order, regardless of adjacency.

---

## Usage

```
grabchars select    -F<p|f|c> <options>
grabchars select-lr -F<p|f|c> <options>
```

`-F` alone (no letter) is treated as `-Fp` (prefix).

The flag may be placed anywhere among the other flags:

```bash
# These are all equivalent
grabchars select-lr -Ff 'a, b, c'
grabchars select-lr -Ff -d a 'a, b, c'
grabchars select-lr -d a -Ff 'a, b, c'
```

---

## Combining with other select flags

`-F` is orthogonal to all other select flags:

| Flag combination | Effect |
|------------------|--------|
| `-Ff -Hr`        | fuzzy filter + reverse-video highlight |
| `-Ff -Hb`        | fuzzy filter + bracket highlight |
| `-Fc -d default` | contains filter with a pre-selected default |
| `-Ff -t 10`      | fuzzy filter with 10-second timeout |
| `-Fc -U`         | contains filter, input mapped to uppercase |
| `-Ff --file list.txt` | fuzzy filter, options loaded from a file |

---

## Shell scripting

```bash
# Fuzzy select, capture result in a variable
city=$(grabchars select-lr -Ff \
  'san francisco, santa maria, san jose, san luis obispo, san diego')
echo "Selected: $city"

# Contains filter from a file, silent mode, exit code = option index
grabchars select -Fc -s --file /etc/shells
case $? in
  0) echo "first shell selected" ;;
  1) echo "second shell selected" ;;
esac

# Fuzzy with timeout and default
result=$(grabchars select-lr -Ff -t 5 -d 'new york' \
  'new haven, new york, new orleans')
```

---

## Implementation

The filter style is stored in `Flags.filter_style` as a `FilterStyle` enum
(`Prefix`, `Fuzzy`, `Contains`). It is parsed from `-F` in the same way
`-H` parses `HighlightStyle`.

In `select.rs`, `compute_matches()` dispatches on the style:

```rust
match style {
    FilterStyle::Prefix   => opt_lower.starts_with(&filter_lower),
    FilterStyle::Fuzzy    => fuzzy_match(&opt_lower, &filter_lower),
    FilterStyle::Contains => opt_lower.contains(&filter_lower),
}
```

The fuzzy implementation is a single forward pass with no backtracking:

```rust
fn fuzzy_match(opt: &str, filter: &str) -> bool {
    let mut opt_chars = opt.chars();
    for fc in filter.chars() {
        if !opt_chars.any(|c| c == fc) {
            return false;
        }
    }
    true
}
```

`Iterator::any()` advances the iterator, so each successful match
establishes a new minimum position for the next filter character. This
guarantees O(n) time per option where n is the length of the option string.

The same `compute_matches()` function is used by both `run_select_mode()`
and `run_select_lr_mode()`, so the behaviour is identical in vertical and
horizontal select.

---

## Caveats

**Fuzzy can produce unexpected matches on long options.** Because any
character spacing is allowed, a short filter like `ao` will match
`san francisco` (the `a` in `san`, the `o` in `francisco`). This is
expected behavior, but can feel surprising on lists with long similar
entries. If you need tighter matching, use contains or prefix.

**Contains matches substrings, not words.** `-Fc` with filter `an` matches
`antenna`, `can`, `plan`, and `scan` — not just options where `an` appears
as a complete word. There is no word-boundary mode.

**The filter is not a regex.** In fuzzy mode, `.` matches a literal dot,
not any character. The `.*` analogy is conceptual, not syntactic — the
filter input is treated as plain text in all three modes.

**Case folding is full Unicode lowercase.** Both the filter and the option
are lowercased with Rust's `.to_lowercase()` before comparison. This handles
ASCII correctly and gives reasonable results for common accented characters,
but complex Unicode case-folding edge cases (e.g. the German `ß`) may not
produce intuitive matches on every platform.
