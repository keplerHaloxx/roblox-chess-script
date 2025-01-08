# Roblox Chess Script

Get chess moves from Stockfish and display them in Roblox.

While the server can be used for various purposes, the script is specifically designed for [this game](https://www.roblox.com/games/6222531507/CHESS). No other game will be supported.

## How to Run

1. **Download Stockfish**

    - Get [_Stockfish_](https://stockfishchess.org/download/). The **Faster** version is recommended, but if the server doesn’t start, try the **More compatible** version.

2. **Download the Latest Release**

    - Download the latest release of the script from [_here_](https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/roblox-chess-script.exe).
    - **IMPORTANT**: If the file does not exist when going to the link, wait around 5 minutes and try again. This is because an update was recently made and the file is still being uploaded.

3. **Run the Application**

    - Launch the application and follow the instructions until it indicates that the server is running.

4. **Execute the Script in Roblox**

    - **IMPORTANT**: Same as step 2, if you get a 404 error in Roblox console (seen by pressing F9), wait around 5 minutes and try again. Also update the server because it may be updated too.
    - Use the following script:

    ```lua
    loadstring(game:HttpGet("https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"))()
    ```

<!-- ## Executor Compatibility

If you’d like your executor added to the compatibility list, please open an [issue](https://github.com/keplerHaloxx/roblox-chess-script/issues/new/choose).

| Executor | Status                  |
| -------- | ----------------------- |
| Wave     | ✅                      |
| Solara   | ⚠️ UI seems to not load |
| Others   | ❓                      |

**✅ Supported**: Fully functional and tested.

**⚠️ Not Fully Tested**: May work but has not been confirmed.

**❓ Unknown**: Compatibility is uncertain. -->

## Notes

-   The server is currently tested only on **Windows**.
-   If you encounter issues or would like to suggest a feature, please open an [issue](https://github.com/keplerHaloxx/roblox-chess-script/issues/new/choose). I’ll try to address them as soon as possible.
-   If you find this project useful, please consider starring the repository. ✨

## Credits

The communication with Stockfish's UCI protocol is based on the [uci](https://crates.io/crates/uci) crate, with slight modifications to work with this program.

## Disclaimer

This app is intended for educational purposes only. By using it, you agree to take full responsibility for any actions or decisions made based on the app’s content. The developers assume no liability for any outcomes resulting from its use.
