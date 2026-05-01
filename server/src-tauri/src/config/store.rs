use std::{fs, io, path::PathBuf};

use directories::ProjectDirs;
use thiserror::Error;

use super::model::AppConfig;

#[derive(Clone, Debug)]
pub struct ConfigStore {
    config_path: PathBuf,
    data_dir: PathBuf,
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("could not resolve application config directory")]
    MissingProjectDirectory,
    #[error("io error: {0}")]
    Io(#[from] io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("invalid config: {0}")]
    Invalid(String),
}

impl ConfigStore {
    #[doc(hidden)]
    pub fn from_paths(config_path: PathBuf, data_dir: PathBuf) -> Result<Self, ConfigError> {
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::create_dir_all(&data_dir)?;

        Ok(Self {
            config_path,
            data_dir,
        })
    }

    pub fn open() -> Result<Self, ConfigError> {
        let project_dirs = ProjectDirs::from("com", "local", "roblox-chess-script")
            .ok_or(ConfigError::MissingProjectDirectory)?;
        let config_dir = project_dirs.config_dir().to_path_buf();
        let data_dir = project_dirs.data_dir().to_path_buf();
        fs::create_dir_all(&config_dir)?;
        fs::create_dir_all(&data_dir)?;

        Ok(Self {
            config_path: config_dir.join("config.json"),
            data_dir,
        })
    }

    pub fn load_or_default(&self) -> AppConfig {
        match self.load() {
            Ok(config) => config,
            Err(err) => {
                tracing::warn!(%err, "using default config");
                let config = AppConfig::default();
                if let Err(save_err) = self.save(&config) {
                    tracing::warn!(%save_err, "failed to persist default config");
                }
                config
            }
        }
    }

    pub fn load(&self) -> Result<AppConfig, ConfigError> {
        if !self.config_path.exists() {
            return Ok(AppConfig::default());
        }

        let content = fs::read_to_string(&self.config_path)?;
        let config: AppConfig = serde_json::from_str(&content)?;
        config.validate().map_err(ConfigError::Invalid)?;
        Ok(config)
    }

    pub fn save(&self, config: &AppConfig) -> Result<(), ConfigError> {
        config.validate().map_err(ConfigError::Invalid)?;
        let json = serde_json::to_string_pretty(config)?;
        fs::write(&self.config_path, json)?;
        Ok(())
    }

    pub fn data_dir(&self) -> PathBuf {
        self.data_dir.clone()
    }

    pub fn config_path(&self) -> PathBuf {
        self.config_path.clone()
    }
}
