use std::{collections::VecDeque, sync::Arc};

use tokio::sync::Mutex;

use crate::{api::types::HistoryItem, config::store::ConfigStore, engine::manager::EngineManager};

#[derive(Clone)]
pub struct AppState {
    pub config_store: ConfigStore,
    pub engine: EngineManager,
    history: Arc<Mutex<VecDeque<HistoryItem>>>,
}

impl AppState {
    pub fn new(config_store: ConfigStore, engine: EngineManager) -> Self {
        Self {
            config_store,
            engine,
            history: Arc::new(Mutex::new(VecDeque::with_capacity(100))),
        }
    }

    pub async fn push_history(&self, item: HistoryItem) {
        let mut history = self.history.lock().await;
        if history.len() >= 100 {
            history.pop_front();
        }
        history.push_back(item);
    }

    pub async fn history(&self) -> Vec<HistoryItem> {
        self.history.lock().await.iter().cloned().collect()
    }
}
