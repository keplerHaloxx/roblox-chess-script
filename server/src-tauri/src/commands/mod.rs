use serde::{Deserialize, Serialize};
use tauri::State;

use crate::{
    api::types::{DetectStockfishResponse, EngineStatusResponse, GenericOkResponse, HistoryItem},
    app_state::AppState,
    config::model::{AppConfig, BotTimingPreset},
};

#[derive(Debug, Serialize)]
pub struct UiStatusResponse {
    pub ok: bool,
    pub ready_for_roblox: bool,
    pub setup_required: bool,
    pub status_label: String,
    pub helper_text: String,
    pub engine: EngineStatusResponse,
    pub config: AppConfig,
    pub config_path: String,
    pub last_activity: Option<HistoryItem>,
    pub history_count: usize,
}

#[derive(Debug, Deserialize)]
pub struct SaveSettingsRequest {
    pub config: AppConfig,
    pub restart_engine: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct SetTimingPresetRequest {
    pub preset: BotTimingPreset,
}

#[tauri::command]
pub async fn get_ui_status(state: State<'_, AppState>) -> Result<UiStatusResponse, String> {
    let config = state.config_store.load_or_default();
    let engine = state.engine.status();
    let history = state.history().await;
    let last_activity = history.last().cloned();
    let ready_for_roblox = engine.status == "ready" || engine.status == "analyzing";
    let setup_required =
        engine.status == "not_configured" || config.engine.stockfish_path.is_none();

    let (status_label, helper_text) = match engine.status.as_str() {
        "ready" => (
            "Ready for Roblox".to_string(),
            "The background service is waiting for move requests.".to_string(),
        ),
        "analyzing" => (
            "Thinking".to_string(),
            "A move request is currently being calculated.".to_string(),
        ),
        "starting" => (
            "Starting".to_string(),
            "The chess engine is being prepared.".to_string(),
        ),
        "restarting" => (
            "Restarting".to_string(),
            "The chess engine is restarting with the latest settings.".to_string(),
        ),
        "not_configured" => (
            "Setup Needed".to_string(),
            "Install the chess engine to get ready for Roblox.".to_string(),
        ),
        "crashed" => (
            "Recovering".to_string(),
            "The chess engine stopped unexpectedly.".to_string(),
        ),
        _ => (
            "Needs Attention".to_string(),
            engine
                .last_error
                .clone()
                .unwrap_or_else(|| "Something went wrong. Try restarting the engine.".to_string()),
        ),
    };

    Ok(UiStatusResponse {
        ok: true,
        ready_for_roblox,
        setup_required,
        status_label,
        helper_text,
        engine,
        config,
        config_path: state.config_store.config_path().display().to_string(),
        last_activity,
        history_count: history.len(),
    })
}

#[tauri::command]
pub async fn get_settings(state: State<'_, AppState>) -> Result<AppConfig, String> {
    Ok(state.config_store.load_or_default())
}

#[tauri::command]
pub async fn save_settings(
    state: State<'_, AppState>,
    request: SaveSettingsRequest,
) -> Result<GenericOkResponse, String> {
    let restart_engine = request.restart_engine.unwrap_or(false);

    state
        .config_store
        .save(&request.config)
        .map_err(|err| format!("Could not save settings: {err}"))?;

    if restart_engine {
        match state.engine.initialize_from_config().await {
            Ok(()) => {
                return Ok(GenericOkResponse {
                    ok: true,
                    message: "Settings saved and engine restarted.".to_string(),
                });
            }
            Err(err) => {
                return Ok(GenericOkResponse {
                    ok: false,
                    message: format!(
                        "Settings were saved, but the engine could not restart: {err}"
                    ),
                });
            }
        }
    }

    Ok(GenericOkResponse {
        ok: true,
        message: "Settings saved.".to_string(),
    })
}

#[tauri::command]
pub async fn update_settings(
    state: State<'_, AppState>,
    request: SaveSettingsRequest,
) -> Result<GenericOkResponse, String> {
    save_settings(state, request).await
}

#[tauri::command]
pub async fn set_timing_preset(
    state: State<'_, AppState>,
    request: SetTimingPresetRequest,
) -> Result<GenericOkResponse, String> {
    let mut config = state.config_store.load_or_default();
    config.apply_timing_preset(request.preset);
    state
        .engine
        .apply_config(config, false)
        .await
        .map_err(|err| err.to_string())?;

    Ok(GenericOkResponse {
        ok: true,
        message: "Bot timing updated.".to_string(),
    })
}

#[tauri::command]
pub async fn restart_engine(state: State<'_, AppState>) -> Result<GenericOkResponse, String> {
    match state.engine.initialize_from_config().await {
        Ok(()) => Ok(GenericOkResponse {
            ok: true,
            message: "Engine restarted.".to_string(),
        }),
        Err(err) => Ok(GenericOkResponse {
            ok: false,
            message: format!("Could not restart the engine: {err}"),
        }),
    }
}

#[tauri::command]
pub async fn cancel_analysis(state: State<'_, AppState>) -> Result<GenericOkResponse, String> {
    state.engine.cancel();
    Ok(GenericOkResponse {
        ok: true,
        message: "Cancellation requested.".to_string(),
    })
}

#[tauri::command]
pub async fn detect_stockfish(
    state: State<'_, AppState>,
) -> Result<DetectStockfishResponse, String> {
    match state.engine.detect_stockfish().await {
        Ok(Some(path)) => Ok(DetectStockfishResponse {
            ok: true,
            message: "Chess engine found successfully.".to_string(),
            path: Some(path.display().to_string()),
        }),
        Ok(None) => Ok(DetectStockfishResponse {
            ok: false,
            message: "No compatible chess engine was found automatically. You can download it or choose a file manually.".to_string(),
            path: None,
        }),
        Err(err) => Ok(DetectStockfishResponse {
            ok: false,
            message: format!("Could not check for a chess engine: {err}"),
            path: None,
        }),
    }
}

#[tauri::command]
pub async fn choose_stockfish_manually(
    state: State<'_, AppState>,
) -> Result<DetectStockfishResponse, String> {
    let Some(path) = state.engine.choose_with_native_dialog().await else {
        return Ok(DetectStockfishResponse {
            ok: false,
            message: "No file selected.".to_string(),
            path: None,
        });
    };

    match state.engine.choose_stockfish_manually(path).await {
        Ok(path) => Ok(DetectStockfishResponse {
            ok: true,
            message: "Chess engine selected successfully.".to_string(),
            path: Some(path.display().to_string()),
        }),
        Err(err) => Ok(DetectStockfishResponse {
            ok: false,
            message: format!("Could not use the selected file: {err}"),
            path: None,
        }),
    }
}

#[tauri::command]
pub async fn download_stockfish(
    state: State<'_, AppState>,
) -> Result<DetectStockfishResponse, String> {
    match state.engine.download_latest().await {
        Ok(path) => Ok(DetectStockfishResponse {
            ok: true,
            message: "Chess engine downloaded successfully.".to_string(),
            path: Some(path.display().to_string()),
        }),
        Err(err) => Ok(DetectStockfishResponse {
            ok: false,
            message: format!("Could not download the chess engine: {err}"),
            path: None,
        }),
    }
}

#[tauri::command]
pub async fn redownload_stockfish(
    state: State<'_, AppState>,
) -> Result<DetectStockfishResponse, String> {
    match state.engine.redownload_stockfish().await {
        Ok(path) => Ok(DetectStockfishResponse {
            ok: true,
            message: "Chess engine redownloaded successfully.".to_string(),
            path: Some(path.display().to_string()),
        }),
        Err(err) => Ok(DetectStockfishResponse {
            ok: false,
            message: format!("Could not redownload the chess engine: {err}"),
            path: None,
        }),
    }
}

#[tauri::command]
pub async fn redownload_engine(
    state: State<'_, AppState>,
) -> Result<DetectStockfishResponse, String> {
    redownload_stockfish(state).await
}

#[tauri::command]
pub async fn reset_recommended_settings(
    state: State<'_, AppState>,
) -> Result<GenericOkResponse, String> {
    let current = state
        .config_store
        .load()
        .map_err(|err| format!("Could not load current settings: {err}"))?;

    let mut recommended = AppConfig::default();

    // Preserve setup choices.
    recommended.engine.stockfish_path = current.engine.stockfish_path;
    recommended.engine.syzygy_paths = current.engine.syzygy_paths;

    state
        .config_store
        .save(&recommended)
        .map_err(|err| format!("Could not save recommended settings: {err}"))?;

    match state.engine.initialize_from_config().await {
        Ok(()) => Ok(GenericOkResponse {
            ok: true,
            message: "Recommended settings restored.".to_string(),
        }),
        Err(err) => Ok(GenericOkResponse {
            ok: false,
            message: format!(
                "Recommended settings were restored, but the engine could not restart: {err}"
            ),
        }),
    }
}

#[tauri::command]
pub async fn reset_settings(state: State<'_, AppState>) -> Result<GenericOkResponse, String> {
    reset_recommended_settings(state).await
}

#[tauri::command]
pub async fn choose_syzygy_folders(state: State<'_, AppState>) -> Result<Vec<String>, String> {
    let folders = tokio::task::spawn_blocking(|| {
        rfd::FileDialog::new()
            .set_title("Choose Syzygy tablebase folders")
            .pick_folders()
            .unwrap_or_default()
    })
    .await
    .map_err(|err| err.to_string())?;

    let mut config = state.config_store.load_or_default();
    for folder in folders {
        let value = folder.display().to_string();
        if !config.engine.syzygy_paths.contains(&value) {
            config.engine.syzygy_paths.push(value);
        }
    }

    let result = config.engine.syzygy_paths.clone();
    state
        .engine
        .apply_config(config, false)
        .await
        .map_err(|err| err.to_string())?;
    Ok(result)
}

#[tauri::command]
pub async fn clear_syzygy_folders(state: State<'_, AppState>) -> Result<Vec<String>, String> {
    let mut config = state.config_store.load_or_default();
    config.engine.syzygy_paths.clear();
    state
        .engine
        .apply_config(config, false)
        .await
        .map_err(|err| err.to_string())?;
    Ok(Vec::new())
}

#[tauri::command]
pub async fn get_history(state: State<'_, AppState>) -> Result<Vec<HistoryItem>, String> {
    Ok(state.history().await)
}

#[tauri::command]
pub async fn test_connection(state: State<'_, AppState>) -> Result<GenericOkResponse, String> {
    let config = state.config_store.load_or_default();
    Ok(GenericOkResponse {
        ok: true,
        message: format!(
            "Local API is configured for {}:{}",
            config.server.host, config.server.port
        ),
    })
}
