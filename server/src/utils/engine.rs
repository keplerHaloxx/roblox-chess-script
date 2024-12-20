use std::process::{exit, Command};

use rfd::FileDialog;
use sysinfo::System;
use thousands::Separable;

use crate::{
    macros::styled::f,
    uci::Engine,
    utils::{
        color_print::{CommonColors, Printer},
        input::{get_input, get_int_input},
    },
};

pub fn choose_engine_settings() -> (Option<i32>, Option<i32>, String) {
    Printer::println(
        "Please leave the following options empty if you do not know what you are doing!",
        CommonColors::Red,
    );
    let sys = System::new_all();

    let gb = 1024_f64.powf(3.0);
    let mb = 1024_f64.powf(2.0);
    let total_mem = sys.total_memory() as f64;
    let free_mem = sys.free_memory() as f64;

    let hash = get_int_input(
        &f!(
            "Enter hash amount in MB\nTotal: {} GB | {} MB\nFree: {} GB | {} MB",
            (total_mem / gb + (total_mem % gb).signum()).floor(),
            (total_mem as u64 / mb as u64).separate_with_commas(),
            (free_mem / gb + (free_mem % gb).signum()).floor(),
            (free_mem as u64 / mb as u64).separate_with_commas(),
        ),
        true,
    );
    let threads = get_int_input(
        &f!("Enter threads amount\nTotal: {}", sys.cpus().len()),
        true,
    );

    let syzygy: String = {
        loop {
            let answer = get_input("Do you have a Syzygy tablebase? (Y\\n).").to_ascii_lowercase();

            if answer.is_empty() || answer == "n" {
                break "".to_string();
            } else if answer == "y" {
                if let Some(folder_paths) = FileDialog::new()
                    .set_title("Choose location of Syzygy tablebase")
                    .pick_folders()
                {
                    let mut glued_folder_paths = String::new();
                    for folder_path in folder_paths {
                        glued_folder_paths.push_str(&folder_path.display().to_string());
                        glued_folder_paths.push(';');
                    }
                    break glued_folder_paths;
                } else {
                    println!("No folder selected. Please try again.");
                }
            } else {
                Printer::println(
                    "Invalid input. Please enter 'y' (yes), 'n' (no), or leave blank to skip.",
                    super::color_print::CommonColors::Red,
                );
            }
        }
    };
    (hash, threads, syzygy)
}

pub fn initialize_engine(
    stockfish_path: &str,
    hash: &Option<i32>,
    threads: &Option<i32>,
    syzygy_path: &str,
) -> Engine {
    let engine = Engine::new(stockfish_path).unwrap_or_else(|err| {
        Printer::println(f!("\nCould not start engine: {}\n", err), CommonColors::Red);
        Printer::println("Things to consider:", CommonColors::BrightBoldYellow);
        Printer::println("  - Did you select the correct file for Stockfish?", CommonColors::BrightBoldYellow);
        Printer::println("  - Did you make sure to enter valid settings?\n", CommonColors::BrightBoldYellow);
        Printer::println(
            "If you cannot figure out what went wrong, message me on Discord (on my GitHub) or leave an inssue on the repo\n",
            CommonColors::BrightCyan,
        );
        let _ = Command::new("cmd.exe").arg("/c").arg("pause").status();
        exit(1);
    });

    if hash.is_some() {
        engine
            .set_option("Hash", &hash.unwrap().to_string())
            .unwrap();
    }
    if threads.is_some() {
        engine
            .set_option("Threads", &threads.unwrap().to_string())
            .unwrap();
    }
    if !syzygy_path.is_empty() {
        engine.set_option("SyzygyPath", syzygy_path).unwrap();
    }

    engine
}
