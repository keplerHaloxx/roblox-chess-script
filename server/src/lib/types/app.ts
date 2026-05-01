export type BotTimingPreset = 'quick' | 'balanced' | 'careful' | 'very_careful';

export interface AppConfig {
  server: {
    host: string;
    port: number;
  };
  engine: {
    stockfish_path: string | null;
    hash_mb: number;
    threads: number;
    syzygy_paths: string[];
    multipv: number;
    auto_restart: boolean;
  };
  analysis: {
    difficulty_enabled: boolean;
    candidate_threshold_cp: number;
    cancel_previous_on_new_request: boolean;
    min_delay_ms: number;
    max_delay_ms: number;
    timing_preset: BotTimingPreset;
  };
}

export interface Difficulty {
  score: number;
  label: string;
  reason: string;
  recommended_delay_ms: number;
}

export interface EngineStatus {
  status: string;
  name: string | null;
  stockfish_path: string | null;
  last_error: string | null;
  current_job_id: string | null;
}

export interface HistoryItem {
  id: string;
  timestamp: string;
  fen: string;
  best_move: string | null;
  difficulty: Difficulty | null;
  time_taken_ms: number | null;
  status: string;
  error: string | null;
}

export interface UiStatusResponse {
  ok: boolean;
  ready_for_roblox: boolean;
  setup_required: boolean;
  status_label: string;
  helper_text: string;
  engine: EngineStatus;
  config: AppConfig;
  config_path: string;
  last_activity: HistoryItem | null;
  history_count: number;
}

export interface GenericOkResponse {
  ok: boolean;
  message: string;
}

export interface DetectStockfishResponse {
  ok: boolean;
  path: string | null;
  message: string;
}
