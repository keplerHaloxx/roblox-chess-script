#![allow(unused)]

mod simple_logger;
mod uci;

use std::{
    fs::File,
    io::{stdin, stdout, Write},
    path::Path,
    process::exit,
    sync::Arc,
    time::Duration,
};

use actix_web::{
    get,
    rt::time::{sleep, Instant},
    web, App, HttpServer, Responder,
};
use inline_colorization::*;
use serde::Deserialize;
use uci::lib::Engine;

const PORT: u16 = 3000;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("Ensure you input valid options to prevent crashes.");
    println!("Leave options blank if unsure.");
    println!("UNLESS stockfish.exe is in the current folder don't leave the first one empty.\n");

    let stockfish_path = get_file_name_with_default(
        "Enter stockfish.exe path (defaults to: './stockfish.exe')\n'./' means current folder",
        "./stockfish.exe",
    );
    let hash = get_input("Enter hash amount");
    let threads = get_input("Enter threads amount");
    let syzygy_path = get_input("Enter Syzygy path");

    let engine = initialize_engine(&stockfish_path, &hash, &threads, &syzygy_path);

    let engine_data = web::Data::new(Arc::new(engine));

    println!("{color_bright_green}Starting server at http://localhost:{PORT}{color_reset}");

    HttpServer::new(move || App::new().app_data(engine_data.clone()).service(solve))
        .bind(("127.0.0.1", PORT))?
        .run()
        .await
}

/// Tries to get file name and has default if message is empty.
/// If file does not exist, it will ask for input again.
fn get_file_name_with_default(message: &str, default: &str) -> String {
    loop {
        let input = get_input_with_default(message, "./stockfish.exe");
        if Path::new(&input).exists() {
            return input;
        } else {
            println!("{color_red}File not found. Please try again.{color_reset}\n");
        }
    }
}

/// Gets input from user. If message is empty, it will return default.
fn get_input_with_default(message: &str, default: &str) -> String {
    let input = get_input(message);
    if input.is_empty() {
        default.to_string()
    } else {
        input
    }
}

/// Gets input from user
fn get_input(message: &str) -> String {
    println!();
    let mut input = String::new();
    println!("{}", message);
    print!("> ");
    stdout().flush().unwrap();
    stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

fn initialize_engine(stockfish_path: &str, hash: &str, threads: &str, syzygy_path: &str) -> Engine {
    let engine = Engine::new(stockfish_path).unwrap_or_else(|err| {
        eprintln!("Could not start engine: {}", err);
        exit(1);
    });

    if !hash.is_empty() {
        engine.set_option("Hash", hash).unwrap();
    }
    if !threads.is_empty() {
        engine.set_option("Threads", threads).unwrap();
    }
    if !syzygy_path.is_empty() {
        engine.set_option("SyzygyPath", syzygy_path).unwrap();
    }

    engine
}

#[derive(Deserialize, Debug)]
struct SolveQueryParams {
    fen: String,
    duration_secs: Option<u64>,
}

#[get("/api/solve")]
async fn solve(
    engine: web::Data<Arc<Engine>>,
    query: web::Query<SolveQueryParams>,
) -> impl Responder {
    println!(
        "{color_bright_magenta}Received FEN{color_reset}: {}\n{color_bright_magenta}Set think time{color_reset}: {}",
        query.fen,
        query.duration_secs.unwrap_or(0)
    );

    let start = Instant::now();
    engine.set_position(query.fen.as_str()).unwrap();
    let answer = if let Some(duration) = query.duration_secs {
        engine.bestmove(true).unwrap();
        sleep(Duration::from_secs(duration)).await;
        engine.stop_search().unwrap()
    } else {
        engine.bestmove(false).unwrap()
    };
    let duration = start.elapsed();

    println!("{color_bright_magenta}Returned{color_reset}: {}\n{color_bright_magenta}Time taken{color_reset}: {:?}\n", answer, duration);

    answer
}
