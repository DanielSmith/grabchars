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

//! Select mode and select-lr mode: inline option selection.

use std::io::{self, Write};
use std::sync::atomic::Ordering;

use crate::input::{self, KeyInput};
use crate::output::{self, CURSOR_LEFT, CURSOR_RIGHT, CLEAR_TO_EOL, REVERSE_ON, REVERSE_OFF};
use crate::{Flags, HighlightStyle, TIMED_OUT};

// ---------------------------------------------------------------------------
// Select mode
// ---------------------------------------------------------------------------

/// Return indices of options whose lowercase starts with the given filter.
fn compute_matches(options: &[String], filter: &str) -> Vec<usize> {
    let filter_lower = filter.to_lowercase();
    options
        .iter()
        .enumerate()
        .filter(|(_, opt)| opt.to_lowercase().starts_with(&filter_lower))
        .map(|(i, _)| i)
        .collect()
}

/// Render the select widget on stderr.
/// Layout: `<filter_text> → <matched_option> (N matches) ↑↓`
fn render_select_line(
    filter: &[u8],
    cursor_pos: usize,
    options: &[String],
    matches: &[usize],
    match_idx: usize,
    prev_total_width: &mut usize,
) {
    let mut stderr = io::stderr();

    // Move back to start of widget
    if *prev_total_width > 0 {
        output::cursor_left_n(&mut stderr, *prev_total_width);
    }
    let _ = stderr.write_all(CLEAR_TO_EOL);

    // Build the display line
    let filter_str = String::from_utf8_lossy(filter);
    let match_display = if matches.is_empty() {
        "(no matches)".to_string()
    } else {
        options[matches[match_idx]].clone()
    };
    let hint = format!(
        "{} \u{2192} {} ({} match{}) \u{2191}\u{2193}",
        filter_str,
        match_display,
        matches.len(),
        if matches.len() == 1 { "" } else { "es" }
    );

    let _ = stderr.write_all(hint.as_bytes());

    // Calculate total display width (approximate: count chars)
    let total_width = hint.chars().count();

    // Reposition cursor to cursor_pos within filter field
    let tail = total_width - cursor_pos;
    if tail > 0 {
        output::cursor_left_n(&mut stderr, tail);
    }

    *prev_total_width = cursor_pos;
    let _ = stderr.flush();
}

/// Clear the select widget from stderr.
fn clear_select_line(prev_total_width: &mut usize) {
    if *prev_total_width > 0 {
        let mut stderr = io::stderr();
        output::cursor_left_n(&mut stderr, *prev_total_width);
        let _ = stderr.write_all(CLEAR_TO_EOL);
        let _ = stderr.flush();
        *prev_total_width = 0;
    }
}

pub fn run_select_mode(
    options: &[String],
    flags: &Flags,
    default_string: &Option<String>,
    output_to_stderr: bool,
    stdin_fd: i32,
) -> i32 {
    let mut filter: Vec<u8> = Vec::new();
    let mut cursor_pos: usize = 0;
    let mut matches = compute_matches(options, "");
    let mut match_idx: usize = 0;
    let mut prev_width: usize = 0;

    // If -d is set, find and highlight that option initially
    if let Some(ds) = default_string {
        let ds_lower = ds.to_lowercase();
        for (i, idx) in matches.iter().enumerate() {
            if options[*idx].to_lowercase() == ds_lower {
                match_idx = i;
                break;
            }
        }
    }

    // Initial render
    if !flags.silent {
        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
    }

    loop {
        // Check timeout
        if TIMED_OUT.load(Ordering::Relaxed) {
            if let Some(ds) = default_string {
                // Find the default in original options
                let ds_lower = ds.to_lowercase();
                for (i, opt) in options.iter().enumerate() {
                    if opt.to_lowercase() == ds_lower {
                        if !flags.silent {
                            clear_select_line(&mut prev_width);
                            output::output_str(opt, output_to_stderr, flags.both);
                        }
                        return i as i32;
                    }
                }
            }
            if !flags.silent {
                clear_select_line(&mut prev_width);
            }
            return -2;
        }

        let key = match input::read_key(stdin_fd) {
            Ok(k) => k,
            Err(ref e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(_) => break,
        };

        match key {
            KeyInput::Char(b) => {
                let mut ch = b as char;
                if flags.upper {
                    ch = ch.to_uppercase().next().unwrap_or(ch);
                }
                if flags.lower {
                    ch = ch.to_lowercase().next().unwrap_or(ch);
                }
                filter.insert(cursor_pos, ch as u8);
                cursor_pos += 1;
                let filter_str = String::from_utf8_lossy(&filter);
                matches = compute_matches(options, &filter_str);
                if match_idx >= matches.len() {
                    match_idx = 0;
                }
                if !flags.silent {
                    render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                }
            }
            KeyInput::Backspace => {
                if cursor_pos > 0 {
                    filter.remove(cursor_pos - 1);
                    cursor_pos -= 1;
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::Delete => {
                if cursor_pos < filter.len() {
                    filter.remove(cursor_pos);
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
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
                if cursor_pos < filter.len() {
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
                if cursor_pos < filter.len() {
                    let delta = filter.len() - cursor_pos;
                    if !flags.silent {
                        let mut stderr = io::stderr();
                        output::cursor_right_n(&mut stderr, delta);
                        let _ = stderr.flush();
                    }
                    cursor_pos = filter.len();
                }
            }
            KeyInput::KillToEnd => {
                if cursor_pos < filter.len() {
                    filter.truncate(cursor_pos);
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::KillToStart => {
                if cursor_pos > 0 {
                    filter.drain(..cursor_pos);
                    cursor_pos = 0;
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::KillWordBack => {
                if cursor_pos > 0 {
                    let mut new_pos = cursor_pos;
                    while new_pos > 0 && filter[new_pos - 1] == b' ' {
                        new_pos -= 1;
                    }
                    while new_pos > 0 && filter[new_pos - 1] != b' ' {
                        new_pos -= 1;
                    }
                    filter.drain(new_pos..cursor_pos);
                    cursor_pos = new_pos;
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::Up => {
                if !matches.is_empty() {
                    if match_idx == 0 {
                        match_idx = matches.len() - 1;
                    } else {
                        match_idx -= 1;
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::Down => {
                if !matches.is_empty() {
                    match_idx = (match_idx + 1) % matches.len();
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::Tab => {
                if !matches.is_empty() {
                    let selected = options[matches[match_idx]].clone();
                    filter = selected.as_bytes().to_vec();
                    cursor_pos = filter.len();
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    // Find the same option in the new matches
                    match_idx = 0;
                    let sel_lower = selected.to_lowercase();
                    for (i, idx) in matches.iter().enumerate() {
                        if options[*idx].to_lowercase() == sel_lower {
                            match_idx = i;
                            break;
                        }
                    }
                    if !flags.silent {
                        render_select_line(&filter, cursor_pos, options, &matches, match_idx, &mut prev_width);
                    }
                }
            }
            KeyInput::Enter => {
                if !matches.is_empty() {
                    let original_idx = matches[match_idx];
                    let selected = &options[original_idx];
                    if !flags.silent {
                        clear_select_line(&mut prev_width);
                        output::output_str(selected, output_to_stderr, flags.both);
                    }
                    return original_idx as i32;
                }
                // If no matches, Enter does nothing
            }
            KeyInput::Escape => {
                if !flags.silent {
                    clear_select_line(&mut prev_width);
                }
                return -1;
            }
            KeyInput::Unknown => {}
        }
    }

    // EOF or error
    if !flags.silent {
        clear_select_line(&mut prev_width);
    }
    -1
}

// ---------------------------------------------------------------------------
// Select-LR mode (horizontal browsing)
// ---------------------------------------------------------------------------

/// Render the select-lr widget on stderr.
/// Layout: `<filter_text> → highlight(match1) match2 match3 ... (N matches)`
fn render_select_lr_line(
    filter: &[u8],
    cursor_pos: usize,
    options: &[String],
    matches: &[usize],
    match_idx: usize,
    highlight_style: &HighlightStyle,
    prev_total_width: &mut usize,
) {
    let mut stderr = io::stderr();

    // Move back to start of widget
    if *prev_total_width > 0 {
        output::cursor_left_n(&mut stderr, *prev_total_width);
    }
    let _ = stderr.write_all(CLEAR_TO_EOL);

    let filter_str = String::from_utf8_lossy(filter);

    if matches.is_empty() {
        let hint = format!("{} \u{2192} (no matches)", filter_str);
        let total_width = hint.chars().count();
        let _ = stderr.write_all(hint.as_bytes());
        let tail = total_width - cursor_pos;
        if tail > 0 {
            output::cursor_left_n(&mut stderr, tail);
        }
        *prev_total_width = cursor_pos;
        let _ = stderr.flush();
        return;
    }

    // Build: "<filter> → " prefix
    let prefix = format!("{} \u{2192} ", filter_str);
    let _ = stderr.write_all(prefix.as_bytes());
    let mut display_width = prefix.chars().count();

    // Write each match, highlighting the selected one
    for (i, &opt_idx) in matches.iter().enumerate() {
        if i > 0 {
            let _ = stderr.write_all(b" ");
            display_width += 1;
        }
        let opt = &options[opt_idx];
        if i == match_idx {
            match highlight_style {
                HighlightStyle::Reverse => {
                    let _ = stderr.write_all(REVERSE_ON);
                    let _ = stderr.write_all(opt.as_bytes());
                    let _ = stderr.write_all(REVERSE_OFF);
                    display_width += opt.chars().count();
                }
                HighlightStyle::Bracket => {
                    let _ = stderr.write_all(b"[");
                    let _ = stderr.write_all(opt.as_bytes());
                    let _ = stderr.write_all(b"]");
                    display_width += opt.chars().count() + 2;
                }
                HighlightStyle::Arrow => {
                    let _ = stderr.write_all(b">");
                    let _ = stderr.write_all(opt.as_bytes());
                    let _ = stderr.write_all(b"<");
                    display_width += opt.chars().count() + 2;
                }
            }
        } else {
            let _ = stderr.write_all(opt.as_bytes());
            display_width += opt.chars().count();
        }
    }

    // Append match count
    let count_str = format!(
        "  ({} match{})",
        matches.len(),
        if matches.len() == 1 { "" } else { "es" }
    );
    let _ = stderr.write_all(count_str.as_bytes());
    display_width += count_str.chars().count();

    // Reposition cursor to cursor_pos within filter field
    let tail = display_width - cursor_pos;
    if tail > 0 {
        output::cursor_left_n(&mut stderr, tail);
    }

    *prev_total_width = cursor_pos;
    let _ = stderr.flush();
}

pub fn run_select_lr_mode(
    options: &[String],
    flags: &Flags,
    default_string: &Option<String>,
    output_to_stderr: bool,
    stdin_fd: i32,
) -> i32 {
    let mut filter: Vec<u8> = Vec::new();
    let mut cursor_pos: usize = 0;
    let mut matches = compute_matches(options, "");
    let mut match_idx: usize = 0;
    let mut prev_width: usize = 0;

    // If -d is set, find and highlight that option initially
    if let Some(ds) = default_string {
        let ds_lower = ds.to_lowercase();
        for (i, idx) in matches.iter().enumerate() {
            if options[*idx].to_lowercase() == ds_lower {
                match_idx = i;
                break;
            }
        }
    }

    // Initial render
    if !flags.silent {
        render_select_lr_line(
            &filter, cursor_pos, options, &matches, match_idx,
            &flags.highlight_style, &mut prev_width,
        );
    }

    loop {
        // Check timeout
        if TIMED_OUT.load(Ordering::Relaxed) {
            if let Some(ds) = default_string {
                let ds_lower = ds.to_lowercase();
                for (i, opt) in options.iter().enumerate() {
                    if opt.to_lowercase() == ds_lower {
                        if !flags.silent {
                            clear_select_line(&mut prev_width);
                            output::output_str(opt, output_to_stderr, flags.both);
                        }
                        return i as i32;
                    }
                }
            }
            if !flags.silent {
                clear_select_line(&mut prev_width);
            }
            return -2;
        }

        let key = match input::read_key(stdin_fd) {
            Ok(k) => k,
            Err(ref e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(_) => break,
        };

        match key {
            KeyInput::Char(b) => {
                let mut ch = b as char;
                if flags.upper {
                    ch = ch.to_uppercase().next().unwrap_or(ch);
                }
                if flags.lower {
                    ch = ch.to_lowercase().next().unwrap_or(ch);
                }
                filter.insert(cursor_pos, ch as u8);
                cursor_pos += 1;
                let filter_str = String::from_utf8_lossy(&filter);
                matches = compute_matches(options, &filter_str);
                if match_idx >= matches.len() {
                    match_idx = 0;
                }
                if !flags.silent {
                    render_select_lr_line(
                        &filter, cursor_pos, options, &matches, match_idx,
                        &flags.highlight_style, &mut prev_width,
                    );
                }
            }
            KeyInput::Backspace => {
                if cursor_pos > 0 {
                    filter.remove(cursor_pos - 1);
                    cursor_pos -= 1;
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::Delete => {
                if cursor_pos < filter.len() {
                    filter.remove(cursor_pos);
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    if match_idx >= matches.len() {
                        match_idx = 0;
                    }
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::Left | KeyInput::Up => {
                if !matches.is_empty() {
                    if match_idx == 0 {
                        match_idx = matches.len() - 1;
                    } else {
                        match_idx -= 1;
                    }
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::Right | KeyInput::Down => {
                if !matches.is_empty() {
                    match_idx = (match_idx + 1) % matches.len();
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::Home => {
                if !matches.is_empty() {
                    match_idx = 0;
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::End => {
                if !matches.is_empty() {
                    match_idx = matches.len() - 1;
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::KillToEnd | KeyInput::KillToStart | KeyInput::KillWordBack => {
                // Clear the filter
                filter.clear();
                cursor_pos = 0;
                matches = compute_matches(options, "");
                if match_idx >= matches.len() {
                    match_idx = 0;
                }
                if !flags.silent {
                    render_select_lr_line(
                        &filter, cursor_pos, options, &matches, match_idx,
                        &flags.highlight_style, &mut prev_width,
                    );
                }
            }
            KeyInput::Tab => {
                if !matches.is_empty() {
                    let selected = options[matches[match_idx]].clone();
                    filter = selected.as_bytes().to_vec();
                    cursor_pos = filter.len();
                    let filter_str = String::from_utf8_lossy(&filter);
                    matches = compute_matches(options, &filter_str);
                    match_idx = 0;
                    let sel_lower = selected.to_lowercase();
                    for (i, idx) in matches.iter().enumerate() {
                        if options[*idx].to_lowercase() == sel_lower {
                            match_idx = i;
                            break;
                        }
                    }
                    if !flags.silent {
                        render_select_lr_line(
                            &filter, cursor_pos, options, &matches, match_idx,
                            &flags.highlight_style, &mut prev_width,
                        );
                    }
                }
            }
            KeyInput::Enter => {
                if !matches.is_empty() {
                    let original_idx = matches[match_idx];
                    let selected = &options[original_idx];
                    if !flags.silent {
                        clear_select_line(&mut prev_width);
                        output::output_str(selected, output_to_stderr, flags.both);
                    }
                    return original_idx as i32;
                }
            }
            KeyInput::Escape => {
                if !flags.silent {
                    clear_select_line(&mut prev_width);
                }
                return -1;
            }
            KeyInput::Unknown => {}
        }
    }

    // EOF or error
    if !flags.silent {
        clear_select_line(&mut prev_width);
    }
    -1
}
