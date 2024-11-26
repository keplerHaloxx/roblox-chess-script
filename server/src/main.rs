mod macros;
mod uci;
mod utils;

use std::{
    process::{exit, Command},
    sync::{Arc, Mutex},
};

use actix_web::{get, rt::time::Instant, web, App, HttpResponse, HttpServer, Responder};
use inline_colorization::*;
use macros::styled::{f, styled_print, styled_println};
use rfd::FileDialog;
use shakmaty::fen::Fen;
// use shakmaty::fen::Fen;
use uci::Engine;
use utils::{
    engine::{choose_engine_settings, initialize_engine},
    SolveQueryParams, SolveResponse,
};

const PORT: u16 = 3000;

struct AppState {
    engine: Arc<Mutex<Engine>>,
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    styled_println!("If anything goes wrong please try updating the app first. If that doesn't work, please report the issue on GitHub or DM me on Discord (in my github profile).\n", color_bright_cyan);

    let stockfish_path = choose_stockfish_file();
    let (hash, threads, syzygy) = choose_engine_settings();

    let engine = initialize_engine(&stockfish_path, &hash, &threads, &syzygy);
    set_stockfish_option(&engine, "Ponder", "true");
    set_stockfish_option(&engine, "MultiPV", "5");
    set_stockfish_option(&engine, "Move Overhead", "0");

    styled_println!(
        format!("\nStarting server at http://localhost:{PORT}\n"),
        color_bright_green
    );

    let engine_data = web::Data::new(AppState {
        engine: Arc::new(Mutex::new(engine)),
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

fn set_stockfish_option(engine: &Engine, option: &str, value: &str) {
    engine
        .set_option(option, value)
        .unwrap_or_else(|e| styled_println!(f!("Failed to set option: {e}")));
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

#[get("/api/solve")]
async fn solve(data: web::Data<AppState>, query: web::Query<SolveQueryParams>) -> impl Responder {
    let mut engine = data.engine.lock().unwrap();

    styled_print!("Received FEN", color_bright_magenta);
    println!(": {}", query.fen);

    styled_print!("Max Think Time", color_bright_magenta);
    println!(": {}", query.max_think_time.unwrap_or(100));

    // Validate FEN
    if query.fen.parse::<Fen>().is_err() {
        styled_println!("Invalid FEN\n", color_red);
        return HttpResponse::BadRequest().json(SolveResponse {
            success: false,
            result: "Error: Invalid FEN".to_string(),
        });
    }

    let start = Instant::now();

    // Set position on engine
    if let Err(err) = engine.set_position(query.fen.as_str()) {
        styled_println!(f!("Failed to set position - {err}\n"), color_red);
        return HttpResponse::BadRequest().json(SolveResponse {
            success: false,
            result: f!("Error: Failed to set position - {}", err),
        });
    }

    // Use provided think time or default to 100ms
    let max_think_time = query.max_think_time.unwrap_or(100);
    engine.movetime(max_think_time);

    // Get the best move
    let best_move = match engine.bestmove_depth(17) {
        Ok(mv) => mv,
        Err(err) => {
            styled_println!(f!("Failed to get best move - {err}\n"), color_red);
            return HttpResponse::BadRequest().json(SolveResponse {
                success: false,
                result: f!("Error: Failed to get best move - {}", err),
            });
        }
    };

    let duration = start.elapsed();

    styled_print!("Returned", color_bright_magenta);
    println!(": {best_move}");

    styled_print!("Time Taken", color_bright_magenta);
    println!(": {duration:?}\n");

    // Return best move as JSON response
    HttpResponse::Ok().json(SolveResponse {
        success: true,
        result: best_move,
    })
}
