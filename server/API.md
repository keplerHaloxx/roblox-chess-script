# roblox-chess-script Local HTTP API

This document describes the local HTTP API exposed by `roblox-chess-script` for Roblox/client integration.

Default base URL:

```text
http://127.0.0.1:3000/api/v1
```

If the app's configured port changes, replace `3000` with the configured port.

All JSON endpoints use:

```http
Content-Type: application/json
```

## Response conventions

Successful object responses usually include:

```json
{
  "ok": true
}
```

User-action responses often return:

```json
{
  "ok": true,
  "message": "Engine restarted."
}
```

Errors use this shape:

```json
{
  "ok": false,
  "error": {
    "code": "bad_request",
    "message": "The provided FEN is invalid."
  }
}
```

Common error codes include:

| Code                    | Meaning                                                                  |
| ----------------------- | ------------------------------------------------------------------------ |
| `bad_request`           | The request body/query was invalid.                                      |
| `engine_not_configured` | No usable Stockfish/chess engine is configured.                          |
| `engine_busy`           | The engine is already analyzing and the request could not be accepted.   |
| `engine_error`          | The chess engine failed, crashed, timed out, or returned invalid output. |
| `config_error`          | Settings could not be loaded, validated, or saved.                       |
| `internal_error`        | Unexpected app/server error.                                             |

The exact engine-related codes depend on the Rust error mapping in `EngineManagerError::to_api_parts()`.

---

# Endpoints

## `GET /status`

Returns app configuration and current chess engine status.

### Purpose

Use this to check whether the local app is running, whether the engine is ready, and what server/config values are active.

### Request

No body.

### Response

```ts
interface StatusResponse {
  ok: true;
  engine: {
    status: string;
    name: string | null;
    stockfish_path: string | null;
    last_error: string | null;
    current_job_id: string | null;
  };
  config: AppConfig;
  config_path: string;
}
```

### Example

```bash
curl http://127.0.0.1:3000/api/v1/status
```

### Example response

```json
{
  "ok": true,
  "engine": {
    "status": "ready",
    "name": "Stockfish 18",
    "stockfish_path": "C:\\Users\\user\\AppData\\Roaming\\local\\roblox-chess-script\\data\\engines\\stockfish\\stockfish.exe",
    "last_error": null,
    "current_job_id": null
  },
  "config": {
    "server": {
      "host": "127.0.0.1",
      "port": 3000
    },
    "engine": {
      "stockfish_path": "C:\\Users\\user\\...\\stockfish.exe",
      "hash_mb": 256,
      "threads": 4,
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
  "config_path": "C:\\Users\\user\\AppData\\Roaming\\local\\roblox-chess-script\\config.json"
}
```

---

## `POST /analyze`

Analyzes a chess position and returns the best move, optional ponder move, candidate lines, difficulty estimate, and suggested delay.

### Purpose

This is the main endpoint the Roblox client should call when it needs a move.

### Request body

```ts
interface AnalyzeRequest {
  fen: string;
  depth?: number;
  max_think_time_ms?: number;
  disregard_think_time?: boolean;
  request_id?: string;
}
```

### Fields

| Field                  |      Type | Required | Purpose                                                                         |
| ---------------------- | --------: | -------: | ------------------------------------------------------------------------------- |
| `fen`                  |  `string` |      Yes | FEN string representing the current chess position.                             |
| `depth`                |  `number` |       No | Engine search depth. Defaults are controlled by backend logic if omitted.       |
| `max_think_time_ms`    |  `number` |       No | Maximum think time in milliseconds.                                             |
| `disregard_think_time` | `boolean` |       No | If true, search can ignore `max_think_time_ms` and rely more directly on depth. |
| `request_id`           |  `string` |       No | Optional client-provided ID echoed back in the response.                        |

### Response

```ts
interface AnalyzeResponse {
  ok: true;
  request_id: string;
  best_move: string;
  ponder: string | null;
  depth: number;
  time_taken_ms: number;
  difficulty: Difficulty | null;
  lines: AnalysisLine[];
  engine: {
    name: string | null;
    status: string;
  };
}
```

```ts
interface Difficulty {
  score: number;
  label: 'trivial' | 'easy' | 'medium' | 'hard' | 'very_hard';
  recommended_delay_ms: number;
  reason: string;
  legal_move_count: number;
  in_check: boolean;
  candidate_moves: number;
  best_second_gap_cp: number | null;
}
```

```ts
interface AnalysisLine {
  rank: number;
  depth: number | null;
  move_uci: string | null;
  score_cp: number | null;
  mate: number | null;
  pv: string[];
}
```

### Example

```bash
curl -X POST http://127.0.0.1:3000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "depth": 17,
    "max_think_time_ms": 100,
    "disregard_think_time": false
  }'
```

### Example response

```json
{
  "ok": true,
  "request_id": "7eec88d7-43da-4a7f-b5cb-6ed7cc2fd677",
  "best_move": "e2e4",
  "ponder": "e7e5",
  "depth": 17,
  "time_taken_ms": 96,
  "difficulty": {
    "score": 0.42,
    "label": "medium",
    "recommended_delay_ms": 927,
    "reason": "the top candidate moves were close in evaluation; several candidate moves were still reasonable",
    "legal_move_count": 20,
    "in_check": false,
    "candidate_moves": 3,
    "best_second_gap_cp": 42
  },
  "lines": [
    {
      "rank": 1,
      "depth": 17,
      "move_uci": "e2e4",
      "score_cp": 32,
      "mate": null,
      "pv": ["e2e4", "e7e5", "g1f3"]
    }
  ],
  "engine": {
    "name": "Stockfish 18",
    "status": "ready"
  }
}
```

---

## `POST /analyze/cancel`

Requests cancellation of the current engine analysis.

### Purpose

Use this when the Roblox client has moved to a newer position and the current analysis is no longer useful.

### Request

No body.

### Response

```ts
interface GenericOkResponse {
  ok: boolean;
  message: string;
}
```

### Example response

```json
{
  "ok": true,
  "message": "Cancellation requested. The running analysis will stop at the next UCI checkpoint."
}
```

---

## `GET /history`

Returns recent analysis attempts.

### Purpose

Useful for the desktop UI output tab, debugging, and lightweight diagnostics. Roblox usually does not need this endpoint.

### Request

No body.

### Response

```ts
type HistoryResponse = HistoryItem[];

interface HistoryItem {
  id: string;
  timestamp: string;
  fen: string;
  best_move: string | null;
  difficulty: Difficulty | null;
  time_taken_ms: number | null;
  status: string;
  error: string | null;
}
```

### Example response

```json
[
  {
    "id": "7eec88d7-43da-4a7f-b5cb-6ed7cc2fd677",
    "timestamp": "2026-04-30T11:20:45.100Z",
    "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "best_move": "e2e4",
    "difficulty": {
      "score": 0.42,
      "label": "medium",
      "recommended_delay_ms": 927,
      "reason": "the top candidate moves were close in evaluation",
      "legal_move_count": 20,
      "in_check": false,
      "candidate_moves": 3,
      "best_second_gap_cp": 42
    },
    "time_taken_ms": 96,
    "status": "ok",
    "error": null
  }
]
```

---

## `GET /settings`

Returns the current app configuration.

### Purpose

Used by the desktop UI or advanced tools to inspect current engine/server/analysis settings.

### Request

No body.

### Response

```ts
interface AppConfig {
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
    timing_preset: 'quick' | 'balanced' | 'careful' | 'very_careful';
  };
}
```

---

## `PUT /settings`

Updates app configuration.

### Purpose

Used by the desktop UI to save settings. The Roblox client should normally not call this.

### Request body

```ts
interface UpdateSettingsRequest {
  config: AppConfig;
  restart_engine?: boolean;
}
```

### Notes

- If `restart_engine` is true, the backend attempts to restart/apply the engine after saving.
- Settings validation happens in Rust before saving/applying.
- If the server host/port changes, it may require a full app restart depending on how the local API is currently started.

### Example request

```json
{
  "config": {
    "server": {
      "host": "127.0.0.1",
      "port": 3000
    },
    "engine": {
      "stockfish_path": "C:\\stockfish\\stockfish.exe",
      "hash_mb": 512,
      "threads": 4,
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
  "restart_engine": true
}
```

### Response

```json
{
  "ok": true,
  "message": "Settings saved."
}
```

---

## `POST /engine/restart`

Restarts the configured chess engine.

### Purpose

Used after changing engine-related settings or recovering from an engine error.

### Request

No body.

### Response

```json
{
  "ok": true,
  "message": "Engine restarted."
}
```

---

## `POST /engine/detect`

Attempts to detect an existing Stockfish executable.

### Purpose

Used by setup flows. It checks known app install locations and common system locations.

### Request

No body.

### Response

```ts
interface DetectStockfishResponse {
  ok: boolean;
  path: string | null;
  message: string;
}
```

### Example success

```json
{
  "ok": true,
  "path": "C:\\stockfish\\stockfish.exe",
  "message": "Detected Stockfish at C:\\stockfish\\stockfish.exe"
}
```

### Example no match

```json
{
  "ok": false,
  "path": null,
  "message": "No Stockfish executable was detected."
}
```

---

## `POST /engine/choose`

Opens the native file picker on the local machine and lets the user choose the Stockfish executable.

### Purpose

Used by the desktop setup UI. This endpoint is not recommended for Roblox because it is interactive and opens a local dialog.

### Request

No body.

### Response

```ts
interface DetectStockfishResponse {
  ok: boolean;
  path: string | null;
  message: string;
}
```

### Example success

```json
{
  "ok": true,
  "path": "C:\\Users\\user\\Downloads\\stockfish.exe",
  "message": "Stockfish path saved and engine restarted."
}
```

### Example cancelled

```json
{
  "ok": false,
  "path": null,
  "message": "No file was chosen."
}
```

---

## `POST /engine/download`

Downloads, installs, saves, and starts the latest supported Stockfish build.

### Purpose

Used by the setup wizard. This is the easiest path for non-technical users.

### Request

No body.

### Response

```ts
interface DetectStockfishResponse {
  ok: boolean;
  path: string | null;
  message: string;
}
```

### Example success

```json
{
  "ok": true,
  "path": "C:\\Users\\user\\AppData\\Roaming\\local\\roblox-chess-script\\data\\engines\\stockfish\\stockfish.exe",
  "message": "Stockfish downloaded, saved, and started."
}
```

---

# Type definitions

## `AppConfig`

```ts
interface AppConfig {
  server: ServerConfig;
  engine: EngineConfig;
  analysis: AnalysisConfig;
}

interface ServerConfig {
  host: string;
  port: number;
}

interface EngineConfig {
  stockfish_path: string | null;
  hash_mb: number;
  threads: number;
  syzygy_paths: string[];
  multipv: number;
  auto_restart: boolean;
}

interface AnalysisConfig {
  difficulty_enabled: boolean;
  candidate_threshold_cp: number;
  cancel_previous_on_new_request: boolean;
  min_delay_ms: number;
  max_delay_ms: number;
  timing_preset: 'quick' | 'balanced' | 'careful' | 'very_careful';
}
```
