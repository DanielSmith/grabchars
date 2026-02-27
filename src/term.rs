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

use std::sync::Mutex;

static SAVED_TERMIOS: Mutex<Option<libc::termios>> = Mutex::new(None);

/// Put the terminal into raw (cbreak) mode with echo off.
/// Returns the original termios so we can restore it later.
pub fn init_term(flush: bool) -> libc::termios {
    unsafe {
        let mut orig: libc::termios = std::mem::zeroed();
        libc::tcgetattr(0, &mut orig);

        // Save a copy for signal handler restoration
        *SAVED_TERMIOS.lock().unwrap() = Some(orig);

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
    if let Ok(guard) = SAVED_TERMIOS.lock() {
        if let Some(ref orig) = *guard {
            unsafe {
                libc::tcsetattr(0, libc::TCSAFLUSH, orig);
            }
        }
    }
}
