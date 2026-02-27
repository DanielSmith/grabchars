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

//! Mask mode: positional input validation via `-m <mask>`.

use std::io::{self, Write};
use std::process;
use std::sync::atomic::Ordering;

use crate::input::{self, KeyInput};
use crate::output::{self, CURSOR_LEFT, CLEAR_TO_EOL};
use crate::{Flags, TIMED_OUT, EXIT_STAT};

pub enum MaskClass {
    Upper,       // U - uppercase letter
    Lower,       // l - lowercase letter
    Alpha,       // c - any letter
    Digit,       // n - digit 0-9
    Hex,         // x - hex digit 0-9a-fA-F
    Punct,       // p - punctuation
    Whitespace,  // W - whitespace
    Any,         // . - any character
    Custom(regex::Regex), // [...] - custom character class
    Literal(char),        // literal character (auto-inserted)
}

#[derive(Clone, Copy, PartialEq)]
pub enum Quantifier {
    One,      // exactly one (default, current behavior)
    Star,     // * — zero or more
    Plus,     // + — one or more
    Optional, // ? — zero or one
}

pub struct MaskElement {
    pub class: MaskClass,
    pub quantifier: Quantifier,
}

pub fn parse_mask(mask_str: &str) -> Vec<MaskElement> {
    let mut elements = Vec::new();
    let chars: Vec<char> = mask_str.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let ch = chars[i];
        // Quantifiers at the start or after another quantifier are invalid
        if ch == '*' || ch == '+' || ch == '?' {
            eprintln!("-m option: unexpected quantifier '{}' at position {} in mask", ch, i);
            process::exit(255);
        }
        let is_literal;
        if ch == '\\' {
            // Escaped literal
            i += 1;
            if i < chars.len() {
                elements.push(MaskElement { class: MaskClass::Literal(chars[i]), quantifier: Quantifier::One });
            }
            is_literal = true;
        } else if ch == '[' {
            // Custom character class — collect until ']'
            let start = i;
            i += 1;
            // Handle [^ and [] edge cases
            if i < chars.len() && (chars[i] == '^' || chars[i] == ']') {
                i += 1;
            }
            while i < chars.len() && chars[i] != ']' {
                i += 1;
            }
            if i >= chars.len() {
                eprintln!("-m option: unclosed '[' in mask");
                process::exit(255);
            }
            let bracket_expr: String = chars[start..=i].iter().collect();
            let pattern = format!("^{}$", bracket_expr);
            let re = regex::Regex::new(&pattern).unwrap_or_else(|e| {
                eprintln!("-m option: invalid character class '{}': {}", bracket_expr, e);
                process::exit(255);
            });
            elements.push(MaskElement { class: MaskClass::Custom(re), quantifier: Quantifier::One });
            is_literal = false;
        } else {
            let class = match ch {
                'U' => MaskClass::Upper,
                'l' => MaskClass::Lower,
                'c' => MaskClass::Alpha,
                'n' => MaskClass::Digit,
                'x' => MaskClass::Hex,
                'p' => MaskClass::Punct,
                'W' => MaskClass::Whitespace,
                '.' => MaskClass::Any,
                _ => MaskClass::Literal(ch),
            };
            is_literal = matches!(class, MaskClass::Literal(_));
            elements.push(MaskElement { class, quantifier: Quantifier::One });
        }
        i += 1;
        // Check for quantifier suffix
        if i < chars.len() && (chars[i] == '*' || chars[i] == '+' || chars[i] == '?') {
            if is_literal {
                eprintln!("-m option: quantifier '{}' cannot be applied to a literal character", chars[i]);
                process::exit(255);
            }
            let q = match chars[i] {
                '*' => Quantifier::Star,
                '+' => Quantifier::Plus,
                '?' => Quantifier::Optional,
                _ => unreachable!(),
            };
            elements.last_mut().unwrap().quantifier = q;
            i += 1;
        }
    }
    elements
}

fn mask_char_matches(class: &MaskClass, ch: char) -> bool {
    match class {
        MaskClass::Upper => ch.is_ascii_uppercase(),
        MaskClass::Lower => ch.is_ascii_lowercase(),
        MaskClass::Alpha => ch.is_ascii_alphabetic(),
        MaskClass::Digit => ch.is_ascii_digit(),
        MaskClass::Hex => ch.is_ascii_hexdigit(),
        MaskClass::Punct => ch.is_ascii_punctuation(),
        MaskClass::Whitespace => ch.is_ascii_whitespace(),
        MaskClass::Any => true,
        MaskClass::Custom(re) => re.is_match(&ch.to_string()),
        MaskClass::Literal(l) => ch == *l,
    }
}

/// Get the current mask element index and how many chars have been consumed at that index.
fn current_mask_state(_mask: &[MaskElement], mask_map: &[usize]) -> (usize, usize) {
    if mask_map.is_empty() {
        // Find first non-literal element (literals get auto-inserted before we start)
        return (0, 0);
    }
    let idx = *mask_map.last().unwrap();
    let count = mask_map.iter().rev().take_while(|&&x| x == idx).count();
    (idx, count)
}

/// Try to advance from `from_idx` to find a mask element that accepts `ch`.
/// Skips literals (they're auto-inserted) and zero-minimum elements that don't match.
/// Returns the mask element index that accepts `ch`, or None.
fn try_advance(mask: &[MaskElement], from_idx: usize, ch: char) -> Option<usize> {
    let mut idx = from_idx;
    while idx < mask.len() {
        // Skip literals — they get auto-inserted, not typed
        if let MaskClass::Literal(_) = mask[idx].class {
            idx += 1;
            continue;
        }
        if mask_char_matches(&mask[idx].class, ch) {
            return Some(idx);
        }
        // Can we skip this element? Only if min is 0
        let can_skip = matches!(mask[idx].quantifier, Quantifier::Star | Quantifier::Optional);
        if can_skip {
            idx += 1;
        } else {
            return None; // blocked by a required element
        }
    }
    None // past end of mask
}

/// Check if the mask is satisfied — all required elements have their minimums met.
fn mask_satisfied(mask: &[MaskElement], mask_map: &[usize]) -> bool {
    for (idx, elem) in mask.iter().enumerate() {
        if let MaskClass::Literal(_) = elem.class {
            continue; // literals are auto-inserted
        }
        let count = mask_map.iter().filter(|&&x| x == idx).count();
        let min = match elem.quantifier {
            Quantifier::One => 1,
            Quantifier::Plus => 1,
            Quantifier::Star => 0,
            Quantifier::Optional => 0,
        };
        if count < min {
            return false;
        }
    }
    true
}

/// Check if the mask has any unbounded quantifiers (Star or Plus).
fn mask_has_unbounded(mask: &[MaskElement]) -> bool {
    mask.iter().any(|e| matches!(e.quantifier, Quantifier::Star | Quantifier::Plus))
}


/// Auto-insert consecutive literal elements starting from `from_idx`.
/// Returns number of literals inserted.
fn mask_auto_insert_literals(
    mask: &[MaskElement],
    buffer: &mut Vec<u8>,
    mask_map: &mut Vec<usize>,
    from_idx: usize,
    silent: bool,
) -> usize {
    let mut count = 0;
    let mut idx = from_idx;
    while idx < mask.len() {
        if let MaskClass::Literal(l) = mask[idx].class {
            buffer.push(l as u8);
            mask_map.push(idx);
            count += 1;
            if !silent {
                eprint!("{}", l);
            }
            idx += 1;
        } else {
            break;
        }
    }
    if count > 0 && !silent {
        let _ = io::stderr().flush();
    }
    count
}

pub fn run_mask_mode(
    mask: &[MaskElement],
    flags: &Flags,
    default_string: &Option<String>,
    valid_pattern: &Option<regex::Regex>,
    exclude_pattern: &Option<regex::Regex>,
    output_to_stderr: bool,
    stdin_fd: i32,
) -> i32 {
    let mut buffer: Vec<u8> = Vec::new();
    let mut mask_map: Vec<usize> = Vec::new();
    let has_unbounded = mask_has_unbounded(mask);

    // Auto-insert any leading literals
    mask_auto_insert_literals(mask, &mut buffer, &mut mask_map, 0, flags.silent);

    loop {
        // Check if mask is complete (all fixed-length elements filled, no unbounded)
        if !has_unbounded {
            // For fixed masks: check if we've reached the end
            let (idx, count) = current_mask_state(mask, &mask_map);
            let past_end = if mask_map.is_empty() {
                // All elements are literals (already inserted) or mask is empty
                mask.is_empty() || mask.iter().all(|e| matches!(e.class, MaskClass::Literal(_)))
            } else {
                // Current element is past the last mask element
                idx >= mask.len() - 1 && count >= 1 && mask[idx].quantifier == Quantifier::One
                    && idx == mask.len() - 1
            };
            // More precise: are ALL elements at their exact-one count?
            if !has_unbounded && buffer.len() >= mask.len()
                && mask.iter().all(|e| e.quantifier == Quantifier::One)
            {
                break;
            }
            if past_end && !has_unbounded {
                // Verify all elements are satisfied
                if mask_satisfied(mask, &mask_map) {
                    break;
                }
            }
        }

        // Check timeout
        if TIMED_OUT.load(Ordering::Relaxed) {
            if flags.dflt && buffer.is_empty() {
                if let Some(ds) = default_string {
                    output::handle_default(ds, flags, output_to_stderr);
                    return EXIT_STAT.load(Ordering::Relaxed);
                }
            }
            // Output partial buffer
            if !buffer.is_empty() {
                let s = String::from_utf8_lossy(&buffer);
                output::output_str(&s, output_to_stderr, flags.both);
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
                // Case mapping
                if flags.upper {
                    ch = ch.to_uppercase().next().unwrap_or(ch);
                }
                if flags.lower {
                    ch = ch.to_lowercase().next().unwrap_or(ch);
                }
                // -c: include filter
                if flags.check {
                    if let Some(re) = valid_pattern {
                        if !re.is_match(&ch.to_string()) {
                            continue;
                        }
                    }
                }
                // -C: exclude filter
                if flags.exclude {
                    if let Some(re) = exclude_pattern {
                        if re.is_match(&ch.to_string()) {
                            continue;
                        }
                    }
                }

                // Quantifier-aware character acceptance
                let (idx, count) = current_mask_state(mask, &mask_map);

                // Can the current element accept more characters?
                let can_accept_more = if idx < mask.len() {
                    match mask[idx].quantifier {
                        Quantifier::One => count < 1,
                        Quantifier::Star => true,
                        Quantifier::Plus => true,
                        Quantifier::Optional => count < 1,
                    }
                } else {
                    false
                };

                let matches_current = can_accept_more
                    && idx < mask.len()
                    && mask_char_matches(&mask[idx].class, ch);

                // Has the current element met its minimum?
                let min_satisfied = if idx < mask.len() {
                    match mask[idx].quantifier {
                        Quantifier::One => count >= 1,
                        Quantifier::Star => true,
                        Quantifier::Plus => count >= 1,
                        Quantifier::Optional => true,
                    }
                } else {
                    true
                };

                if matches_current {
                    // Greedy: accept at current element
                    buffer.push(ch as u8);
                    mask_map.push(idx);
                    if !flags.silent {
                        eprint!("{}", ch);
                        let _ = io::stderr().flush();
                    }
                    // If current element is One or Optional (now full), auto-insert literals after it
                    let now_count = count + 1;
                    let is_full = match mask[idx].quantifier {
                        Quantifier::One => now_count >= 1,
                        Quantifier::Optional => now_count >= 1,
                        _ => false, // unbounded elements don't auto-advance
                    };
                    if is_full {
                        mask_auto_insert_literals(mask, &mut buffer, &mut mask_map, idx + 1, flags.silent);
                    }
                } else if min_satisfied {
                    // Try to advance to a later element
                    let advance_from = if idx < mask.len() { idx + 1 } else { mask.len() };
                    if let Some(new_idx) = try_advance(mask, advance_from, ch) {
                        // Auto-insert any literals between current and new position
                        mask_auto_insert_literals(mask, &mut buffer, &mut mask_map, advance_from, flags.silent);
                        // Now accept the character at new_idx
                        // (literals between advance_from and new_idx were already inserted;
                        //  but try_advance skips literals, so we may need to insert up to new_idx)
                        // Re-insert literals up to new_idx if needed
                        let last_map = mask_map.last().copied().unwrap_or(0);
                        if last_map < new_idx {
                            // Insert any remaining literals between last inserted and new_idx
                            let start = if mask_map.is_empty() { 0 } else { last_map + 1 };
                            for li in start..new_idx {
                                if let MaskClass::Literal(l) = mask[li].class {
                                    buffer.push(l as u8);
                                    mask_map.push(li);
                                    if !flags.silent {
                                        eprint!("{}", l);
                                    }
                                }
                            }
                            if !flags.silent {
                                let _ = io::stderr().flush();
                            }
                        }
                        buffer.push(ch as u8);
                        mask_map.push(new_idx);
                        if !flags.silent {
                            eprint!("{}", ch);
                            let _ = io::stderr().flush();
                        }
                        // Auto-insert literals after the newly accepted position
                        if mask[new_idx].quantifier == Quantifier::One
                            || mask[new_idx].quantifier == Quantifier::Optional
                        {
                            mask_auto_insert_literals(mask, &mut buffer, &mut mask_map, new_idx + 1, flags.silent);
                        }
                    }
                    // else: reject (ignore keystroke)
                }
                // else: reject (ignore keystroke — minimum not met and doesn't match)
            }
            KeyInput::Backspace => {
                if !buffer.is_empty() {
                    buffer.pop();
                    mask_map.pop();
                    if !flags.silent {
                        let _ = io::stderr().write_all(CURSOR_LEFT);
                        let _ = io::stderr().write_all(CLEAR_TO_EOL);
                        let _ = io::stderr().flush();
                    }
                    // Chain-delete backwards over literals
                    while !buffer.is_empty() {
                        let prev_mask_idx = *mask_map.last().unwrap();
                        if matches!(mask[prev_mask_idx].class, MaskClass::Literal(_)) {
                            // Check if everything remaining is literals (leading-literals case)
                            let all_literals = mask_map.iter().all(|&mi| {
                                matches!(mask[mi].class, MaskClass::Literal(_))
                            });
                            buffer.pop();
                            mask_map.pop();
                            if !flags.silent {
                                let _ = io::stderr().write_all(CURSOR_LEFT);
                                let _ = io::stderr().write_all(CLEAR_TO_EOL);
                                let _ = io::stderr().flush();
                            }
                            if all_literals {
                                // Keep going — clear all leading literals
                                continue;
                            }
                            // If the next one back is also a literal, keep going
                            if !buffer.is_empty() {
                                let next_back = *mask_map.last().unwrap();
                                if matches!(mask[next_back].class, MaskClass::Literal(_)) {
                                    continue;
                                }
                            }
                            break;
                        } else {
                            break;
                        }
                    }
                }
            }
            KeyInput::Enter => {
                if flags.dflt && buffer.is_empty() {
                    if let Some(ds) = default_string {
                        output::handle_default(ds, flags, output_to_stderr);
                        return EXIT_STAT.load(Ordering::Relaxed);
                    }
                }
                if flags.ret_key {
                    // With -r: accept if mask is satisfied (or buffer non-empty for compat)
                    if mask_satisfied(mask, &mask_map) || buffer.is_empty() {
                        break;
                    }
                } else if !has_unbounded {
                    // Without -r and no unbounded: only auto-complete breaks the loop
                    // Enter does nothing (same as phase 1)
                } else {
                    // Has unbounded quantifiers: Enter accepts if satisfied
                    if mask_satisfied(mask, &mask_map) && !buffer.is_empty() {
                        break;
                    }
                }
            }
            KeyInput::Escape => {
                // Erase displayed buffer from stderr
                if !flags.silent && !buffer.is_empty() {
                    let mut stderr = io::stderr();
                    output::cursor_left_n(&mut stderr, buffer.len());
                    let _ = stderr.write_all(CLEAR_TO_EOL);
                    let _ = stderr.flush();
                }
                return -1;
            }
            // All other keys ignored in mask mode
            _ => {}
        }
    }

    // Output the buffer
    if !buffer.is_empty() {
        let s = String::from_utf8_lossy(&buffer);
        output::output_str(&s, output_to_stderr, flags.both);
    }

    buffer.len() as i32
}
