// main.rs — errors as values: Result and the ? operator.
//
// Rust has no exceptions. A function that can fail returns
// Result<T, E>: Ok(value) or Err(reason). `?` hands an Err straight back
// to the caller, so the happy path reads top to bottom, and the compiler
// won't let you forget a failure is possible.
//
// This adds up the numbers in a file, one per line, skipping # comments.
// A line that isn't a number stops it, with the line number in the message.
use std::fmt;
use std::fs;
use std::num::ParseIntError;

#[derive(Debug)]
enum SumError {
    Read(std::io::Error),
    NotANumber { line: usize, text: String, cause: ParseIntError },
}

// How each error is shown to a person.
impl fmt::Display for SumError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            SumError::Read(e) => write!(f, "can't read the file: {e}"),
            SumError::NotANumber { line, text, cause } =>
                write!(f, "line {line}: {text:?} is not a number ({cause})"),
        }
    }
}

// From lets `?` turn an io::Error into a SumError by itself.
impl From<std::io::Error> for SumError {
    fn from(e: std::io::Error) -> Self {
        SumError::Read(e)
    }
}

fn sum_file(path: &str) -> Result<i64, SumError> {
    let text = fs::read_to_string(path)?;          // an io::Error returns here
    let mut total = 0;
    for (i, line) in text.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let n: i64 = line.parse().map_err(|cause| SumError::NotANumber {
            line: i + 1,
            text: line.to_string(),
            cause,
        })?;                                           // a bad number returns here
        total += n;
    }
    Ok(total)
}

fn main() {
    for path in ["numbers.txt", "missing.txt"] {
        match sum_file(path) {
            Ok(total) => println!("{path}: total {total}"),
            Err(e) => println!("{path}: {e}"),
        }
    }
}
