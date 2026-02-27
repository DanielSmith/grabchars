# grabchars Documentation

## [cookbook.md](cookbook.md)

Runnable examples covering every feature — copy-paste ready. Includes normal
mode, character filtering, mask mode, select/select-lr, timeouts, defaults,
silent mode, output routing, and real-world script patterns.

## [maskInput.md](maskInput.md)

Mask syntax reference for the `-m` flag. Covers character classes (`U`, `l`,
`c`, `n`, `x`, `p`, `W`, `.`), bracket expressions (`[abc]`), quantifiers
(`*`, `+`, `?`), literals, and auto-insertion behavior.

## [RUST-PORT.md](RUST-PORT.md)

Architecture and design notes for the Rust port. Covers the full feature set,
module structure, signal handling, key input pipeline, terminal handling, and
comparison with the original C implementation.

## [quantifiers-plan.md](quantifiers-plan.md)

Design document for the mask quantifier implementation (`*`, `+`, `?`). Useful
for understanding the greedy matching strategy and edge cases in `mask.rs`.

## [README-1990](README-1990)

The original 1990 readme posted to `comp.sources.misc` with the C source.
Historical reference.
