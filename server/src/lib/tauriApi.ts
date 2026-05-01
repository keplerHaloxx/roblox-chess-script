import { invoke } from '@tauri-apps/api/core';

import type {
  AppConfig,
  BotTimingPreset,
  DetectStockfishResponse,
  GenericOkResponse,
  HistoryItem,
  UiStatusResponse,
} from '$lib/types/app';

export function getUiStatus() {
  return invoke<UiStatusResponse>('get_ui_status');
}

export function getSettings() {
  return invoke<AppConfig>('get_settings');
}

export function saveSettings(config: AppConfig, restart_engine?: boolean) {
  return invoke<GenericOkResponse>('save_settings', {
    request: { config, restart_engine },
  });
}

export function updateSettings(config: AppConfig, restart_engine?: boolean) {
  return invoke<GenericOkResponse>('update_settings', {
    request: { config, restart_engine },
  });
}

export function setTimingPreset(preset: BotTimingPreset) {
  return invoke<GenericOkResponse>('set_timing_preset', {
    request: { preset },
  });
}

export function restartEngine() {
  return invoke<GenericOkResponse>('restart_engine');
}

export function cancelAnalysis() {
  return invoke<GenericOkResponse>('cancel_analysis');
}

export function detectStockfish() {
  return invoke<DetectStockfishResponse>('detect_stockfish');
}

export function chooseStockfishManually() {
  return invoke<DetectStockfishResponse>('choose_stockfish_manually');
}

export function downloadStockfish() {
  return invoke<DetectStockfishResponse>('download_stockfish');
}

export function redownloadStockfish() {
  return invoke<DetectStockfishResponse>('redownload_stockfish');
}

export function redownloadEngine() {
  return invoke<GenericOkResponse>('redownload_engine');
}

export function resetRecommendedSettings() {
  return invoke<GenericOkResponse>('reset_recommended_settings');
}

export function resetSettings() {
  return invoke<GenericOkResponse>('reset_settings');
}

export function chooseSyzygyFolders() {
  return invoke<GenericOkResponse>('choose_syzygy_folders');
}

export function clearSyzygyFolders() {
  return invoke<GenericOkResponse>('clear_syzygy_folders');
}

export function getHistory() {
  return invoke<HistoryItem[]>('get_history');
}

export function testConnection() {
  return invoke<GenericOkResponse>('test_connection');
}
