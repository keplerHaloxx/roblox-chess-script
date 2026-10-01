# Native Luau client

A strictly typed Luau client using the stable [Rayfield Gen2 API](https://docs.sirius.menu/rayfield-gen2). It builds without roblox-ts.

## Run

1. Start the desktop server and configure Stockfish.
2. Join CHESS, place `6222531507`.
3. Unload the previous script before switching to this build for the first time.
4. Execute `dist/main.lua`, then use **Check connection** and **Suggest move**.

The client uses `http://127.0.0.1:57250/api/v1`. Required executor features are `getgenv()`, HTTP requests, registry/upvalue inspection, and `loadstring`. The UI loads from `https://sirius.menu/gen2`. Teleport queue support is optional.

## Structure

- `src/main.client.luau`: startup, dependency wiring, lifecycle, and polling.
- `src/UI/Controls.luau`: typed Gen2 controls and callbacks.
- `src/UI/StatusView.luau`: status messages, persistent instructions, and expiry timers.
- `src/Modules/Controller.luau`: request ownership, cancellation, position validation, and automation.
- `src/Modules/Board.luau`: game discovery, board conversion, and the experimental promotion adapter.
- `src/Modules/ChessServer.luau` and `Protocol.luau`: HTTP transport and response validation.
- `src/Modules/Runtime.luau`: executor compatibility and the sole shared namespace, `getgenv().ChessClient`.
- `src/Modules/Settings.luau`: typed defaults.
- `src/Modules/Highlighter.luau`: owned board-square highlights, independent of piece skins.
- `src/Types/Chess.luau`: explicit game, request, result, settings, and lifecycle contracts.
- `src/Types/Rayfield.luau`: reusable stable Gen2 declarations, with documentation comments.

Unknown external JSON values are narrowed before use. `any` is restricted to arbitrary closure signatures at the executor registry boundary. No fallback global environment is used.

## Rayfield type library

The type module covers documented stable windows, tabs, groups, sections, all element constructors, handle methods, notifications, toasts, popups, tags, configuration, themes, and localization. It uses canonical camelCase property names; the runtime also accepts PascalCase aliases. Preview-only heartbeat and fallbackFont options are excluded. Dropdown and keybind options distinguish single/multiple and press/hold callbacks respectively. Dynamic flag values return `unknown` for callers to narrow.

```lua
local RayfieldTypes = require("./Types/Rayfield")
local options: RayfieldTypes.MultiDropdownProps = {
    name = "Features",
    multiSelect = true,
    options = { "Highlights", "Analysis" },
    callback = function(selected: {string})
        print(#selected)
    end,
}
```

`tests/types/Gen2.luau` demonstrates the other controls. Type modules contain no UI implementation. Editor analysis and the command-line checker use strict Luau mode.

## Controls and lifecycle

Play puts the current suggestion, manual actions, Stop & clear, and connection checks first. Auto Play groups automation and timing, with experimental features below. Engine contains search settings, Reconnect to board, and Close chess assistant. Appearance contains the theme and highlight colors. All four tabs sit at the top. Suggestions and errors stay visible until replaced or cleared; the connection card records the last manual check. New configurations start with the cobalt theme, while saved theme choices are preserved.

Cancel disables automatic calculation and invalidates pending moves. New executions replace the previous session in `getgenv().ChessClient`; unload removes owned highlights and stops polling. Late HTTP replies cannot unlock a newer request or execute against a changed position. Re-execution retains only the teleport-queued marker to avoid duplicate queue entries.

Settings persist in the separate Gen2 `chess-gen2` configuration. Gen1 settings are not imported. Game error reporting is not changed.

## Experimental promotion: live test checklist

The old client calls `clickOnTile(x, y)` first at the source, then the destination. We infer selection followed by submission. Its existing types describe `move.promote.pieceName`; they do not show the game's actual promotion handler.

With **Experimental promotion** enabled in Auto Play, this build temporarily wraps the pawn's `getMoves` function around those two clicks. Matching legal moves are cloned, and their existing `promote.pieceName` is set to the engine's choice. Original move tables are not modified. The wrapper is restored on success, cancellation, or click failure. This assumes the tile handler reads that metadata; it is not verified against the live game.

The toggle defaults off. Without it, promotion instructions remain visible for manual play. To test the experiment:

1. Use a match with another player, not a bot match (automatic execution is disabled against bots). Start with **Auto calculate** and **Auto execute move** off.
2. Get a white pawn onto rank 7 with a legal forward promotion to rank 8. Enable **Experimental promotion**, then use **Play best move** when analysis recommends that pawn move. Check the displayed UCI suffix: `q` means Queen, `r` Rook, `b` Bishop, `n` Knight.
3. Confirm the resulting piece matches that suffix, the pawn is gone, the opponent can move, and analysis still works on your following turn. **Promotion confirmed** means the adapter observed the requested piece on the destination square.
4. Repeat with a black pawn going from rank 2 to rank 1.
5. Test capture promotions for both colors: an enemy piece diagonally ahead on the final rank. Confirm the capture and promotion both occur.
6. If the engine recommends underpromotion, repeat for `n`, `r`, and `b`. Do not count a queen appearing as a successful underpromotion. The offline suite covers all choices, but normal play may rarely produce these recommendations.
7. Try **Suggest move** at a promotion position: it should never move the pawn. Disable the experiment and try auto execution: it should show manual instructions without clicking.
8. Cancel during a nonzero execute delay: no move should be sent. After that, run again and verify normal moves still work.
9. After successful manual tests, enable Auto Play and repeat a promotion. Test with skins enabled too; highlighting uses the board squares.
10. Execute the new script twice, then unload it. There should be one active session and no remaining owned highlights.

If metadata is absent, the client stops before clicking. If the requested piece is not observed within three seconds, or a different piece appears, Auto Play stops and leaves a persistent explanation. This timeout can also mean slow replication; inspect the board before retrying. A failed attempt does not automatically send another move.

For a failure report, capture the UCI move, your color, straight/capture promotion, whether the game's selector appeared, the actual piece (or stuck pawn), the displayed message, and whether the next turn still works. An already stuck pawn cannot be recovered by this client.

## Build and verify

From this directory:

```powershell
mise install
mise run typecheck
mise run bundle-dev
mise run bundle-prod
mise run test
```

`typecheck` uses pinned luau-lsp 1.70.1 and hash-verified Roblox definitions (downloaded into ignored `.tools` on first use), plus executor declarations in `types/executor.d.luau`. It checks source and Gen2 usage examples. Additional lint/format checks:

```powershell
selene src
stylua --check --syntax Luau src tests
```

`dist/main.dev.lua` is readable; `dist/main.lua` is optimized. Build both before running the Lune regression suite. Mock tests verify our behavior under the stated contracts, not the real game's promotion implementation.

## Remaining limitations

Castling rights and en-passant history are not available through the verified adapter contract, so FEN sends neither. Automatic execution is disabled in bot matches. Live executor behavior still requires testing.

Teleport/rejoin queues the existing GitHub latest-release URL. Local builds do not publish that asset: upload the new `dist/main.lua` before expecting teleports to load this version automatically.
