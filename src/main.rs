#![allow(unused)]

mod simple_logger;
mod uci;

use std::{
    env,
    io::{stdin, stdout, Write},
    process::exit,
    sync::Arc,
    time::Duration,
};

use actix_web::{get, rt::time::sleep, web, App, HttpServer, Responder};
use serde::Deserialize;
use uci::lib::Engine;

const PORT: u16 = 3000;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("There's like to safety checks here so don't input anything stupid so the app doesn't crash.");
    println!("You can leave blank options you don't know about or don't want to touch.");
    println!("Do not leave 'stockfish_path' blank as that is needed.\n");

    let mut stockfish_path = get_input(
        "Enter stockfish path (defaults to: './stockfish.exe')\n'./' means current folder",
    );
    let hash = get_input("Enter hash amount");
    let threads = get_input("Enter threads amount");
    let syzygy_path = get_input("Enter Syzygy path");

    // init engine
    if stockfish_path.is_empty() {
        stockfish_path = "./stockfish.exe".to_string();
    }

    let engine = Engine::new(&stockfish_path);
    // quick error check
    if engine.is_err() {
        qerror!("Could not start engine: {}", engine.err().unwrap());
        exit(1);
    }

    let engine = engine.unwrap();

    // engine options
    if !hash.is_empty() {
        engine.set_option("Hash", &hash).unwrap();
    }
    if !threads.is_empty() {
        // engine
        //     .command(&format!("setoption name Threads value {}", threads))
        //     .unwrap();
        engine.set_option("Threads", &threads).unwrap();
    }
    if !syzygy_path.is_empty() {
        engine.set_option("SyzygyPath", &syzygy_path).unwrap();
    }

    // share engine data across app
    let engine_data = web::Data::new(Arc::new(engine));

    qinfo!("Starting server at http://localhost:{}", PORT);

    HttpServer::new(move || App::new().app_data(engine_data.clone()).service(solve))
        .bind(("127.0.0.1", PORT))?
        .run()
        .await
}

fn get_input(message: &str) -> String {
    let mut input = String::new();
    println!("{}", message);
    print!("> ");
    stdout().flush().unwrap(); // won't show message otherwise
    stdin().read_line(&mut input).unwrap();
    println!();
    input.trim().to_string()
}

#[derive(Deserialize, Debug)]
struct SolveQueryParams {
    fen: String,
    duration_secs: Option<u64>,
}

#[get("/api/solve")] // would change this shitty path but i cbf changing the lua script :3
async fn solve(
    engine: web::Data<Arc<Engine>>,
    query: web::Query<SolveQueryParams>,
) -> impl Responder {
    println!("ran");
    // pray that these unwraps don't error. i MIGHT consider fixing this if many errors come about
    engine.set_position(query.fen.as_str()).unwrap();

    // #[allow(unused_assignments)] // the warning was very annoying
    // let mut answer = String::new();
    let answer = engine.bestmove(false).unwrap();
    // println!("{:?}", query);
    // if query.duration_secs.is_some() {
    //     engine.bestmove(true).unwrap();
    //     sleep(Duration::from_secs(query.duration_secs.unwrap())).await;
    //     answer = engine.stop_search().unwrap();
    // } else {
    //     answer = engine.bestmove(false).unwrap();
    // }

    qinfo!(
        "Received FEN: {}\nRan for: {}\nOutput: {}\n",
        query.fen,
        query.duration_secs.unwrap_or(0),
        answer
    );
    answer
}
