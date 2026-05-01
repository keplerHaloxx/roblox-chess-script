use axum::{http::StatusCode, response::IntoResponse, Json};
use serde::Serialize;
use thiserror::Error;

use crate::{config::store::ConfigError, engine::manager::EngineManagerError};

#[derive(Debug, Error)]
pub enum ApiError {
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("engine error: {0}")]
    Engine(#[from] EngineManagerError),
    #[error("config error: {0}")]
    Config(#[from] ConfigError),
    #[error("internal error")]
    Internal,
}

#[derive(Debug, Serialize)]
struct ErrorBody {
    ok: bool,
    error: ErrorDetails,
}

#[derive(Debug, Serialize)]
struct ErrorDetails {
    code: &'static str,
    message: String,
}

impl ApiError {
    pub fn internal(err: impl std::fmt::Display) -> Self {
        tracing::error!(%err, "internal api error");
        ApiError::Internal
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let (status, code, message) = match self {
            ApiError::BadRequest(message) => (StatusCode::BAD_REQUEST, "bad_request", message),
            ApiError::Engine(err) => err.to_api_parts(),
            ApiError::Config(err) => (StatusCode::BAD_REQUEST, "config_error", err.to_string()),
            ApiError::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "An unexpected error occurred.".to_string(),
            ),
        };

        (
            status,
            Json(ErrorBody {
                ok: false,
                error: ErrorDetails { code, message },
            }),
        )
            .into_response()
    }
}
