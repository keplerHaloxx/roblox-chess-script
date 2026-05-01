use roblox_chess_script_lib::config::{model::AppConfig, store::ConfigStore};

fn temp_store() -> (tempfile::TempDir, ConfigStore) {
    let dir = tempfile::tempdir().expect("temp dir");
    let store = ConfigStore::from_paths(
        dir.path().join("config").join("config.json"),
        dir.path().join("data"),
    )
    .expect("store");
    (dir, store)
}

#[test]
fn default_config_is_valid() {
    let config = AppConfig::default();
    config.validate().expect("default config should validate");
    assert_eq!(config.server.port, 57250);
    assert!(config.engine.multipv >= 1);
    assert!(config.analysis.difficulty_enabled);
}

#[test]
fn config_store_saves_and_loads_round_trip() {
    let (_dir, store) = temp_store();
    let mut config = AppConfig::default();
    config.engine.hash_mb = 1024;
    config.engine.threads = 1;
    config.engine.stockfish_path = Some("C:/tools/stockfish.exe".to_string());
    config.analysis.min_delay_ms = 250;
    config.analysis.max_delay_ms = 1750;

    store.save(&config).expect("save config");
    let loaded = store.load().expect("load config");

    assert_eq!(loaded.engine.hash_mb, 1024);
    assert_eq!(loaded.engine.threads, 1);
    assert_eq!(
        loaded.engine.stockfish_path.as_deref(),
        Some("C:/tools/stockfish.exe")
    );
    assert_eq!(loaded.analysis.min_delay_ms, 250);
    assert_eq!(loaded.analysis.max_delay_ms, 1750);
}

#[test]
fn invalid_config_is_rejected() {
    let (_dir, store) = temp_store();
    let mut config = AppConfig::default();
    config.engine.hash_mb = 0;

    let err = store.save(&config).expect_err("invalid config should fail");
    assert!(err.to_string().contains("hash_mb"));
}
