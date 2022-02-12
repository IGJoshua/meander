use lazy_static::lazy_static;
use regex::Regex;

use crate::types::Atom;

lazy_static! {
    static ref NUMBER_REGEX: Regex =
        Regex::new(r#"(0[1-7][0-7_]*|0b[01][01_]*|0x[0-9a-fA-F][0-9a-fA-F_]*|[1-9][0-9_]*(\.[0-9_]+)?f?|0(\.[0-9_]+)?f?)"#)
            .unwrap();
    static ref SYMBOL_REGEX: Regex =
        Regex::new(r#"((?P<namespace>[\P{Zl}&&\P{Zp}&&\P{Zs}&&\P{Cc}&&\P{Cf}&&[^/ "()\[\]]]+)/)?(?P<name>[\P{Zl}&&\P{Zp}&&\P{Zs}&&\P{Cc}&&\P{Cf}&&[^/ "()\[\]]]+)"#)
            .unwrap();
    static ref STRING_REGEX: Regex =
        Regex::new(r#""(?P<contents>(\\"|[^"])*)""#)
            .unwrap();
    static ref BUFFER_REGEX: Regex =
        Regex::new(r#"#\[(?P<buffer_contents>(0x[0-9a-fA-F]{2}(\s+0x[0-9a-fA-F]{2})*)?)\]"#)
            .unwrap();
}

fn read_list(input: &str) -> Option<(Atom, usize)> {
    if input.chars().next() != Some('(') {
        return None;
    }

    let mut input = &input[1..];
    let mut elts = vec![];
    let mut end_idx = 1;
    loop {
        input = {
            let new_input = input.trim_start();
            end_idx += input.len() - new_input.len();
            new_input
        };
        if input.chars().next() == Some(')') {
            return Some((Atom::Tuple(elts), end_idx + 1))
        }
        let (elt, next_idx) = read_with_end(input)?;
        elts.push(elt);
        end_idx += next_idx;
        input = &input[next_idx..];
    }
}

fn read_string(input: &str) -> Option<(Atom, usize)> {
    let mat = STRING_REGEX.find(input)?;
    let cap = STRING_REGEX.captures(input)?.name("contents")?;
    Some((Atom::Buffer(cap.as_str().as_bytes().to_owned()), mat.end()))
}

fn read_buffer(input: &str) -> Option<(Atom, usize)> {
    let mat = BUFFER_REGEX.find(input)?;
    let cap = BUFFER_REGEX.captures(input)?.name("buffer_contents")?;
    let elts = cap.as_str()
                  .split_ascii_whitespace()
                  .map(|s| &s[2..])
                  .flat_map(|s| u8::from_str_radix(s, 16))
                  .collect();
    Some((Atom::Buffer(elts), mat.end()))
}

fn read_number(input: &str) -> Option<(Atom, usize)> {
    let mat = NUMBER_REGEX.find(input)?;
    println!("Match {}", mat.as_str());
    let input = mat.as_str();
    let input = input.replace("_", "");

    if input.as_str().rfind('f') == Some(input.len() - 1) {
        let input = &input[..input.len() - 1];
        if let Ok(real) = input.parse() {
            Some((Atom::Real(real), mat.end()))
        } else {
            None
        }
    } else {
        let mut chars = input.chars();
        if chars.next() == Some('0') && input.len() > 1 {
            let next_char = chars.next().unwrap();
            let parsed_int = match next_char {
                'x' => i64::from_str_radix(&input[2..], 16).ok(),
                'b' => i64::from_str_radix(&input[2..], 2).ok(),
                '.' => return Some((Atom::Real(input.parse().ok()?), mat.end())),
                _ => {
                    if next_char.is_ascii_digit() {
                        i64::from_str_radix(&input[1..], 8).ok()
                    } else {
                        None
                    }
                }
            };
            match parsed_int {
                Some(i) => Some((Atom::Integer(i), mat.end())),
                None => None,
            }
        } else {
            if let Ok(int) = input.parse() {
                Some((Atom::Integer(int), mat.end()))
            } else if let Ok(real) = input.parse() {
                Some((Atom::Real(real), mat.end()))
            } else {
                None
            }
        }
    }
}

fn read_symbolic_value(input: &str) -> Option<(Option<String>, String, usize)> {
    let mat = SYMBOL_REGEX.find(input)?;
    let cap = SYMBOL_REGEX.captures(input)?;
    let namespace = cap.name("namespace");
    let name = &cap["name"];
    Some((
        namespace.map(|s| s.as_str().to_owned()),
        name.to_owned(),
        mat.end(),
    ))
}

fn read_with_end(input: &str) -> Option<(Atom, usize)> {
    let (input, offset) = {
        let new_input = input.trim_start();
        (new_input, input.len() - new_input.len())
    };
    match input.chars().next() {
        Some('(') => read_list(input).map(|(v, i)| (v, i + offset)),
        Some('"') => read_string(input).map(|(v, i)| (v, i + offset)),
        Some('\'') => {
            let (read, idx) = read_with_end(&input[1..])?;
            Some((Atom::Tuple(vec![
                Atom::SimpleSymbol("quote".to_owned()),
                read,
            ]), idx + offset))
        },
        Some(_) => {
            let mut chars = input.chars();
            let start_char = chars.next()?;
            if start_char.is_ascii_digit() {
                read_number(input).map(|(v, i)| (v, i + offset))
            } else {
                match start_char {
                    '#' => {
                        if let Some('[') = chars.next() {
                            read_buffer(input).map(|(v, i)| (v, i + offset))
                        } else {
                            unimplemented!()
                        }
                    },
                    ':' => {
                        let (namespace, name, symbol_end) = read_symbolic_value(&input[1..])?;
                        Some(match namespace {
                            Some(namespace) => (Atom::QualifiedKeyword(namespace, name), symbol_end + offset),
                            None => (Atom::SimpleKeyword(name), symbol_end + offset),
                        })
                    }
                    _ => {
                        let (namespace, name, symbol_end) = read_symbolic_value(input)?;
                        Some(match namespace {
                            Some(namespace) => (Atom::QualifiedSymbol(namespace, name), symbol_end + offset),
                            None => (Atom::SimpleSymbol(name), symbol_end + offset),
                        })
                    }
                }
            }
        }
        None => None
    }
}

pub fn read(input: &str) -> Option<Atom> {
    read_with_end(input).map(|v| v.0)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn read_symbols() {
        assert_eq!(
            read("hello").unwrap(),
            Atom::SimpleSymbol("hello".to_owned())
        );
        assert_eq!(
            read("some/hello").unwrap(),
            Atom::QualifiedSymbol("some".to_owned(), "hello".to_owned())
        );
    }

    #[test]
    fn read_keywords() {
        assert_eq!(
            read(":hello").unwrap(),
            Atom::SimpleKeyword("hello".to_owned())
        );
        assert_eq!(
            read(":some/hello").unwrap(),
            Atom::QualifiedKeyword("some".to_owned(), "hello".to_owned())
        );
    }

    #[test]
    fn read_numbers() {
        assert_eq!(read("10").unwrap(), Atom::Integer(10),);
        assert_eq!(read("10.5").unwrap(), Atom::Real(10.5),);
        assert_eq!(read("0x10").unwrap(), Atom::Integer(16),);
        assert_eq!(read("010").unwrap(), Atom::Integer(8),);
        assert_eq!(read("0b10").unwrap(), Atom::Integer(2),);
        assert_eq!(read("1_000_000").unwrap(), Atom::Integer(1000000),);
        assert_eq!(read("0").unwrap(), Atom::Integer(0),);
        assert_eq!(read("0f").unwrap(), Atom::Real(0.0),);
        assert_eq!(read("0.0f").unwrap(), Atom::Real(0.0),);
        assert_eq!(read("1.0f").unwrap(), Atom::Real(1.0),);
        assert_eq!(read("0.1").unwrap(), Atom::Real(0.1),);
    }

    #[test]
    fn read_tuples() {
        assert_eq!(read("()").unwrap(), Atom::Tuple(vec![]),);
        assert_eq!(
            read("(1 2 3)").unwrap(),
            Atom::Tuple(vec![Atom::Integer(1), Atom::Integer(2), Atom::Integer(3),]),
        );
    }

    #[test]
    fn read_strings() {
        assert_eq!(
            read(r#" "" "#).unwrap(),
            Atom::Buffer("".as_bytes().to_owned())
        );
        assert_eq!(
            read(r#" "abcd" "#).unwrap(),
            Atom::Buffer("abcd".as_bytes().to_owned())
        );
        assert_eq!(
            read(
                r#" "ab
cd" "#
            )
            .unwrap(),
            Atom::Buffer("ab\ncd".as_bytes().to_owned())
        );
    }

    #[test]
    fn read_buffer() {
        assert_eq!(
            read(r#"#[]"#).unwrap(),
            Atom::Buffer(vec![]),
        );
        assert_eq!(
            read(r#"#[0x00]"#).unwrap(),
            Atom::Buffer(vec![0]),
        );
        assert_eq!(
            read(r#"#[0x00 0xaf 0x06 0xFF]"#).unwrap(),
            Atom::Buffer(vec![0, 0xaf, 0x06, 0xff]),
        );
    }
}
