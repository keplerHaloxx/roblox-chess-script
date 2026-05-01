use std::net::{IpAddr, Ipv4Addr};

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub engine: EngineConfig,
    pub analysis: AnalysisConfig,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: IpAddr,
    pub port: u16,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EngineConfig {
    pub stockfish_path: Option<String>,
    pub hash_mb: u32,
    pub threads: u32,
    pub syzygy_paths: Vec<String>,
    pub multipv: u8,
    pub auto_restart: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AnalysisConfig {
    pub difficulty_enabled: bool,
    pub candidate_threshold_cp: i32,
    pub cancel_previous_on_new_request: bool,
    pub min_delay_ms: u64,
    pub max_delay_ms: u64,
    #[serde(default = "default_timing_preset")]
    pub timing_preset: BotTimingPreset,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BotTimingPreset {
    Quick,
    Balanced,
    Careful,
    VeryCareful,
}

impl BotTimingPreset {
    pub fn label(self) -> &'static str {
        match self {
            BotTimingPreset::Quick => "Quick",
            BotTimingPreset::Balanced => "Balanced",
            BotTimingPreset::Careful => "Careful",
            BotTimingPreset::VeryCareful => "Very Careful",
        }
    }

    pub fn delay_bounds(self) -> (u64, u64) {
        match self {
            BotTimingPreset::Quick => (75, 900),
            BotTimingPreset::Balanced => (150, 2_000),
            BotTimingPreset::Careful => (400, 4_000),
            BotTimingPreset::VeryCareful => (750, 7_500),
        }
    }
}

impl Default for AppConfig {
    fn default() -> Self {
        let threads = recommended_threads();
        let timing_preset = BotTimingPreset::Balanced;
        let (min_delay_ms, max_delay_ms) = timing_preset.delay_bounds();

        Self {
            server: ServerConfig {
                host: IpAddr::V4(Ipv4Addr::LOCALHOST),
                port: 57250,
            },
            engine: EngineConfig {
                stockfish_path: None,
                hash_mb: recommended_hash_mb(),
                threads,
                syzygy_paths: Vec::new(),
                multipv: 4,
                auto_restart: true,
            },
            analysis: AnalysisConfig {
                difficulty_enabled: true,
                candidate_threshold_cp: 80,
                cancel_previous_on_new_request: true,
                min_delay_ms,
                max_delay_ms,
                timing_preset,
            },
        }
    }
}

impl AppConfig {
    pub fn validate(&self) -> Result<(), String> {
        if self.server.port == 0 {
            return Err("server port must be greater than zero".to_string());
        }
        if self.engine.hash_mb == 0 || self.engine.hash_mb > 65_536 {
            return Err("hash_mb must be between 1 and 65536".to_string());
        }
        let max_threads = std::thread::available_parallelism()
            .map(|n| n.get() as u32)
            .unwrap_or(64)
            .max(64);
        if self.engine.threads == 0 || self.engine.threads > max_threads {
            return Err(format!("threads must be between 1 and {max_threads}"));
        }
        if self.engine.multipv == 0 || self.engine.multipv > 8 {
            return Err("multipv must be between 1 and 8".to_string());
        }
        if self.analysis.candidate_threshold_cp < 0 || self.analysis.candidate_threshold_cp > 500 {
            return Err("candidate_threshold_cp must be between 0 and 500".to_string());
        }
        if self.analysis.min_delay_ms > self.analysis.max_delay_ms {
            return Err("min_delay_ms must be less than or equal to max_delay_ms".to_string());
        }
        Ok(())
    }

    pub fn apply_timing_preset(&mut self, preset: BotTimingPreset) {
        let (min_delay_ms, max_delay_ms) = preset.delay_bounds();
        self.analysis.timing_preset = preset;
        self.analysis.min_delay_ms = min_delay_ms;
        self.analysis.max_delay_ms = max_delay_ms;
    }
}

fn default_timing_preset() -> BotTimingPreset {
    BotTimingPreset::Balanced
}

pub fn recommended_hash_mb() -> u32 {
    256
}

pub fn recommended_threads() -> u32 {
    let cpus = std::thread::available_parallelism()
        .map(|n| n.get() as u32)
        .unwrap_or(1);

    cpus.saturating_sub(1).clamp(1, 8)
}
