use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{config::model::AppConfig, engine::difficulty::Difficulty};

#[derive(Debug, Deserialize)]
pub struct AnalyzeRequest {
    pub fen: String,
    pub depth: Option<u32>,
    pub max_think_time_ms: Option<u64>,
    pub disregard_think_time: Option<bool>,
    pub request_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AnalyzeResponse {
    pub ok: bool,
    pub request_id: String,
    pub best_move: String,
    pub ponder: Option<String>,
    pub depth: u32,
    pub time_taken_ms: u128,
    pub difficulty: Option<Difficulty>,
    pub lines: Vec<AnalysisLine>,
    pub engine: EngineSummary,
}

#[derive(Debug, Clone, Serialize)]
pub struct AnalysisLine {
    pub rank: u8,
    pub depth: Option<u32>,
    pub move_uci: Option<String>,
    pub score_cp: Option<i32>,
    pub mate: Option<i32>,
    pub pv: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct EngineSummary {
    pub name: Option<String>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct StatusResponse {
    pub ok: bool,
    pub engine: EngineStatusResponse,
    pub config: AppConfig,
    pub config_path: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct EngineStatusResponse {
    pub status: String,
    pub name: Option<String>,
    pub stockfish_path: Option<String>,
    pub last_error: Option<String>,
    pub current_job_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct HistoryItem {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub fen: String,
    pub best_move: Option<String>,
    pub difficulty: Option<Difficulty>,
    pub time_taken_ms: Option<u128>,
    pub status: String,
    pub error: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSettingsRequest {
    pub config: AppConfig,
    pub restart_engine: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct GenericOkResponse {
    pub ok: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct DetectStockfishResponse {
    pub ok: bool,
    pub path: Option<String>,
    pub message: String,
}
