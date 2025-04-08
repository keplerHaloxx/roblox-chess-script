pub mod color_print;
pub mod engine;
pub mod input;
pub mod os;

use std::process::{exit, Command};

use color_print::{CommonColors, Printer};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug)]
pub struct SolveQueryParams {
    pub fen: String,
    pub max_think_time: Option<u32>,
    pub depth: Option<u32>,
    pub disregard_think_time: Option<bool>,
}

#[derive(Serialize)]
pub struct SolveResponse {
    pub success: bool,
    pub result: String,
}

pub fn print_err_and_quit(msg: impl Into<String>) {
    Printer::println(msg.into(), CommonColors::Red);

    let _ = Command::new("cmd.exe").arg("/c").arg("pause").status();
    exit(1);
}
