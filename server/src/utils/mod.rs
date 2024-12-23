pub mod engine;
pub mod input;
pub mod color_print;

use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug)]
pub struct SolveQueryParams {
    pub fen: String,
    pub max_think_time: Option<u32>,
}

#[derive(Serialize)]
pub struct SolveResponse {
    pub success: bool,
    pub result: String,
}
