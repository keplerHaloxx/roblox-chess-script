pub mod api;
pub mod app_state;
pub mod commands;
pub mod config;
pub mod engine;
pub mod local_api;

use rfd::{MessageButtons, MessageDialog, MessageLevel};
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use crate::{
    app_state::AppState,
    commands::{
        cancel_analysis, choose_stockfish_manually, choose_syzygy_folders, clear_syzygy_folders,
        detect_stockfish, download_stockfish, get_history, get_settings, get_ui_status,
        redownload_engine, redownload_stockfish, reset_recommended_settings, reset_settings,
        restart_engine, save_settings, set_timing_preset, test_connection, update_settings,
    },
    config::store::ConfigStore,
    engine::manager::{EngineManager, EngineManagerError},
};

pub fn run() {
    init_tracing();

    let config_store = match ConfigStore::open() {
        Ok(store) => store,
        Err(err) => {
            error!(%err, "failed to open config store");
            let _ = MessageDialog::new()
                .set_title("roblox-chess-script")
                .set_description(format!(
                    "The app could not open its config directory.\n\nError: {err}\n\nTry running as a normal user and ensure your profile directory is writable."
                ))
                .set_level(MessageLevel::Error)
                .set_buttons(MessageButtons::Ok)
                .show();
            return;
        }
    };
    let engine_manager = EngineManager::new(config_store.clone());
    let state = AppState::new(config_store, engine_manager);
    let setup_state = state.clone();

    let result = tauri::Builder::default()
        .manage(state)
        .setup(move |_app| {
            tauri::async_runtime::spawn(async move {
                match setup_state.engine.initialize_from_config().await {
                    Ok(()) => info!("chess engine initialized"),
                    Err(EngineManagerError::NotConfigured) => {
                        info!("chess engine not configured yet; setup wizard will handle it")
                    }
                    Err(err) => error!(%err, "engine initialization failed"),
                }

                if let Err(err) = local_api::serve(setup_state).await {
                    error!(%err, "local Roblox API stopped");
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_ui_status,
            get_settings,
            save_settings,
            update_settings,
            set_timing_preset,
            restart_engine,
            cancel_analysis,
            detect_stockfish,
            choose_stockfish_manually,
            download_stockfish,
            redownload_stockfish,
            redownload_engine,
            reset_recommended_settings,
            reset_settings,
            choose_syzygy_folders,
            clear_syzygy_folders,
            get_history,
            test_connection
        ])
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .run(tauri::generate_context!());

    if let Err(err) = result {
        error!(%err, "error while running tauri application");
    }
}

fn init_tracing() {
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("roblox_chess_script=info,tower_http=warn"));

    let _ = tracing_subscriber::registry()
        .with(env_filter)
        .with(tracing_subscriber::fmt::layer())
        .try_init();
}
