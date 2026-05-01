use std::net::SocketAddr;

use axum::Router;
use tower_http::trace::TraceLayer;

use crate::{api::routes::api_routes, app_state::AppState};

pub async fn serve(state: AppState) -> std::io::Result<()> {
    let config = state.config_store.load_or_default();
    let bind_address = SocketAddr::new(config.server.host, config.server.port);

    let app = Router::new()
        .nest("/api/v1", api_routes())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    tracing::info!(%bind_address, "starting local Roblox API");
    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    axum::serve(listener, app).await
}
