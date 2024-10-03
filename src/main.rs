mod macros;
mod uci;

use std::{
    io::{stdin, stdout, Write},
    process::{exit, Command},
    sync::{Arc, Mutex},
};

use actix_web::{get, http, rt::time::Instant, web, App, HttpServer, Responder};
use inline_colorization::*;
use rfd::FileDialog;
use serde::Deserialize;
use shakmaty::fen::Fen;
use sysinfo::System;
use thousands::Separable;
use uci::lib::{Engine, DEFAULT_TIME};

const PORT: u16 = 3000;

struct AppState {
    engine: Arc<Mutex<Engine>>,
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let stockfish_path = choose_stockfish_file();
    let (hash, threads, syzygy) = choose_engine_settings();

    let engine = initialize_engine(&stockfish_path, &hash, &threads, &syzygy);

    styled_println!(
        format!("\nStarting server at http://localhost:{PORT}\n"),
        color_bright_green
    );

    let engine_data = web::Data::new(AppState {
        engine: Arc::new(Mutex::new(engine))
    });
    HttpServer::new(move || {
        App::new()
            .app_data(engine_data.clone()) // Use the cloned Data instance
            .service(solve)
    })
    .bind(("127.0.0.1", PORT))?
    .run()
    .await
}

fn choose_stockfish_file() -> String {
    println!("Choose file for Stockfish.");
    let stockfish_path = FileDialog::new()
        .set_title("Choose location of Stockfish")
        .add_filter("Executable (*.exe)", &["exe"])
        .pick_file();

    if stockfish_path.is_none() {
        styled_println!(
            "No file selected. Please select a file to continue.",
            color_red
        );

        let _ = Command::new("cmd.exe").arg("/c").arg("pause").status();
        // get_input("Press enter to exit...", None);
        exit(1);
    }

    styled_println!("File chosen successfully!\n", color_bright_green);

    stockfish_path.unwrap().display().to_string()
}

fn choose_engine_settings() -> (Option<i32>, Option<i32>, String) {
    styled_println!(
        "Please leave the following options empty if you do not know what you are doing!",
        color_red
    );
    let sys = System::new_all();

    let gb = 1024_f64.powf(3.0);
    let mb = 1024_f64.powf(2.0);
    let total_mem = sys.total_memory() as f64;
    let free_mem = sys.free_memory() as f64;
    /*
    This may truly be the most perplexing code I've ever penned,
    A tangled mess my future self must one day comprehend.
    To the me who will revisit this chaos, I offer my deepest apology.
    Oh, save me from this torment, this cryptic tragedy.
    */
    let hash = get_int_input(
        &format!(
            "Enter hash amount in MB\nTotal: {} GB | {} MB\nFree: {} GB | {} MB",
            (total_mem / gb + (total_mem % gb).signum()).floor(),
            (total_mem as u64 / mb as u64).separate_with_commas(),
            (free_mem / gb + (free_mem % gb).signum()).floor(),
            (free_mem as u64 / mb as u64).separate_with_commas(),
        ),
        true,
        None,
    );
    let threads = get_int_input(
        &format!("Enter threads amount\nTotal: {}", sys.cpus().len()),
        true,
        None,
    );

    let syzygy: String = {
        loop {
            let answer =
                get_input("Do you have a Syzygy tablebase? (Y\\n).", None).to_ascii_lowercase();

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
                styled_println!(
                    "Invalid input. Please enter 'y' (yes), 'n' (no), or leave blank to skip.",
                    color_red
                );
            }
        }
    };
    (hash, threads, syzygy)
}

/// Gets input from user
fn get_input(message: &str, styles: Option<Vec<&str>>) -> String {
    println!(); // format

    let mut input = String::new();
    match styles {
        Some(styles_vec) => styled_vec_print!(format!("{message}\n>"), styles_vec),
        None => print!("{message}\n>"),
    }
    stdout().flush().unwrap();

    stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

fn get_int_input(message: &str, allow_empty: bool, styles: Option<Vec<&str>>) -> Option<i32> {
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

fn initialize_engine(
    stockfish_path: &str,
    hash: &Option<i32>,
    threads: &Option<i32>,
    syzygy_path: &str,
) -> Engine {
    let engine = Engine::new(stockfish_path).unwrap_or_else(|err| {
        styled_println!(
            format!("Could not start engine: {}\n", err),
            color_red,
            "\n"
        );
        styled_println!("Things to consider:", style_bold, color_bright_yellow);
        styled_println!("  - Did you select the correct file for Stockfish?", style_bold, color_bright_yellow);
        styled_println!("  - Did you make sure to enter valid settings?\n", style_bold, color_bright_yellow);
        styled_println!(
            "If you cannot figure out what went wrong, message me on Discord (on my GitHub) or leave an inssue on the repo\n",
            color_bright_cyan
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

#[derive(Deserialize, Debug)]
struct SolveQueryParams {
    fen: String,
    max_think_time: Option<u32>,
}

#[get("/api/solve")]
async fn solve(data: web::Data<AppState>, query: web::Query<SolveQueryParams>) -> impl Responder {
    let mut engine = data.engine.lock().unwrap();

    styled_print!("Received FEN", color_bright_magenta);
    println!(": {}", query.fen);

    styled_print!("Set think time", color_bright_magenta);
    println!(": {}", query.max_think_time.unwrap_or(0));

    // validate fen
    if let Err(e) = query.fen.parse::<Fen>() {
        styled_println!("Invalid FEN\n", color_red);
        return (format!("Error: {}", e), http::StatusCode::BAD_REQUEST);
    }

    let start = Instant::now(); // measure how long request took
    

    // i dont THINK this should ever error unless there's something wrong with stockfish
    // as i've already validated the fen. still gonna do it regardless
    if let Err(err) = engine.set_position(query.fen.as_str()) {
        styled_println!("Failed to set position\n", color_red);
        return (format!("Error: {}", err), http::StatusCode::BAD_REQUEST);
    }

    engine.set_movetime(query.max_think_time.unwrap_or(DEFAULT_TIME));

    let answer = match engine.bestmove(false) {
        Ok(move_) => move_,
        // i have no clue what causes this error to happen but just in case
        Err(err) => {
            styled_println!("Failed to get best move\n", color_red);
            return (format!("Error: {}", err), http::StatusCode::BAD_REQUEST);
        }
    };

    let duration = start.elapsed();

    styled_print!("Returned", color_bright_magenta);
    println!(": {answer}");

    styled_print!("Time taken", color_bright_magenta);
    println!(": {duration:?}\n");

    (answer, http::StatusCode::OK)
}