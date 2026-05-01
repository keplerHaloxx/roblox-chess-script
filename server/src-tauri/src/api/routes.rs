use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use chrono::Utc;
use uuid::Uuid;

use crate::{
    api::{
        error::ApiError,
        types::{
            AnalyzeRequest, DetectStockfishResponse, GenericOkResponse, HistoryItem,
            StatusResponse, UpdateSettingsRequest,
        },
    },
    app_state::AppState,
};

pub fn api_routes() -> Router<AppState> {
    Router::new()
        .route("/status", get(status))
        .route("/analyze", post(analyze))
        .route("/analyze/cancel", post(cancel_analysis))
        .route("/history", get(history))
        .route("/settings", get(get_settings).put(update_settings))
        .route("/engine/restart", post(restart_engine))
        .route("/engine/detect", post(detect_stockfish))
        .route("/engine/choose", post(choose_stockfish))
        .route("/engine/download", post(download_stockfish))
}

async fn status(State(state): State<AppState>) -> Result<Json<StatusResponse>, ApiError> {
    let config = state.config_store.load_or_default();
    Ok(Json(StatusResponse {
        ok: true,
        engine: state.engine.status(),
        config,
        config_path: state.config_store.config_path().display().to_string(),
    }))
}

async fn analyze(
    State(state): State<AppState>,
    Json(request): Json<AnalyzeRequest>,
) -> Result<Json<crate::api::types::AnalyzeResponse>, ApiError> {
    let fen = request.fen.clone();
    match state.engine.analyze(request).await {
        Ok(response) => {
            state
                .push_history(HistoryItem {
                    id: Uuid::new_v4(),
                    timestamp: Utc::now(),
                    fen,
                    best_move: Some(response.best_move.clone()),
                    difficulty: response.difficulty.clone(),
                    time_taken_ms: Some(response.time_taken_ms),
                    status: "ok".to_string(),
                    error: None,
                })
                .await;
            Ok(Json(response))
        }
        Err(err) => {
            state
                .push_history(HistoryItem {
                    id: Uuid::new_v4(),
                    timestamp: Utc::now(),
                    fen,
                    best_move: None,
                    difficulty: None,
                    time_taken_ms: None,
                    status: "error".to_string(),
                    error: Some(err.to_string()),
                })
                .await;
            Err(ApiError::Engine(err))
        }
    }
}

async fn cancel_analysis(State(state): State<AppState>) -> Json<GenericOkResponse> {
    state.engine.cancel();
    Json(GenericOkResponse {
        ok: true,
        message:
            "Cancellation requested. The running analysis will stop at the next UCI checkpoint."
                .to_string(),
    })
}

async fn history(State(state): State<AppState>) -> Json<Vec<HistoryItem>> {
    Json(state.history().await)
}

async fn get_settings(State(state): State<AppState>) -> Json<crate::config::model::AppConfig> {
    Json(state.config_store.load_or_default())
}

pub async fn update_settings(
    State(state): State<AppState>,
    Json(request): Json<UpdateSettingsRequest>,
) -> Result<Json<GenericOkResponse>, ApiError> {
    state
        .engine
        .apply_config(request.config, request.restart_engine.unwrap_or(false))
        .await?;

    Ok(Json(GenericOkResponse {
        ok: true,
        message: "Settings saved.".to_string(),
    }))
}

async fn restart_engine(
    State(state): State<AppState>,
) -> Result<Json<GenericOkResponse>, ApiError> {
    state.engine.restart().await?;
    Ok(Json(GenericOkResponse {
        ok: true,
        message: "Engine restarted.".to_string(),
    }))
}

async fn detect_stockfish(
    State(state): State<AppState>,
) -> Result<Json<DetectStockfishResponse>, ApiError> {
    let path = state.engine.detect().await;
    Ok(Json(DetectStockfishResponse {
        ok: path.is_some(),
        message: path
            .as_ref()
            .map(|p| format!("Detected Stockfish at {}", p.display()))
            .unwrap_or_else(|| "No Stockfish executable was detected.".to_string()),
        path: path.map(|p| p.display().to_string()),
    }))
}

async fn choose_stockfish(
    State(state): State<AppState>,
) -> Result<Json<DetectStockfishResponse>, ApiError> {
    let Some(path) = state.engine.choose_with_native_dialog().await else {
        return Ok(Json(DetectStockfishResponse {
            ok: false,
            path: None,
            message: "No file was chosen.".to_string(),
        }));
    };

    let mut config = state.config_store.load_or_default();
    config.engine.stockfish_path = Some(path.display().to_string());
    state.engine.apply_config(config, true).await?;

    Ok(Json(DetectStockfishResponse {
        ok: true,
        path: Some(path.display().to_string()),
        message: "Stockfish path saved and engine restarted.".to_string(),
    }))
}

async fn download_stockfish(
    State(state): State<AppState>,
) -> Result<Json<DetectStockfishResponse>, ApiError> {
    let path = state.engine.download_latest().await?;
    Ok(Json(DetectStockfishResponse {
        ok: true,
        path: Some(path.display().to_string()),
        message: "Stockfish downloaded, saved, and started.".to_string(),
    }))
}
