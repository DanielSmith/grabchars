# Installing grabchars

Four ways to install, in order of convenience.

---

## 1. cargo install (Rust toolchain required)

If you have Rust installed, this is the simplest path:

```bash
cargo install grabchars
```

The binary is placed in `~/.cargo/bin/`. If that directory is in your `$PATH`
(the Rust installer adds it automatically), grabchars is immediately available.

To update to a newer version later:

```bash
cargo install grabchars --force
```

---

## 2. Pre-built binary (no Rust required)

Download a pre-compiled binary from the
[GitHub Releases page](https://github.com/DanielSmith/grabchars/releases).

Choose the archive for your platform:

| File | Platform |
|------|---------|
| `grabchars-x86_64-apple-darwin.tar.gz` | macOS Intel |
| `grabchars-aarch64-apple-darwin.tar.gz` | macOS Apple Silicon (M1/M2/M3/M4) |
| `grabchars-x86_64-unknown-linux-gnu.tar.gz` | Linux x86_64 |
| `grabchars-aarch64-unknown-linux-gnu.tar.gz` | Linux ARM64 — Raspberry Pi 4/5 (64-bit OS), AWS Graviton |
| `grabchars-armv7-unknown-linux-gnueabihf.tar.gz` | Linux ARMv7 32-bit — Raspberry Pi 2/3, or Pi 4 running a 32-bit OS |

**Which Raspberry Pi binary do I need?**
Pi 4 and Pi 5 ship with 64-bit Raspberry Pi OS by default — use `aarch64`.
Pi 2 and Pi 3, or any Pi running a 32-bit OS — use `armv7`.
Not sure? Run `uname -m` on your Pi: `aarch64` = 64-bit, `armv7l` = 32-bit.

Then install:

```bash
# Example for macOS Apple Silicon — adjust filename for your platform
tar -xzf grabchars-aarch64-apple-darwin.tar.gz
sudo mv grabchars /usr/local/bin/
```

Verify:

```bash
grabchars --version
```

---

## 3. Homebrew (macOS and Linux)

```bash
brew install DanielSmith/grabchars/grabchars
```

This taps the
[DanielSmith/homebrew-grabchars](https://github.com/DanielSmith/homebrew-grabchars)
repository and installs grabchars in one step.

To update:

```bash
brew upgrade grabchars
```

---

## 4. AUR (Arch Linux and derivatives — CachyOS, Manjaro, etc.)

Two packages are available. Choose one:

**Pre-built binary** (no Rust toolchain required):
```bash
paru -S grabchars-bin
# or
yay -S grabchars-bin
```

**Build from source** (requires Rust):
```bash
paru -S grabchars
# or
yay -S grabchars
```

The two packages conflict with each other — install one or the other. Both
provide the `grabchars` command.

---

## 5. Build from source

Requires [Rust](https://rustup.rs/) 1.85 or later (edition 2024).

```bash
git clone https://github.com/DanielSmith/grabchars.git
cd grabchars
cargo build --release
```

The binary is at `target/release/grabchars`. Copy it wherever you like:

```bash
sudo cp target/release/grabchars /usr/local/bin/
```

---

## Getting started

Once installed, verify it works:

```bash
grabchars --version
grabchars -q "Press any key: "
```

A few things to try:

```bash
# Press y or n — anything else is ignored
grabchars -c yn -q "Continue? [y/n] "

# Read 4 characters, auto-exit after the 4th (no Enter needed)
grabchars -n4 -q "PIN: "

# 5-second timeout, default to 'n' if no input
grabchars -c yn -d n -t5 -q "Continue? [y/N] "

# Phone number — parens, space, and dash auto-inserted as you type
grabchars -m "(nnn) nnn-nnnn" -q "Phone: "

# Choose from a list with filter-as-you-type
grabchars select "red,green,blue,yellow" -q "Color: "
```

For full documentation see:

- `docs/cookbook.md` — 21 runnable examples covering every feature
- `docs/maskInput.md` — mask mode syntax reference (`-m`)
- `docs/RAW-MODE.md` — raw byte capture mode (`-R`)
- `README.md` — flags reference and comparison with other tools

---

## System requirements

- POSIX-compliant Unix: Linux, macOS, or WSL
- A real TTY (grabchars reads directly from the terminal — it will not work
  when stdin is a pipe or redirected file)
