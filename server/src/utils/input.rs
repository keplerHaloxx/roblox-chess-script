use std::io::{stdin, stdout, Write};

use inline_colorization::*;

use crate::macros::styled::{f, styled_println, styled_vec_print};

pub fn get_input(message: &str, styles: Option<Vec<&str>>) -> String {
    println!(); // format

    let mut input = String::new();
    match styles {
        Some(styles_vec) => styled_vec_print!(f!("{message}\n>"), styles_vec),
        None => print!("{message}\n>"),
    }
    stdout().flush().unwrap();

    stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

pub fn get_int_input(message: &str, allow_empty: bool, styles: Option<Vec<&str>>) -> Option<i32> {
    loop {
        let input = get_input(message, styles.clone());
        if allow_empty && input.is_empty() {
            return None;
        }
        if let Ok(number) = input.parse::<i32>() {
            return Some(number);
        }
        styled_println!("Invalid input. Please enter a number.", color_red);
    }
}
