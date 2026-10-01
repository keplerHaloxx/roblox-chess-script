use roblox_chess_script_lib::{
    api::types::AnalyzeRequest,
    config::{
        model::{AppConfig, BotTimingPreset},
        store::ConfigStore,
    },
    engine::manager::EngineManager,
};

fn manager() -> (tempfile::TempDir, ConfigStore, EngineManager) {
    let dir = tempfile::tempdir().unwrap();
    let store =
        ConfigStore::from_paths(dir.path().join("config.json"), dir.path().join("data")).unwrap();
    let manager = EngineManager::new(store.clone());
    (dir, store, manager)
}

#[tokio::test]
async fn settings_can_be_saved_before_engine_setup() {
    let (_dir, store, manager) = manager();
    let mut config = AppConfig::default();
    config.apply_timing_preset(BotTimingPreset::Careful);
    manager.apply_config(config, false).await.unwrap();
    let saved = store.load().unwrap();
    assert_eq!(saved.analysis.min_delay_ms, 400);
    assert_eq!(saved.analysis.max_delay_ms, 4000);
    assert_eq!(manager.status().status, "not_configured");
}

#[tokio::test]
async fn failed_engine_switch_preserves_saved_path() {
    let (dir, store, manager) = manager();
    let mut config = AppConfig::default();
    config.engine.stockfish_path = Some("previous-stockfish.exe".into());
    store.save(&config).unwrap();
    let invalid_engine = dir.path().join("stockfish-invalid.exe");
    assert!(manager.use_stockfish_path(invalid_engine).await.is_err());
    assert_eq!(
        store.load().unwrap().engine.stockfish_path,
        config.engine.stockfish_path
    );
}

#[tokio::test]
async fn failed_restart_does_not_overwrite_saved_settings() {
    let (_dir, store, manager) = manager();
    let mut original = AppConfig::default();
    original.engine.stockfish_path = Some("previous-stockfish.exe".into());
    store.save(&original).unwrap();
    assert!(manager
        .apply_config(AppConfig::default(), true)
        .await
        .is_err());
    assert_eq!(
        store.load().unwrap().engine.stockfish_path,
        original.engine.stockfish_path
    );
}

#[tokio::test]
async fn unconfigured_analysis_does_not_leave_a_phantom_job() {
    let (_dir, _store, manager) = manager();
    let request: AnalyzeRequest = serde_json::from_value(serde_json::json!({
        "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    }))
    .unwrap();
    assert!(manager.analyze(request).await.is_err());
    let status = manager.status();
    assert_eq!(status.status, "not_configured");
    assert!(status.current_job_id.is_none());
}
