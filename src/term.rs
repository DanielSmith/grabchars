// Copyright 2026 Daniel Smith
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! Terminal setup and restore for grabchars.
//!
//! Replaces the BSD sgtty.h / SysV termio.h code from sys.c
//! with POSIX termios via libc.

use std::mem::MaybeUninit;
use std::sync::atomic::{AtomicBool, Ordering};

// Async-signal-safe storage for the saved termios.
//
// We write exactly once in init_term() before any signals are enabled,
// then read (never write again) in restore_saved() which may be called
// from a signal handler.  A Mutex is not async-signal-safe; this pattern
// avoids the theoretical deadlock where a signal fires while init_term()
// holds the lock.
static TERMIOS_SAVED: AtomicBool = AtomicBool::new(false);
static mut SAVED_TERMIOS: MaybeUninit<libc::termios> = MaybeUninit::uninit();

/// Put the terminal into raw (cbreak) mode with echo off.
/// Returns the original termios so we can restore it later.
pub fn init_term(flush: bool) -> libc::termios {
    unsafe {
        if libc::isatty(0) == 0 {
            eprintln!("grabchars: stdin is not a terminal");
            std::process::exit(255);
        }

        let mut orig: libc::termios = std::mem::zeroed();
        if libc::tcgetattr(0, &mut orig) != 0 {
            eprintln!("grabchars: tcgetattr failed");
            std::process::exit(255);
        }

        // Save a copy for signal handler restoration.
        // Written once here, before signals are enabled; never written again.
        // Use addr_of_mut! to get a raw pointer without creating a reference
        // (required by Rust 2024 static_mut_refs lint).
        std::ptr::addr_of_mut!(SAVED_TERMIOS).write(MaybeUninit::new(orig));
        TERMIOS_SAVED.store(true, Ordering::Release);

        let mut raw = orig;

        // Equivalent to CBREAK + ~ECHO on BSD:
        // Turn off canonical mode (line buffering) and echo.
        raw.c_lflag &= !(libc::ICANON | libc::ECHO);

        // Read one character at a time, no timeout
        raw.c_cc[libc::VMIN] = 1;
        raw.c_cc[libc::VTIME] = 0;

        if flush {
            // TCSAFLUSH: flush input buffer (like BSD TIOCSETP)
            libc::tcsetattr(0, libc::TCSAFLUSH, &raw);
        } else {
            // TCSANOW: don't flush (like BSD TIOCSETN)
            libc::tcsetattr(0, libc::TCSANOW, &raw);
        }

        orig
    }
}

/// Restore terminal to original settings.
pub fn restore_term(orig: &libc::termios) {
    unsafe {
        libc::tcsetattr(0, libc::TCSAFLUSH, orig);
    }
}

/// Restore from the saved static copy (used in signal handlers
/// where we can't pass parameters).
pub fn restore_saved() {
    if TERMIOS_SAVED.load(Ordering::Acquire) {
        unsafe {
            // addr_of! gives a raw pointer without creating a reference;
            // MaybeUninit<T> has the same layout as T, so the cast is valid.
            let tp = std::ptr::addr_of!(SAVED_TERMIOS) as *const libc::termios;
            libc::tcsetattr(0, libc::TCSAFLUSH, tp);
        }
    }
}
