# Roblox Chess Script 2.0.0

## Client

- Replaced the TypeScript client with the native Luau client in `client/`. The project now builds with Darklua, without roblox-ts.
- Migrated to Rayfield Gen2 with documented types for its stable API and strict types throughout the client.
- Redesigned the interface with top tabs, tab symbols, grouped move actions, clearer connection checks, persistent suggestions and errors, and theme and highlight controls.
- Fixed position generation to use the game's active side instead of the player's color, addressing invalid FEN errors in reported check positions.
- Updated Auto Play request handling so a submitted move can release the busy state when the board changes, even if the game's tile-click handler keeps yielding. Added protection against stale responses and late callbacks affecting newer requests.
- Added clearer calculation, delay, selection, and move-submission status messages, with cancellation and retry handling.
- Added optional experimental promotion execution using the game's inferred move metadata. The option is off by default, and unconfirmed promotion stops automation with an explanation.
- Centralized session state in `getgenv().ChessClient`, with cleanup on reload and unload, and board-square highlighting independent of piece skins.

## Desktop server

- Moved Stockfish setup into its own navigation tab, so selecting or replacing an engine no longer blocks other menus.
- Clarified engine download, file selection, detection, settings, and troubleshooting actions.
- Improved setup feedback, connection checks, request history, error handling, and window controls.
- Kept status requests responsive during engine searches and strengthened cancellation of queued analysis.
- Preserved saved engine settings when a switch or restart fails, and prevented unconfigured analysis from leaving a stale job.
- Improved Stockfish executable selection during installation and recovery from engine failures.

## Downloads and upgrade

- `roblox-chess-script.exe`: Windows desktop server, built in release mode.
- `main.lua`: optimized client script. Keep this exact asset name so the existing loader and teleport queue find it.
- `main.dev.lua`: readable client bundle for debugging.
- `SHA256SUMS.txt`: SHA-256 checksums for the release files.

Start the server and configure Stockfish, then unload the previous client before executing the new script. Gen2 settings use a separate configuration; Gen1 settings are not imported. Local builds do not update the GitHub loader until the assets are uploaded to the latest release. The application version remains `2.0.0`.

## Known limitations and testing

Castling rights and en-passant history are not available through the verified game adapter, so those moves remain unsupported. Automatic move execution is disabled in bot matches. Promotion uses inferred behavior and still needs live-game testing; the full checklist is in `client/README.md`.

For Auto Play, test several consecutive turns without toggling either option, then test Stop & clear during a delay, reloading the script, and starting a new match. For promotion, test both colors, straight and capture promotions, the selected piece, and whether play continues on the next turn.

Validation for this build: strict Luau type checking, 29 client regression tests, 35 Rust tests, Svelte checking with zero errors or warnings, and a successful Windows release build. Client tests use mocked game contracts; live Roblox behavior has not been verified for this release.
