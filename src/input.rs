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

//! Key input parsing: reading raw bytes, escape sequences, and logical keys.

use std::io;

pub enum KeyInput {
    Char(u8),
    Backspace,
    Delete,
    Left,
    Right,
    Up,
    Down,
    Home,
    End,
    Tab,
    Escape,
    KillToEnd,     // Ctrl-K: delete from cursor to end of line
    KillToStart,   // Ctrl-U: delete from start of line to cursor
    KillWordBack,  // Ctrl-W: delete word backward
    Enter,
    Unknown,
}

/// Read one logical key from stdin.  Handles escape sequences for arrows, etc.
pub fn read_key(fd: i32) -> Result<KeyInput, io::Error> {
    let b = read_byte(fd)?;
    match b {
        0x01 => Ok(KeyInput::Home),          // Ctrl-A
        0x02 => Ok(KeyInput::Left),          // Ctrl-B
        0x04 => Ok(KeyInput::Delete),        // Ctrl-D
        0x05 => Ok(KeyInput::End),           // Ctrl-E
        0x06 => Ok(KeyInput::Right),         // Ctrl-F
        0x0B => Ok(KeyInput::KillToEnd),     // Ctrl-K
        0x15 => Ok(KeyInput::KillToStart),   // Ctrl-U
        0x17 => Ok(KeyInput::KillWordBack),  // Ctrl-W
        0x09 => Ok(KeyInput::Tab),
        0x7F | 0x08 => Ok(KeyInput::Backspace),
        0x0A | 0x0D => Ok(KeyInput::Enter),
        0x1B => parse_escape_seq(fd),
        _ => Ok(KeyInput::Char(b)),
    }
}

pub fn read_byte(fd: i32) -> Result<u8, io::Error> {
    let mut buf = [0u8; 1];
    let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, 1) };
    if n == 1 {
        return Ok(buf[0]);
    }
    if n == 0 {
        return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "EOF"));
    }
    Err(io::Error::last_os_error())
}

/// Check if a byte is available on the given fd within `timeout_ms` milliseconds.
fn byte_available(fd: i32, timeout_ms: i32) -> bool {
    let mut pfd = libc::pollfd {
        fd,
        events: libc::POLLIN,
        revents: 0,
    };
    let ret = unsafe { libc::poll(&mut pfd, 1, timeout_ms) };
    ret > 0 && (pfd.revents & libc::POLLIN) != 0
}

fn parse_escape_seq(fd: i32) -> Result<KeyInput, io::Error> {
    // Check if another byte follows ESC within 50ms; if not, it's a bare Escape
    if !byte_available(fd, 50) {
        return Ok(KeyInput::Escape);
    }
    let b2 = match read_byte(fd) {
        Ok(b) => b,
        Err(_) => return Ok(KeyInput::Escape),
    };
    if b2 != b'[' {
        return Ok(KeyInput::Unknown);
    }
    let b3 = match read_byte(fd) {
        Ok(b) => b,
        Err(_) => return Ok(KeyInput::Unknown),
    };
    match b3 {
        b'A' => Ok(KeyInput::Up),
        b'B' => Ok(KeyInput::Down),
        b'C' => Ok(KeyInput::Right),
        b'D' => Ok(KeyInput::Left),
        b'H' => Ok(KeyInput::Home),
        b'F' => Ok(KeyInput::End),
        // Sequences like \x1b[3~  \x1b[1~  \x1b[4~
        b'1' | b'3' | b'4' => {
            let b4 = match read_byte(fd) {
                Ok(b) => b,
                Err(_) => return Ok(KeyInput::Unknown),
            };
            if b4 == b'~' {
                match b3 {
                    b'3' => Ok(KeyInput::Delete),
                    b'1' => Ok(KeyInput::Home),
                    b'4' => Ok(KeyInput::End),
                    _ => Ok(KeyInput::Unknown),
                }
            } else {
                Ok(KeyInput::Unknown)
            }
        }
        _ => {
            // Consume trailing '~' for other CSI sequences like \x1b[5~ etc.
            if b3.is_ascii_digit() {
                let _ = read_byte(fd); // consume ~
            }
            Ok(KeyInput::Unknown)
        }
    }
}
