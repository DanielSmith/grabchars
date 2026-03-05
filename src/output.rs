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

//! ANSI escape sequences, cursor helpers, and output functions.

use std::io::{self, Write};
use std::sync::atomic::Ordering;

use crate::{Flags, JsonStyle, EXIT_STAT};

// ---------------------------------------------------------------------------
// ANSI escape sequences
// ---------------------------------------------------------------------------

const CSI: &str = "\x1b[";
pub const CURSOR_LEFT: &[u8] = b"\x1b[D";
pub const CURSOR_RIGHT: &[u8] = b"\x1b[C";
pub const CLEAR_TO_EOL: &[u8] = b"\x1b[K";
pub const REVERSE_ON: &[u8] = b"\x1b[7m";
pub const REVERSE_OFF: &[u8] = b"\x1b[27m";

/// Move cursor left by `n` columns.
pub fn cursor_left_n(stderr: &mut impl Write, n: usize) {
    let _ = write!(stderr, "{}{}D", CSI, n);
}

/// Move cursor right by `n` columns.
pub fn cursor_right_n(stderr: &mut impl Write, n: usize) {
    let _ = write!(stderr, "{}{}C", CSI, n);
}

/// Redraw the entire editing buffer on stderr and position the cursor.
/// `prev_cursor_pos` is where the cursor was before the edit (used to back up).
pub fn redraw_input(buffer: &[u8], cursor_pos: usize, prev_cursor_pos: usize) {
    let mut stderr = io::stderr();
    if prev_cursor_pos > 0 {
        cursor_left_n(&mut stderr, prev_cursor_pos);
    }
    let _ = stderr.write_all(CLEAR_TO_EOL);
    let _ = stderr.write_all(buffer);
    let tail = buffer.len() - cursor_pos;
    if tail > 0 {
        cursor_left_n(&mut stderr, tail);
    }
    let _ = stderr.flush();
}

pub fn trailing_newline_if(flags: &Flags) {
    if flags.trailing_newline {
        let _ = io::stderr().write_all(b"\n");
        let _ = io::stderr().flush();
    }
}

pub fn handle_default(default_string: &str, flags: &Flags, output_to_stderr: bool) {
    if !flags.silent {
        output_str(default_string, output_to_stderr, flags.both || flags.ret_key);
    }
    EXIT_STAT.store(default_string.len() as i32, Ordering::Relaxed);
}

fn write_routed(to_stderr: bool, both: bool, emit: impl Fn(&mut dyn Write)) {
    if to_stderr {
        emit(&mut io::stderr());
        let _ = io::stderr().flush();
        if both {
            emit(&mut io::stdout());
            let _ = io::stdout().flush();
        }
    } else {
        emit(&mut io::stdout());
        let _ = io::stdout().flush();
        if both {
            emit(&mut io::stderr());
            let _ = io::stderr().flush();
        }
    }
}

pub fn output_char(ch: char, to_stderr: bool, both: bool) {
    write_routed(to_stderr, both, |w| { let _ = write!(w, "{}", ch); });
}

pub fn output_str(s: &str, to_stderr: bool, both: bool) {
    write_routed(to_stderr, both, |w| { let _ = write!(w, "{}", s); });
}

pub fn output_bytes(buf: &[u8], to_stderr: bool, both: bool) {
    write_routed(to_stderr, both, |w| { let _ = w.write_all(buf); });
}

// ---------------------------------------------------------------------------
// JSON output (-J)
// ---------------------------------------------------------------------------

pub struct JsonPayload {
    pub value: String,
    pub exit: i32,
    pub status: &'static str,
    pub mode: &'static str,
    pub timed_out: bool,
    pub default_used: bool,
    pub index: Option<i32>,
    pub filter: Option<String>,
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                out.push_str(&format!("\\u{:04x}", c as u32));
            }
            c => out.push(c),
        }
    }
    out
}

pub fn emit_json(payload: &JsonPayload, style: JsonStyle, to_stderr: bool, both: bool) {
    let idx = match payload.index {
        Some(i) => i.to_string(),
        None => "null".to_string(),
    };
    let flt = match &payload.filter {
        Some(s) => format!("\"{}\"", json_escape(s)),
        None => "null".to_string(),
    };
    let json = match style {
        JsonStyle::Compact => format!(
            "{{\"value\":\"{}\",\"exit\":{},\"status\":\"{}\",\"mode\":\"{}\",\"timed_out\":{},\"default_used\":{},\"index\":{},\"filter\":{}}}",
            json_escape(&payload.value), payload.exit, payload.status, payload.mode,
            payload.timed_out, payload.default_used, idx, flt
        ),
        JsonStyle::Pretty => format!(
            "{{\n  \"value\": \"{}\",\n  \"exit\": {},\n  \"status\": \"{}\",\n  \"mode\": \"{}\",\n  \"timed_out\": {},\n  \"default_used\": {},\n  \"index\": {},\n  \"filter\": {}\n}}",
            json_escape(&payload.value), payload.exit, payload.status, payload.mode,
            payload.timed_out, payload.default_used, idx, flt
        ),
    };
    write_routed(to_stderr, both, |w| { let _ = write!(w, "{}", json); });
}
