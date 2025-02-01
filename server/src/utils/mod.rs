pub mod color_print;
pub mod engine;
pub mod input;

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
