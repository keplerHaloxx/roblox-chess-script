use axum::{
    body::Body,
    http::{Request, StatusCode},
    Router,
};
use roblox_chess_script_lib::{
    api::routes::api_routes, app_state::AppState, config::store::ConfigStore,
    engine::manager::EngineManager,
};
use serde_json::{json, Value};
use tower::ServiceExt;

fn temp_store() -> (tempfile::TempDir, ConfigStore) {
    let dir = tempfile::tempdir().expect("temp dir");
    let store = ConfigStore::from_paths(
        dir.path().join("config").join("config.json"),
        dir.path().join("data"),
    )
    .expect("store");
    (dir, store)
}

fn test_app() -> (tempfile::TempDir, Router) {
    let (dir, store) = temp_store();
    let engine = EngineManager::new(store.clone());
    let state = AppState::new(store, engine);
    let app = Router::new()
        .nest("/api/v1", api_routes())
        .with_state(state);
    (dir, app)
}

async fn json_response(app: Router, request: Request<Body>) -> (StatusCode, Value) {
    let response = app.oneshot(request).await.expect("response");
    let status = response.status();
    let body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .expect("body bytes");
    let value: Value = serde_json::from_slice(&body).expect("json body");
    (status, value)
}

#[tokio::test]
async fn status_endpoint_returns_default_not_configured_state() {
    let (_dir, app) = test_app();
    let request = Request::builder()
        .method("GET")
        .uri("/api/v1/status")
        .body(Body::empty())
        .unwrap();

    let (status, value) = json_response(app, request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["ok"], true);
    assert_eq!(value["engine"]["status"], "not_configured");
    assert_eq!(value["config"]["server"]["port"], 57250);
}

#[tokio::test]
async fn analyze_rejects_invalid_fen_with_structured_error() {
    let (_dir, app) = test_app();
    let body = json!({
        "fen": "not a fen",
        "depth": 12,
        "max_think_time_ms": 100,
        "disregard_think_time": false
    });
    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/analyze")
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap();

    let (status, value) = json_response(app, request).await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(value["ok"], false);
    assert_eq!(value["error"]["code"], "invalid_fen");
}

#[tokio::test]
async fn analyze_returns_engine_not_configured_for_valid_fen_without_stockfish() {
    let (_dir, app) = test_app();
    let body = json!({
        "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "depth": 12,
        "max_think_time_ms": 100,
        "disregard_think_time": false
    });
    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/analyze")
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap();

    let (status, value) = json_response(app, request).await;

    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["ok"], false);
    assert_eq!(value["error"]["code"], "engine_not_configured");
}

#[tokio::test]
async fn cancel_endpoint_is_idempotent() {
    let (_dir, app) = test_app();
    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/analyze/cancel")
        .body(Body::empty())
        .unwrap();

    let (status, value) = json_response(app, request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(value["ok"], true);
}

#[tokio::test]
async fn update_settings_rejects_invalid_config_with_structured_error() {
    let (_dir, app) = test_app();
    let body = json!({
        "config": {
            "server": { "host": "127.0.0.1", "port": 0 },
            "engine": {
                "stockfish_path": null,
                "hash_mb": 256,
                "threads": 1,
                "syzygy_paths": [],
                "multipv": 4,
                "auto_restart": true
            },
            "analysis": {
                "difficulty_enabled": true,
                "candidate_threshold_cp": 80,
                "cancel_previous_on_new_request": true,
                "min_delay_ms": 150,
                "max_delay_ms": 2000,
                "timing_preset": "balanced"
            }
        },
        "restart_engine": false
    });
    let request = Request::builder()
        .method("PUT")
        .uri("/api/v1/settings")
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap();

    let (status, value) = json_response(app, request).await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(value["ok"], false);
    assert_eq!(value["error"]["code"], "invalid_request");
}
