mod macros;
mod uci;
mod utils;

use std::{
    process::{exit, Command},
    sync::{Arc, Mutex},
};

use actix_web::{get, rt::time::Instant, web, App, HttpResponse, HttpServer, Responder};
use macros::styled::f;
use rfd::FileDialog;
use shakmaty::fen::Fen;
use uci::Engine;
use utils::{
    color_print::{CommonColors, Printer},
    engine::{choose_engine_settings, initialize_engine},
    SolveQueryParams, SolveResponse,
};

const PORT: u16 = 3000;

struct AppState {
    engine: Arc<Mutex<Engine>>,
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    Printer::println("If anything goes wrong please try updating the app first. If that doesn't work, please report the issue on GitHub or DM me on Discord (in my github profile).\n", CommonColors::BrightCyan);

    let stockfish_path = choose_stockfish_file();
    let (hash, threads, syzygy) = choose_engine_settings();

    let engine = initialize_engine(&stockfish_path, &hash, &threads, &syzygy);
    // set_stockfish_option(&engine, "Ponder", "true");
    // set_stockfish_option(&engine, "MultiPV", "5");
    // set_stockfish_option(&engine, "Move Overhead", "0");
    // just testing some settings
    set_stockfish_option(&engine, "MultiPV", "0");
    // set_stockfish_option(&engine, "Move Overhead", "10");

    Printer::println(
        f!("\nStarting server at http://localhost:{PORT}\n"),
        CommonColors::BrightGreen,
    );

    let engine_data = web::Data::new(AppState {
        engine: Arc::new(Mutex::new(engine)),
    });

    HttpServer::new(move || App::new().app_data(engine_data.clone()).service(solve))
        .bind(("127.0.0.1", PORT))?
        .run()
        .await
}

fn set_stockfish_option(engine: &Engine, option: &str, value: &str) {
    engine
        .set_option(option, value)
        .unwrap_or_else(|e| Printer::println(f!("Failed to set option: {e}"), CommonColors::Red));
}

fn choose_stockfish_file() -> String {
    println!("Choose file for Stockfish.");
    let stockfish_path = FileDialog::new()
        .set_title("Choose location of Stockfish")
        .add_filter("Executable (*.exe)", &["exe"])
        .pick_file();

    if stockfish_path.is_none() {
        Printer::println(
            "No file selected. Please select a file to continue.",
            CommonColors::Red,
        );

        let _ = Command::new("cmd.exe").arg("/c").arg("pause").status();
        exit(1);
    }
    Printer::println("File chosen successfully!\n", CommonColors::BrightGreen);

    stockfish_path.unwrap().display().to_string()
}

#[get("/api/solve")]
async fn solve(data: web::Data<AppState>, query: web::Query<SolveQueryParams>) -> impl Responder {
    let mut engine = data.engine.lock().unwrap();

    Printer::print("FEN", CommonColors::BrightMagenta);
    println!(": {}", query.fen);

    Printer::print("Depth", CommonColors::BrightMagenta);
    println!(": {}", query.depth.unwrap_or(17));

    Printer::print("Max Think Time", CommonColors::BrightMagenta);
    println!(": {}", query.max_think_time.unwrap_or(100));

    Printer::print("Disregard Think Time", CommonColors::BrightMagenta);
    println!(": {}", query.disregard_think_time.unwrap_or(false));

    // Validate FEN
    if query.fen.parse::<Fen>().is_err() {
        Printer::println("Invalid FEN\n", CommonColors::Red);
        return HttpResponse::BadRequest().json(SolveResponse {
            success: false,
            result: "Error: Invalid FEN".to_string(),
        });
    }

    let start = Instant::now();

    // Set position on engine
    if let Err(err) = engine.set_position(query.fen.as_str()) {
        Printer::println(f!("Failed to set position - {err}\n"), CommonColors::Red);
        return HttpResponse::BadRequest().json(SolveResponse {
            success: false,
            result: f!("Error: Failed to set position - {}", err),
        });
    }

    // Use provided think time or default to 100ms
    engine.movetime(query.max_think_time.unwrap_or(100));

    // Get the best move
    // setting depth to 17 as default
    let best_move = match engine.bestmove_depth(
        query.depth.unwrap_or(17),
        query.disregard_think_time.unwrap_or(false),
    ) {
        Ok(mv) => mv,
        Err(err) => {
            Printer::println(f!("Failed to get best move - {err}\n"), CommonColors::Red);
            return HttpResponse::BadRequest().json(SolveResponse {
                success: false,
                result: f!("Error: Failed to get best move - {}", err),
            });
        }
    };

    let duration = start.elapsed();

    Printer::print("Returned", CommonColors::BrightMagenta);
    println!(": {best_move}");

    Printer::print("Time Taken", CommonColors::BrightMagenta);
    println!(": {duration:?}\n");

    // Return best move as JSON response
    HttpResponse::Ok().json(SolveResponse {
        success: true,
        result: best_move,
    })
}
