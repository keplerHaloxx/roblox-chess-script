use std::{
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, Mutex,
    },
    time::Instant,
};

use axum::http::StatusCode;
use shakmaty::{fen::Fen, CastlingMode, Chess, Position};
use thiserror::Error;
use uuid::Uuid;

use crate::{
    api::types::{AnalyzeRequest, AnalyzeResponse, EngineStatusResponse, EngineSummary},
    config::{model::AppConfig, store::ConfigStore},
    engine::{
        difficulty::{self, DifficultyInput},
        installer,
        stockfish::{StockfishError, StockfishProcess},
    },
};

#[derive(Debug, Clone)]
pub enum EngineStatus {
    NotConfigured,
    Starting,
    Ready,
    Analyzing,
    Restarting,
    Crashed,
    Error,
}

impl EngineStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            EngineStatus::NotConfigured => "not_configured",
            EngineStatus::Starting => "starting",
            EngineStatus::Ready => "ready",
            EngineStatus::Analyzing => "analyzing",
            EngineStatus::Restarting => "restarting",
            EngineStatus::Crashed => "crashed",
            EngineStatus::Error => "error",
        }
    }
}

#[derive(Debug, Error)]
pub enum EngineManagerError {
    #[error("Stockfish is not configured. Use the dashboard to detect, choose, or download it.")]
    NotConfigured,
    #[error("analysis was cancelled by a newer request or a cancellation command")]
    Cancelled,
    #[error("invalid FEN")]
    InvalidFen,
    #[error("invalid request: {0}")]
    InvalidRequest(String),
    #[error("Stockfish error: {0}")]
    Stockfish(#[from] StockfishError),
    #[error("Stockfish installer error: {0}")]
    Installer(#[from] installer::InstallerError),
    #[error("engine task failed: {0}")]
    Join(String),
    #[error("engine lock is poisoned")]
    LockPoisoned,
}

impl EngineManagerError {
    pub fn to_api_parts(&self) -> (StatusCode, &'static str, String) {
        match self {
            EngineManagerError::NotConfigured => (
                StatusCode::SERVICE_UNAVAILABLE,
                "engine_not_configured",
                self.to_string(),
            ),
            EngineManagerError::Cancelled => {
                (StatusCode::CONFLICT, "analysis_cancelled", self.to_string())
            }
            EngineManagerError::InvalidFen => (
                StatusCode::BAD_REQUEST,
                "invalid_fen",
                "The provided FEN is invalid.".to_string(),
            ),
            EngineManagerError::InvalidRequest(message) => {
                (StatusCode::BAD_REQUEST, "invalid_request", message.clone())
            }
            EngineManagerError::Stockfish(StockfishError::Timeout(_)) => (
                StatusCode::GATEWAY_TIMEOUT,
                "engine_timeout",
                self.to_string(),
            ),
            EngineManagerError::Stockfish(StockfishError::EngineExited) => (
                StatusCode::SERVICE_UNAVAILABLE,
                "engine_exited",
                self.to_string(),
            ),
            EngineManagerError::Stockfish(_) => {
                (StatusCode::BAD_GATEWAY, "engine_error", self.to_string())
            }
            EngineManagerError::Installer(_) => (
                StatusCode::BAD_GATEWAY,
                "stockfish_download_failed",
                self.to_string(),
            ),
            EngineManagerError::Join(_) | EngineManagerError::LockPoisoned => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal_engine_error",
                self.to_string(),
            ),
        }
    }
}

#[derive(Clone)]
pub struct EngineManager {
    inner: Arc<Mutex<ManagedEngine>>,
    process: Arc<Mutex<Option<StockfishProcess>>>,
    cancel_generation: Arc<AtomicU64>,
    install_lock: Arc<tokio::sync::Mutex<()>>,
    config_store: ConfigStore,
}

struct ManagedEngine {
    status: EngineStatus,
    stockfish_path: Option<PathBuf>,
    name: Option<String>,
    last_error: Option<String>,
    current_job_id: Option<String>,
}

impl EngineManager {
    pub fn new(config_store: ConfigStore) -> Self {
        Self {
            inner: Arc::new(Mutex::new(ManagedEngine {
                status: EngineStatus::NotConfigured,
                stockfish_path: None,
                name: None,
                last_error: None,
                current_job_id: None,
            })),
            process: Arc::new(Mutex::new(None)),
            cancel_generation: Arc::new(AtomicU64::new(0)),
            install_lock: Arc::new(tokio::sync::Mutex::new(())),
            config_store,
        }
    }

    pub async fn initialize_from_config(&self) -> Result<(), EngineManagerError> {
        let config = self.config_store.load_or_default();
        let data_dir = self.config_store.data_dir();
        let path = installer::detect_stockfish(config.engine.stockfish_path.as_deref(), &data_dir)
            .ok_or(EngineManagerError::NotConfigured)?;

        self.start_with_path(path, &config).await
    }

    pub async fn restart(&self) -> Result<(), EngineManagerError> {
        let config = self.config_store.load_or_default();
        let path = {
            let inner = self
                .inner
                .lock()
                .map_err(|_| EngineManagerError::LockPoisoned)?;
            inner
                .stockfish_path
                .clone()
                .or_else(|| config.engine.stockfish_path.as_ref().map(PathBuf::from))
        };
        let path = path.ok_or(EngineManagerError::NotConfigured)?;
        self.start_with_path(path, &config).await
    }

    pub async fn detect(&self) -> Option<PathBuf> {
        let config = self.config_store.load_or_default();
        installer::detect_stockfish(
            config.engine.stockfish_path.as_deref(),
            &self.config_store.data_dir(),
        )
    }

    pub async fn choose_with_native_dialog(&self) -> Option<PathBuf> {
        tokio::task::spawn_blocking(|| {
            let mut dialog = rfd::FileDialog::new().set_title("Choose Stockfish executable");
            #[cfg(target_os = "windows")]
            {
                dialog = dialog.add_filter("Executable", &["exe"]);
            }
            dialog.pick_file()
        })
        .await
        .ok()
        .flatten()
    }

    pub async fn download_latest(&self) -> Result<PathBuf, EngineManagerError> {
        let _install_guard = self.install_lock.lock().await;
        let path = installer::download_latest_stockfish(&self.config_store.data_dir()).await?;

        self.use_stockfish_path(path.clone())
            .await
            .map_err(EngineManagerError::InvalidRequest)?;
        Ok(path)
    }

    pub async fn apply_config(
        &self,
        config: AppConfig,
        restart_engine: bool,
    ) -> Result<(), EngineManagerError> {
        config
            .validate()
            .map_err(EngineManagerError::InvalidRequest)?;
        if restart_engine {
            let path = config
                .engine
                .stockfish_path
                .as_ref()
                .map(PathBuf::from)
                .ok_or(EngineManagerError::NotConfigured)?;
            self.start_with_path(path, &config).await?;
        } else {
            self.apply_engine_options(&config).await?;
        }

        self.config_store
            .save(&config)
            .map_err(|err| EngineManagerError::InvalidRequest(err.to_string()))?;
        Ok(())
    }

    pub async fn analyze(
        &self,
        request: AnalyzeRequest,
    ) -> Result<AnalyzeResponse, EngineManagerError> {
        let request_id = request
            .request_id
            .clone()
            .unwrap_or_else(|| Uuid::new_v4().to_string());
        let config = self.config_store.load_or_default();
        let depth = request.depth.unwrap_or(17);
        let max_think_time_ms = request.max_think_time_ms.unwrap_or(100);
        let disregard_think_time = request.disregard_think_time.unwrap_or(false);

        validate_analyze_params(depth, max_think_time_ms)?;
        let features = position_features(&request.fen)?;

        if config.engine.auto_restart && self.status().status == "crashed" {
            self.restart().await?;
        }

        if config.analysis.cancel_previous_on_new_request {
            self.cancel();
        }
        let generation = self.cancel_generation.load(Ordering::SeqCst);

        let inner = self.inner.clone();
        let cancel_generation = self.cancel_generation.clone();
        let process = self.process.clone();
        let fen = request.fen.clone();
        let request_id_for_task = request_id.clone();

        let result = tokio::task::spawn_blocking(move || {
            let mut process_guard = process
                .lock()
                .map_err(|_| EngineManagerError::LockPoisoned)?;
            if cancel_generation.load(Ordering::SeqCst) != generation {
                return Err(EngineManagerError::Cancelled);
            }
            let process = process_guard
                .as_mut()
                .ok_or(EngineManagerError::NotConfigured)?;
            {
                let mut inner = inner.lock().map_err(|_| EngineManagerError::LockPoisoned)?;
                inner.current_job_id = Some(request_id_for_task);
                inner.status = EngineStatus::Analyzing;
                inner.last_error = None;
            }

            let started = Instant::now();
            let raw = process.new_game().and_then(|()| {
                process.analyze(&fen, depth, max_think_time_ms, disregard_think_time, || {
                    cancel_generation.load(Ordering::SeqCst) != generation
                })
            });
            let time_taken_ms = started.elapsed().as_millis();

            let mut inner = inner.lock().map_err(|_| EngineManagerError::LockPoisoned)?;
            match raw {
                Ok(raw) => {
                    inner.status = EngineStatus::Ready;
                    inner.current_job_id = None;
                    if cancel_generation.load(Ordering::SeqCst) != generation {
                        return Err(EngineManagerError::Cancelled);
                    }
                    Ok((
                        raw,
                        time_taken_ms,
                        inner.name.clone(),
                        inner.status.as_str().to_string(),
                    ))
                }
                Err(err) => {
                    if let Some(process) = process_guard.as_mut() {
                        process.try_kill();
                    }
                    *process_guard = None;
                    inner.status = EngineStatus::Crashed;
                    inner.current_job_id = None;
                    inner.last_error = Some(err.to_string());
                    Err(EngineManagerError::Stockfish(err))
                }
            }
        })
        .await
        .map_err(|err| EngineManagerError::Join(err.to_string()))??;

        let (raw, time_taken_ms, engine_name, engine_status) = result;
        let difficulty = if config.analysis.difficulty_enabled {
            Some(difficulty::calculate(DifficultyInput {
                legal_move_count: features.legal_move_count,
                in_check: features.in_check,
                lines: raw.lines.clone(),
                candidate_threshold_cp: config.analysis.candidate_threshold_cp,
                min_delay_ms: config.analysis.min_delay_ms,
                max_delay_ms: config.analysis.max_delay_ms,
            }))
        } else {
            None
        };

        Ok(AnalyzeResponse {
            ok: true,
            request_id,
            best_move: raw.best_move,
            ponder: raw.ponder,
            depth,
            time_taken_ms,
            difficulty,
            lines: raw.lines,
            engine: EngineSummary {
                name: engine_name,
                status: engine_status,
            },
        })
    }

    pub fn cancel(&self) {
        self.cancel_generation.fetch_add(1, Ordering::SeqCst);
    }

    pub fn status(&self) -> EngineStatusResponse {
        match self.inner.lock() {
            Ok(inner) => EngineStatusResponse {
                status: inner.status.as_str().to_string(),
                name: inner.name.clone(),
                stockfish_path: inner
                    .stockfish_path
                    .as_ref()
                    .map(|path| path.display().to_string()),
                last_error: inner.last_error.clone(),
                current_job_id: inner.current_job_id.clone(),
            },
            Err(_) => EngineStatusResponse {
                status: EngineStatus::Error.as_str().to_string(),
                name: None,
                stockfish_path: None,
                last_error: Some("engine lock is poisoned".to_string()),
                current_job_id: None,
            },
        }
    }

    async fn start_with_path(
        &self,
        path: PathBuf,
        config: &AppConfig,
    ) -> Result<(), EngineManagerError> {
        let inner = self.inner.clone();
        let config = config.clone();
        let process = self.process.clone();
        self.cancel();

        tokio::task::spawn_blocking(move || {
        let mut process_guard = process.lock().map_err(|_| EngineManagerError::LockPoisoned)?;
        {
            let mut inner = inner.lock().map_err(|_| EngineManagerError::LockPoisoned)?;
            inner.status = if process_guard.is_some() {
                EngineStatus::Restarting
            } else {
                EngineStatus::Starting
            };
            inner.last_error = None;
            inner.current_job_id = None;
        }

        let startup_result = (|| -> Result<StockfishProcess, EngineManagerError> {
            let mut process = StockfishProcess::spawn(&path)?;
            apply_options_to_process(&mut process, &config)?;
            Ok(process)
        })();

        match startup_result {
            Ok(new_process) => {
                let name = new_process.name.clone();

                let mut inner = inner.lock().map_err(|_| EngineManagerError::LockPoisoned)?;

                if let Some(old_process) = process_guard.as_mut() {
                    old_process.try_kill();
                }

                *process_guard = Some(new_process);
                inner.stockfish_path = Some(path.clone());
                inner.name = name;
                inner.status = EngineStatus::Ready;
                inner.last_error = None;
                inner.current_job_id = None;

                Ok(())
            }
            Err(err) => {
                let mut inner = inner.lock().map_err(|_| EngineManagerError::LockPoisoned)?;

                if process_guard.is_some() {
                    inner.status = EngineStatus::Ready;
                    inner.last_error = Some(format!(
                        "Could not switch to the new Stockfish at {}: {err}. Keeping the current engine.",
                        path.display()
                    ));
                } else {
                    *process_guard = None;
                    inner.stockfish_path = Some(path.clone());
                    inner.name = None;
                    inner.status = EngineStatus::Error;
                    inner.last_error = Some(err.to_string());
                    inner.current_job_id = None;
                }

                Err(err)
            }
        }
        })
        .await
        .map_err(|err| EngineManagerError::Join(err.to_string()))?
    }

    async fn apply_engine_options(&self, config: &AppConfig) -> Result<(), EngineManagerError> {
        let process = self.process.clone();
        let config = config.clone();
        tokio::task::spawn_blocking(move || {
            let mut process_guard = process
                .lock()
                .map_err(|_| EngineManagerError::LockPoisoned)?;
            if let Some(process) = process_guard.as_mut() {
                apply_options_to_process(process, &config)?;
            }
            Ok(())
        })
        .await
        .map_err(|err| EngineManagerError::Join(err.to_string()))?
    }

    pub async fn detect_stockfish(&self) -> Result<Option<std::path::PathBuf>, String> {
        let _install_guard = self.install_lock.lock().await;

        let detected =
            crate::engine::installer::find_existing_stockfish(&self.config_store.data_dir())
                .map_err(|err| format!("Could not search for Stockfish: {err}"))?;

        let Some(path) = detected else {
            return Ok(None);
        };

        self.use_stockfish_path(path.clone()).await?;

        Ok(Some(path))
    }

    pub async fn choose_stockfish_manually(
        &self,
        path: std::path::PathBuf,
    ) -> Result<std::path::PathBuf, String> {
        let _install_guard = self.install_lock.lock().await;

        let installed_path = crate::engine::installer::install_manual_stockfish(
            &path,
            &self.config_store.data_dir(),
        )
        .map_err(|err| format!("Could not use the selected Stockfish file: {err}"))?;

        self.use_stockfish_path(installed_path.clone()).await?;

        Ok(installed_path)
    }

    pub async fn download_stockfish(&self) -> Result<std::path::PathBuf, String> {
        let _install_guard = self.install_lock.lock().await;

        let path =
            crate::engine::installer::download_latest_stockfish(&self.config_store.data_dir())
                .await
                .map_err(|err| format!("Could not download Stockfish: {err}"))?;

        self.use_stockfish_path(path.clone()).await.map_err(|err| {
            format!(
                "Stockfish was downloaded to {}, but it could not be started: {err}",
                path.display()
            )
        })?;

        Ok(path)
    }

    pub async fn redownload_stockfish(&self) -> Result<std::path::PathBuf, String> {
        let _install_guard = self.install_lock.lock().await;

        let path =
            crate::engine::installer::redownload_latest_stockfish(&self.config_store.data_dir())
                .await
                .map_err(|err| format!("Could not redownload Stockfish: {err}"))?;

        self.use_stockfish_path(path.clone()).await?;

        Ok(path)
    }

    pub async fn use_stockfish_path(
        &self,
        path: std::path::PathBuf,
    ) -> Result<std::path::PathBuf, String> {
        crate::engine::installer::validate_stockfish_path(&path)
            .map_err(|err| format!("Invalid Stockfish file: {err}"))?;

        let mut config = self
            .config_store
            .load()
            .map_err(|err| format!("Could not load settings: {err}"))?;

        config.engine.stockfish_path = Some(path.display().to_string());

        self.start_with_path(path.clone(), &config)
            .await
            .map_err(|err| format!("Stockfish could not be started: {err}"))?;

        self.config_store
            .save(&config)
            .map_err(|err| format!("Could not save Stockfish path: {err}"))?;

        Ok(path)
    }
}

fn apply_options_to_process(
    process: &mut StockfishProcess,
    config: &AppConfig,
) -> Result<(), StockfishError> {
    process.set_option("Hash", &config.engine.hash_mb.to_string())?;
    process.set_option("Threads", &config.engine.threads.to_string())?;
    process.set_option("MultiPV", &config.engine.multipv.to_string())?;

    let joined = config
        .engine
        .syzygy_paths
        .join(if cfg!(target_os = "windows") {
            ";"
        } else {
            ":"
        });
    process.set_option("SyzygyPath", &joined)?;

    Ok(())
}

fn validate_analyze_params(depth: u32, max_think_time_ms: u64) -> Result<(), EngineManagerError> {
    if !(1..=40).contains(&depth) {
        return Err(EngineManagerError::InvalidRequest(
            "depth must be between 1 and 40".to_string(),
        ));
    }
    if !(10..=120_000).contains(&max_think_time_ms) {
        return Err(EngineManagerError::InvalidRequest(
            "max_think_time_ms must be between 10 and 120000".to_string(),
        ));
    }
    Ok(())
}

struct PositionFeatures {
    legal_move_count: usize,
    in_check: bool,
}

fn position_features(fen: &str) -> Result<PositionFeatures, EngineManagerError> {
    let fen: Fen = fen.parse().map_err(|_| EngineManagerError::InvalidFen)?;
    let position: Chess = fen
        .into_position(CastlingMode::Standard)
        .map_err(|_| EngineManagerError::InvalidFen)?;

    Ok(PositionFeatures {
        legal_move_count: position.legal_moves().len(),
        in_check: position.is_check(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reported_check_positions_require_black_to_move() {
        let placements = [
            "r3kb1r/p2Q1ppp/2Pp4/4p3/p3P1n1/P1NPB1Pq/1P3P1P/R3K2R",
            "r1b1kbnr/ppp2ppp/3p4/1B1Pp3/1n2P2q/2N1B3/PPP2PPP/R2QK1NR",
        ];
        for placement in placements {
            assert!(position_features(&format!("{placement} w - - 0 1")).is_err());
            let black_turn = position_features(&format!("{placement} b - - 0 1"))
                .expect("reported position should be legal with Black to move");
            assert!(black_turn.in_check);
        }
    }

    #[test]
    fn status_remains_available_while_process_is_locked() {
        let dir = tempfile::tempdir().unwrap();
        let store =
            ConfigStore::from_paths(dir.path().join("config.json"), dir.path().join("data"))
                .unwrap();
        let manager = EngineManager::new(store);
        let process_guard = manager.process.lock().unwrap();
        let clone = manager.clone();
        let (sender, receiver) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || sender.send(clone.status()).unwrap());
        let result = receiver.recv_timeout(std::time::Duration::from_secs(1));
        drop(process_guard);
        worker.join().unwrap();
        assert_eq!(result.unwrap().status, "not_configured");
    }

    #[tokio::test]
    async fn cancelled_queued_request_never_starts() {
        let dir = tempfile::tempdir().unwrap();
        let store =
            ConfigStore::from_paths(dir.path().join("config.json"), dir.path().join("data"))
                .unwrap();
        let manager = EngineManager::new(store);
        let process = manager.process.clone();
        let (acquired_sender, acquired_receiver) = std::sync::mpsc::channel();
        let (release_sender, release_receiver) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            let _guard = process.lock().unwrap();
            acquired_sender.send(()).unwrap();
            release_receiver.recv().unwrap();
        });
        acquired_receiver.recv().unwrap();
        let clone = manager.clone();
        let request: AnalyzeRequest = serde_json::from_value(serde_json::json!({
            "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        }))
        .unwrap();
        let task = tokio::spawn(async move { clone.analyze(request).await });
        tokio::task::yield_now().await;
        manager.cancel();
        release_sender.send(()).unwrap();
        worker.join().unwrap();
        assert!(matches!(
            task.await.unwrap(),
            Err(EngineManagerError::Cancelled)
        ));
        assert!(manager.status().current_job_id.is_none());
    }
}
