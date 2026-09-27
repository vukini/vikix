// main.rs — the ten most common words in a text file.
//
// A word is a run of letters, compared in lower case. A HashMap counts
// them; the counts are then sorted, most common first.
//
//   cargo run -- text.txt
use std::collections::HashMap;
use std::{env, fs, process};

fn main() {
    let path = env::args().nth(1).unwrap_or_else(|| {
        eprintln!("usage: wordfreq FILE");
        process::exit(2);
    });
    let text = fs::read_to_string(&path).unwrap_or_else(|e| {
        eprintln!("{path}: {e}");
        process::exit(1);
    });

    let mut counts: HashMap<String, usize> = HashMap::new();
    let lower = text.to_lowercase();
    for word in lower.split(|c: char| !c.is_ascii_lowercase()).filter(|w| !w.is_empty()) {
        *counts.entry(word.to_string()).or_insert(0) += 1;
    }

    let mut sorted: Vec<(String, usize)> = counts.into_iter().collect();
    // The higher count first; the same count in alphabetical order.
    sorted.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    for (word, count) in sorted.iter().take(10) {
        println!("{count:4} {word}");
    }
}
