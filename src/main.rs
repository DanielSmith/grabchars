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

//! grabchars - get keystrokes directly from user
//!
//! A Rust port / update of my 1988 grabchars utility.

use std::io::{self, Write};
use std::os::unix::io::AsRawFd;
use std::process;
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};

mod input;
mod mask;
mod output;
mod select;
mod term;

use input::KeyInput;
use output::{CURSOR_LEFT, CURSOR_RIGHT, CLEAR_TO_EOL};

// ---------------------------------------------------------------------------
// Shared types and globals
// ---------------------------------------------------------------------------

pub static TIMED_OUT: AtomicBool = AtomicBool::new(false);
pub static EXIT_STAT: AtomicI32 = AtomicI32::new(-1);

pub enum HighlightStyle {
    Reverse,
    Bracket,
    Arrow,
}

impl Default for HighlightStyle {
    fn default() -> Self {
        HighlightStyle::Reverse
    }
}

#[derive(Default)]
pub struct Flags {
    pub both: bool,
    pub check: bool,
    pub exclude: bool,
    pub dflt: bool,
    pub flush: bool,
    pub ret_key: bool,
    pub silent: bool,
    pub erase: Option<bool>, // None = unset (auto), Some(true) = on, Some(false) = off
    pub lower: bool,
    pub upper: bool,
    pub trailing_newline: bool, // -Z: print trailing newline to stderr (default: true)
    pub highlight_style: HighlightStyle,
}

impl Flags {
    fn new() -> Self {
        Flags {
            both: false,
            check: false,
            exclude: false,
            dflt: false,
            flush: false,
            ret_key: false,
            silent: false,
            erase: None,
            lower: false,
            upper: false,
            trailing_newline: true,
            highlight_style: HighlightStyle::Reverse,
        }
    }
}

// ---------------------------------------------------------------------------
// Usage
// ---------------------------------------------------------------------------

fn print_usage() {
    let usage = [
        "usage: grabchars           gets one keystroke",
        "       -b                   output to stdout and stderr",
        "       -c<valid characters> only <valid chars> are returned",
        "       -C<excluded chars>   exclude these characters from input",
        "       -d<char(s)>          default char or string to return",
        "       -e                   output to stderr instead of stdout",
        "       -f                   flush any previous input before reading",
        "       -h                   help screen",
        "       -m<mask>             mask for positional input (U=upper l=lower c=alpha n=digit x=hex p=punct .=any)",
        "       -n<number>           number of characters to read",
        "       -p<prompt>           prompt to help user",
        "       -q<prompt>           prompt to help user (through stderr)",
        "       -r                   RETURN key exits (use with -n)",
        "       -s                   silent, just return status",
        "       -t<seconds>          timeout after <seconds>",
        "       -E/-E1/-E0            enable/disable line editing (default: on when -n > 1)",
        "       -U/-L                upper/lower case mapping on input",
        "       -Z0/-Z1              trailing newline to stderr (default: on)",
        "       --version            show version and exit",
        "",
        "grabchars -c aeiou          get one of the vowels",
        "grabchars -n4               get four characters",
        "grabchars -t2               timeout after two seconds",
        "grabchars -p 'prompt ' -n 3 print a prompt and grab three characters",
        "",
        "grabchars select <options>      inline select from comma-separated list",
        "grabchars select --file <f>     inline select from file (one per line)",
        "grabchars select-lr <options>   horizontal select with all matches shown",
    ];
    for line in &usage {
        eprintln!("{}", line);
    }
}

fn print_select_usage() {
    let usage = [
        "usage: grabchars select <options>      inline select from comma-separated list",
        "       grabchars select --file <f>     inline select from file (one per line)",
        "       grabchars select-lr <options>   horizontal select with all matches shown",
        "       -p<prompt>                      prompt text",
        "       -d<default>                     default selection",
        "       -t<seconds>                     timeout",
        "       -s                              silent mode",
        "       -e                              output to stderr",
        "       -b                              output to both stdout and stderr",
        "       -U/-L                           case mapping on filter input",
        "       -H<r|b|a>                       highlight style: reverse/bracket/arrow (default: r)",
        "       -Z0/-Z1                         trailing newline control",
    ];
    for line in &usage {
        eprintln!("{}", line);
    }
}

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

struct ArgParser {
    args: Vec<String>,
    pos: usize,
}

impl ArgParser {
    fn new() -> Self {
        ArgParser {
            args: std::env::args().collect(),
            pos: 1,
        }
    }

    fn get_optarg(&mut self, rest: &str) -> Option<String> {
        if !rest.is_empty() {
            Some(rest.to_string())
        } else {
            self.pos += 1;
            if self.pos < self.args.len() {
                Some(self.args[self.pos].clone())
            } else {
                None
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Signals
// ---------------------------------------------------------------------------

fn setup_signals() {
    unsafe {
        libc::signal(libc::SIGINT, signal_handler as libc::sighandler_t);
        libc::signal(libc::SIGQUIT, signal_handler as libc::sighandler_t);
        libc::signal(libc::SIGTSTP, signal_handler as libc::sighandler_t);
    }
}

extern "C" fn signal_handler(_sig: libc::c_int) {
    term::restore_saved();
    unsafe {
        libc::_exit(EXIT_STAT.load(Ordering::Relaxed));
    }
}

fn setup_alarm(secs: u32) {
    unsafe {
        // Use sigaction instead of signal() for portable behavior.
        // signal() varies by platform: macOS sets SA_RESTART (read() resumes
        // after signal, never returning EINTR), glibc on Linux also sets it.
        // sigaction with sa_flags=0 guarantees read() returns EINTR on all
        // POSIX systems (macOS, Linux, WSL).
        let mut sa: libc::sigaction = std::mem::zeroed();
        sa.sa_sigaction = alarm_handler as libc::sighandler_t;
        sa.sa_flags = 0;
        libc::sigaction(libc::SIGALRM, &sa, std::ptr::null_mut());
        libc::alarm(secs);
    }
}

extern "C" fn alarm_handler(_sig: libc::c_int) {
    TIMED_OUT.store(true, Ordering::Relaxed);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() {
    let mut flags = Flags::new();
    let mut how_many: usize = 1;
    let mut timeout_secs: u32 = 0;
    let mut valid_pattern: Option<regex::Regex> = None;
    let mut exclude_pattern: Option<regex::Regex> = None;
    let mut default_string: Option<String> = None;
    let mut output_to_stderr = false;
    let mut mask_string: Option<String> = None;

    // Detect select subcommand
    let mut select_mode = false;
    let mut select_lr_mode = false;
    let mut select_options: Vec<String> = Vec::new();

    let mut parser = ArgParser::new();

    // --version flag
    if parser.pos < parser.args.len() && parser.args[parser.pos] == "--version" {
        eprintln!("grabchars {}", env!("CARGO_PKG_VERSION"));
        process::exit(0);
    }

    if parser.pos < parser.args.len()
        && (parser.args[parser.pos] == "select" || parser.args[parser.pos] == "select-lr")
    {
        select_lr_mode = parser.args[parser.pos] == "select-lr";
        select_mode = true;
        parser.pos += 1; // consume "select"

        // Look for options source: --file or positional comma-separated string
        // We need to scan for --file among the remaining args, or pick up the
        // first non-flag arg as the comma-separated list.
        let mut file_path: Option<String> = None;
        let mut positional_opts: Option<String> = None;

        // Pre-scan for --file (need to find it before normal flag parsing)
        let mut pre_pos = parser.pos;
        while pre_pos < parser.args.len() {
            if parser.args[pre_pos] == "--file" {
                if pre_pos + 1 < parser.args.len() {
                    file_path = Some(parser.args[pre_pos + 1].clone());
                    // Remove --file and its argument from args so flag parser doesn't see them
                    parser.args.remove(pre_pos);
                    parser.args.remove(pre_pos);
                } else {
                    eprintln!("select: --file requires a filename");
                    process::exit(255);
                }
                break;
            }
            pre_pos += 1;
        }

        // If no --file, look for first non-flag arg as comma-separated options
        if file_path.is_none() {
            let mut pre_pos2 = parser.pos;
            while pre_pos2 < parser.args.len() {
                let a = &parser.args[pre_pos2];
                if !a.starts_with('-') && a != "--" {
                    positional_opts = Some(parser.args.remove(pre_pos2));
                    break;
                }
                pre_pos2 += 1;
            }
        }

        if let Some(ref fp) = file_path {
            match std::fs::read_to_string(fp) {
                Ok(contents) => {
                    select_options = contents
                        .lines()
                        .filter(|l| !l.is_empty())
                        .map(|l| l.to_string())
                        .collect();
                }
                Err(e) => {
                    eprintln!("select: cannot read file '{}': {}", fp, e);
                    process::exit(255);
                }
            }
        } else if let Some(ref opts_str) = positional_opts {
            select_options = opts_str.split(',').map(|s| s.to_string()).collect();
        }

        if select_options.is_empty() {
            print_select_usage();
            process::exit(255);
        }
    }

    while parser.pos < parser.args.len() {
        let arg = parser.args[parser.pos].clone();
        if !arg.starts_with('-') || arg == "--" {
            break;
        }

        let chars: Vec<char> = arg[1..].chars().collect();
        let mut i = 0;
        while i < chars.len() {
            let rest: String = chars[i + 1..].iter().collect();
            match chars[i] {
                'b' => flags.both = true,
                'c' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-c option: must have at least one valid character");
                        process::exit(255);
                    });
                    if val.is_empty() {
                        eprintln!("-c option: must have at least one valid character");
                        process::exit(255);
                    }
                    flags.check = true;
                    let pattern = if val.starts_with('[') && val.ends_with(']') {
                        format!("^{}$", val)
                    } else {
                        format!("^[{}]$", val)
                    };
                    valid_pattern = Some(regex::Regex::new(&pattern).unwrap_or_else(|e| {
                        eprintln!("-c option: {}", e);
                        process::exit(255);
                    }));
                    break;
                }
                'd' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-d option: must have at least one character for default");
                        process::exit(255);
                    });
                    if val.is_empty() {
                        eprintln!("-d option: must have at least one character for default");
                        process::exit(255);
                    }
                    flags.dflt = true;
                    default_string = Some(val);
                    break;
                }
                'e' => output_to_stderr = true,
                'f' => flags.flush = true,
                'h' => {
                    if select_mode {
                        print_select_usage();
                    } else {
                        print_usage();
                    }
                    process::exit(255);
                }
                'm' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-m option: must provide a mask string");
                        process::exit(255);
                    });
                    if val.is_empty() {
                        eprintln!("-m option: must provide a mask string");
                        process::exit(255);
                    }
                    mask_string = Some(val);
                    break;
                }
                'n' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-n option: need a number");
                        process::exit(255);
                    });
                    how_many = val.parse::<usize>().unwrap_or(0);
                    if how_many == 0 {
                        eprintln!("-n option: number of characters to read must be greater than zero");
                        process::exit(255);
                    }
                    break;
                }
                'p' => {
                    let val = parser.get_optarg(&rest).unwrap_or_default();
                    print!("{}", val);
                    let _ = io::stdout().flush();
                    break;
                }
                'q' => {
                    let val = parser.get_optarg(&rest).unwrap_or_default();
                    eprint!("{}", val);
                    let _ = io::stderr().flush();
                    break;
                }
                'r' => flags.ret_key = true,
                's' => flags.silent = true,
                't' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-t option: need a number");
                        process::exit(255);
                    });
                    timeout_secs = val.parse::<u32>().unwrap_or(0);
                    if timeout_secs == 0 {
                        eprintln!("-t option: number of seconds to timeout must be greater than zero");
                        process::exit(255);
                    }
                    break;
                }
                'C' => {
                    let val = parser.get_optarg(&rest).unwrap_or_else(|| {
                        eprintln!("-C option: must have at least one character to exclude");
                        process::exit(255);
                    });
                    if val.is_empty() {
                        eprintln!("-C option: must have at least one character to exclude");
                        process::exit(255);
                    }
                    flags.exclude = true;
                    let pattern = if val.starts_with('[') && val.ends_with(']') {
                        format!("^{}$", val)
                    } else {
                        format!("^[{}]$", val)
                    };
                    exclude_pattern = Some(regex::Regex::new(&pattern).unwrap_or_else(|e| {
                        eprintln!("-C option: {}", e);
                        process::exit(255);
                    }));
                    break;
                }
                'E' => {
                    if rest.starts_with('0') {
                        flags.erase = Some(false);
                    } else {
                        flags.erase = Some(true);
                    }
                    break;
                }
                'L' => {
                    flags.lower = true;
                    flags.upper = false;
                }
                'U' => {
                    flags.upper = true;
                    flags.lower = false;
                }
                'H' => {
                    // -H or -Hr = reverse, -Hb = bracket, -Ha = arrow
                    if rest.is_empty() || rest.starts_with('r') {
                        flags.highlight_style = HighlightStyle::Reverse;
                    } else if rest.starts_with('b') {
                        flags.highlight_style = HighlightStyle::Bracket;
                    } else if rest.starts_with('a') {
                        flags.highlight_style = HighlightStyle::Arrow;
                    } else {
                        eprintln!("-H option: unrecognized style '{}' (use r, b, or a)", &rest[..1]);
                        process::exit(255);
                    }
                    break;
                }
                'Z' => {
                    // -Z0 = no trailing newline, -Z1 = trailing newline
                    // -Z alone is the same as -Z1
                    if rest.starts_with('0') {
                        flags.trailing_newline = false;
                    } else {
                        flags.trailing_newline = true;
                    }
                    break;
                }
                _ => {
                    print_usage();
                    process::exit(255);
                }
            }
            i += 1;
        }
        parser.pos += 1;
    }

    // Set up terminal raw mode
    let orig_termios = term::init_term(flags.flush);

    // Install cleanup on panic
    let orig_for_panic = orig_termios;
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        term::restore_term(&orig_for_panic);
        default_hook(info);
    }));

    // Signal handlers
    setup_signals();

    // Timeout alarm
    if timeout_secs > 0 {
        setup_alarm(timeout_secs);
    }

    // Select mode: branch to dedicated handler
    if select_mode {
        let stdin_fd = io::stdin().as_raw_fd();
        let exit_code = if select_lr_mode {
            select::run_select_lr_mode(
                &select_options,
                &flags,
                &default_string,
                output_to_stderr,
                stdin_fd,
            )
        } else {
            select::run_select_mode(
                &select_options,
                &flags,
                &default_string,
                output_to_stderr,
                stdin_fd,
            )
        };
        output::trailing_newline_if(&flags);
        term::restore_term(&orig_termios);
        process::exit(exit_code);
    }

    // Mask mode: branch to dedicated handler
    if let Some(ref ms) = mask_string {
        let parsed_mask = mask::parse_mask(ms);
        if parsed_mask.is_empty() {
            eprintln!("-m option: mask is empty");
            term::restore_term(&orig_termios);
            process::exit(255);
        }
        let stdin_fd = io::stdin().as_raw_fd();
        let exit_code = mask::run_mask_mode(
            &parsed_mask, &flags, &default_string,
            &valid_pattern, &exclude_pattern, output_to_stderr, stdin_fd,
        );
        output::trailing_newline_if(&flags);
        term::restore_term(&orig_termios);
        process::exit(exit_code);
    }

    // Resolve erase mode: if unset, default to on when how_many > 1
    let erase_active = match flags.erase {
        Some(v) => v,
        None => how_many > 1,
    };

    // Main character-reading loop
    let mut num_read: usize = 0;
    let mut buffer: Vec<u8> = Vec::new();
    let mut cursor_pos: usize = 0;
    let stdin_fd = io::stdin().as_raw_fd();

    'outer: while num_read < how_many {
        if TIMED_OUT.load(Ordering::Relaxed) {
            if flags.dflt && num_read == 0 {
                if let Some(ref ds) = default_string {
                    output::handle_default(ds, &flags, output_to_stderr);
                    output::trailing_newline_if(&flags);
                    term::restore_term(&orig_termios);
                    process::exit(EXIT_STAT.load(Ordering::Relaxed));
                }
            }
            output::trailing_newline_if(&flags);
            EXIT_STAT.store(-2, Ordering::Relaxed);
            term::restore_term(&orig_termios);
            process::exit(-2);
        }

        let key = match input::read_key(stdin_fd) {
            Ok(k) => k,
            Err(ref e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(ref e) if e.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(_) => break,
        };

        if erase_active {
            match key {
                KeyInput::Char(b) => {
                    let mut ch = b as char;
                    // -c: include filter
                    if flags.check {
                        if let Some(ref re) = valid_pattern {
                            if !re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    // -C: exclude filter
                    if flags.exclude {
                        if let Some(ref re) = exclude_pattern {
                            if re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    // Case mapping
                    if flags.upper {
                        ch = ch.to_uppercase().next().unwrap_or(ch);
                    }
                    if flags.lower {
                        ch = ch.to_lowercase().next().unwrap_or(ch);
                    }
                    buffer.insert(cursor_pos, ch as u8);
                    cursor_pos += 1;
                    num_read += 1;
                    if !flags.silent {
                        output::redraw_input(&buffer, cursor_pos, cursor_pos - 1);
                    }
                }
                KeyInput::Backspace => {
                    if cursor_pos > 0 {
                        buffer.remove(cursor_pos - 1);
                        cursor_pos -= 1;
                        num_read -= 1;
                        if !flags.silent {
                            output::redraw_input(&buffer, cursor_pos, cursor_pos + 1);
                        }
                    }
                }
                KeyInput::Delete => {
                    if cursor_pos < buffer.len() {
                        buffer.remove(cursor_pos);
                        num_read -= 1;
                        if !flags.silent {
                            output::redraw_input(&buffer, cursor_pos, cursor_pos);
                        }
                    }
                }
                KeyInput::Left => {
                    if cursor_pos > 0 {
                        cursor_pos -= 1;
                        if !flags.silent {
                            let _ = io::stderr().write_all(CURSOR_LEFT);
                            let _ = io::stderr().flush();
                        }
                    }
                }
                KeyInput::Right => {
                    if cursor_pos < buffer.len() {
                        cursor_pos += 1;
                        if !flags.silent {
                            let _ = io::stderr().write_all(CURSOR_RIGHT);
                            let _ = io::stderr().flush();
                        }
                    }
                }
                KeyInput::Home => {
                    if cursor_pos > 0 {
                        if !flags.silent {
                            let mut stderr = io::stderr();
                            output::cursor_left_n(&mut stderr, cursor_pos);
                            let _ = stderr.flush();
                        }
                        cursor_pos = 0;
                    }
                }
                KeyInput::End => {
                    if cursor_pos < buffer.len() {
                        let delta = buffer.len() - cursor_pos;
                        if !flags.silent {
                            let mut stderr = io::stderr();
                            output::cursor_right_n(&mut stderr, delta);
                            let _ = stderr.flush();
                        }
                        cursor_pos = buffer.len();
                    }
                }
                KeyInput::KillToEnd => {
                    let removed = buffer.len() - cursor_pos;
                    if removed > 0 {
                        buffer.truncate(cursor_pos);
                        num_read -= removed;
                        if !flags.silent {
                            let _ = io::stderr().write_all(CLEAR_TO_EOL);
                            let _ = io::stderr().flush();
                        }
                    }
                }
                KeyInput::KillToStart => {
                    if cursor_pos > 0 {
                        let old_cursor = cursor_pos;
                        buffer.drain(..cursor_pos);
                        num_read -= old_cursor;
                        cursor_pos = 0;
                        if !flags.silent {
                            output::redraw_input(&buffer, cursor_pos, old_cursor);
                        }
                    }
                }
                KeyInput::KillWordBack => {
                    if cursor_pos > 0 {
                        let old_cursor = cursor_pos;
                        // Skip whitespace backward
                        let mut new_pos = cursor_pos;
                        while new_pos > 0 && buffer[new_pos - 1] == b' ' {
                            new_pos -= 1;
                        }
                        // Skip non-whitespace backward
                        while new_pos > 0 && buffer[new_pos - 1] != b' ' {
                            new_pos -= 1;
                        }
                        let removed = old_cursor - new_pos;
                        buffer.drain(new_pos..old_cursor);
                        cursor_pos = new_pos;
                        num_read -= removed;
                        if !flags.silent {
                            output::redraw_input(&buffer, cursor_pos, old_cursor);
                        }
                    }
                }
                KeyInput::Enter => {
                    // Default on Enter as first input
                    if flags.dflt && num_read == 0 {
                        if let Some(ref ds) = default_string {
                            output::handle_default(ds, &flags, output_to_stderr);
                            output::trailing_newline_if(&flags);
                            term::restore_term(&orig_termios);
                            process::exit(EXIT_STAT.load(Ordering::Relaxed));
                        }
                    }
                    if flags.ret_key {
                        break 'outer;
                    }
                    // Treat newline as a regular char subject to -c/-C filtering
                    let ch = '\n';
                    if flags.check {
                        if let Some(ref re) = valid_pattern {
                            if !re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    if flags.exclude {
                        if let Some(ref re) = exclude_pattern {
                            if re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    buffer.insert(cursor_pos, ch as u8);
                    cursor_pos += 1;
                    num_read += 1;
                    if !flags.silent {
                        output::redraw_input(&buffer, cursor_pos, cursor_pos - 1);
                    }
                }
                KeyInput::Up | KeyInput::Down | KeyInput::Tab | KeyInput::Escape
                    | KeyInput::Unknown => {}
            }
        } else {
            // Non-edit mode: Char, Backspace (raw), and Enter
            match key {
                KeyInput::Char(b) => {
                    let mut ch = b as char;
                    // Default on Enter as first char
                    if ch == '\n' && flags.dflt && num_read == 0 {
                        if let Some(ref ds) = default_string {
                            output::handle_default(ds, &flags, output_to_stderr);
                            output::trailing_newline_if(&flags);
                            term::restore_term(&orig_termios);
                            process::exit(EXIT_STAT.load(Ordering::Relaxed));
                        }
                    }
                    if ch == '\n' && flags.ret_key {
                        break 'outer;
                    }
                    // -c: include filter
                    if flags.check {
                        if let Some(ref re) = valid_pattern {
                            if !re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    // -C: exclude filter
                    if flags.exclude {
                        if let Some(ref re) = exclude_pattern {
                            if re.is_match(&ch.to_string()) {
                                continue;
                            }
                        }
                    }
                    if flags.upper {
                        ch = ch.to_uppercase().next().unwrap_or(ch);
                    }
                    if flags.lower {
                        ch = ch.to_lowercase().next().unwrap_or(ch);
                    }
                    buffer.push(ch as u8);
                    num_read += 1;
                    if !flags.silent {
                        output::output_char(ch, output_to_stderr, flags.both);
                    }
                }
                KeyInput::Backspace => {
                    // -E0: no editing — backspace is a raw byte (0x7F), not an erase
                    buffer.push(0x7F);
                    num_read += 1;
                }
                KeyInput::Enter => {
                    if flags.dflt && num_read == 0 {
                        if let Some(ref ds) = default_string {
                            output::handle_default(ds, &flags, output_to_stderr);
                            output::trailing_newline_if(&flags);
                            term::restore_term(&orig_termios);
                            process::exit(EXIT_STAT.load(Ordering::Relaxed));
                        }
                    }
                    if flags.ret_key {
                        break 'outer;
                    }
                }
                _ => {} // Arrow keys etc. silently ignored
            }
        }
    }

    // In erase mode, write the final buffer to primary output
    if erase_active && !flags.silent {
        let s = String::from_utf8_lossy(&buffer);
        output::output_str(&s, output_to_stderr, flags.both);
    }

    output::trailing_newline_if(&flags);
    EXIT_STAT.store(num_read as i32, Ordering::Relaxed);
    term::restore_term(&orig_termios);
    process::exit(num_read as i32);
}
