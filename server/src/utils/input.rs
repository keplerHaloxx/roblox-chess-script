use std::io::{stdin, stdout, Write};

use super::color_print::{CommonColors, Printer};

pub fn get_input(message: &str) -> String {
    println!(); // format

    let mut input = String::new();
    print!("{message}\n>");
    stdout().flush().unwrap();

    stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

pub fn get_int_input(message: &str, allow_empty: bool) -> Option<i32> {
    loop {
        let input = get_input(message);
        if allow_empty && input.is_empty() {
            return None;
        }
        if let Ok(number) = input.parse::<i32>() {
            return Some(number);
        }
        Printer::println("Invalid input. Please enter a number.", CommonColors::Red);
    }
}
