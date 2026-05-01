import Rayfield from "@libs/Rayfield"
import CoreGui from "@utils/coreGui"
import findOrCreateInstance from "@utils/findOrCreateInstance"
import Board from "@utils/LuaFuncs/board"
import { Highlighter, HighlightOptions } from "@utils/highlighter"
import findBestMove from "@utils/findBestMove"
import { StarterGui } from "@rbxts/services"
import { ensure_executor_functions_access, queue_on_teleport } from "@libs/Unc"
import { $env } from "rbxts-transform-env"
import destroyErrorLogging from "@utils/destroyErrorLogging"
import { RayfieldThemes } from "@/libs/RayfieldSettings"
import Object from "@rbxts/object-utils"

// ── Constants ─────────────────────────────────────────────────────────────────
const CHESS_PLACE_ID = 6222531507
const SCRIPT_URL =
    "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"

const OUTPUT_CLEAR_DELAY = 5 // seconds before bot output is auto-cleared
const STATUS_CLEAR_DELAY = 5 // seconds before status resets to Idle after success

// ── Wrong-game guard ──────────────────────────────────────────────────────────
if (game.PlaceId !== CHESS_PLACE_ID) {
    const joinCallback = new Instance("BindableFunction")
    joinCallback.OnInvoke = () => {
        game.GetService("TeleportService").Teleport(CHESS_PLACE_ID)
    }

    StarterGui.SetCore("SendNotification", {
        Title: "Wrong Game",
        Text: "This script is not meant for this game. Press Join to go there.",
        Button1: "Join",
        Duration: 10,
        Callback: joinCallback,
    })
}

// ── Initialisation ────────────────────────────────────────────────────────────
Highlighter.destroyAll()
destroyErrorLogging()
findOrCreateInstance(CoreGui, "HighlightCache", "Folder")

const board = new Board()
let theme = RayfieldThemes.Default
let highlight_options = {
    FillColor: Color3.fromRGB(59, 235, 223),
    OutlineColor: Color3.fromRGB(255, 255, 255),
    FillTransparency: 0.5,
    OutlineTransparency: 0,
} satisfies HighlightOptions

// ── UI Window ─────────────────────────────────────────────────────────────────
const window = Rayfield.CreateWindow({
    Name: "Chess by Haloxx",
    Icon: "code-xml",
    LoadingTitle: "Chess ♟️",
    LoadingSubtitle: "By Haloxx",
    ScriptID: $env.string("RAYFIELD_SCRIPT_ID")!,
    DisableBuildWarnings: true,
    DisableRayfieldPrompts: true,
    ConfigurationSaving: {
        Enabled: true,
        FolderName: "keplerHaloxx-Chess",
        FileName: "chess-script-config",
    },
})

// ── Core logic ────────────────────────────────────────────────────────────────
function calculateBestMove(autoExecute: boolean): void {
    // Cancel any pending auto-clear so the previous result stays visible
    // while Stockfish is thinking. Output is only updated once we have a result.
    outputClearToken++
    setBotStatus("Calculating")

    const result = findBestMove(
        board,
        depthSlider.CurrentValue,
        thinkTimeSlider.CurrentValue,
        disregardTimeToggle.CurrentValue
    )

    task.spawn(() => {
        if (!result.success) {
            // Show the error and auto-reset status after a short delay.
            setBotOutput(result.reason)
            setBotStatus("Error!", 2.5)
            return
        }

        new Highlighter(result.piece, highlight_options)
        new Highlighter(result.destination, highlight_options)

        // Output auto-clears after OUTPUT_CLEAR_DELAY seconds unless a new
        // move is calculated first, which resets the timer via the token.
        setBotOutput(`Received: ${result.move}`)
        setBotStatus("Idle", STATUS_CLEAR_DELAY)

        if (autoExecute) {
            const delay = useCalculatedDelay.CurrentValue
                ? result.difficulty!.recommended_delay_ms
                : executeDelaySlider.CurrentValue
            if (delay > 0) task.wait(delay / 1000)

            const [moved, reason] = board.autoMove(result.fromPos, result.toPos)
            if (!moved) {
                setBotOutput(`autoMove failed: ${reason}`)
                setBotStatus("Error!", 2.5)
                return
            }
        }

        // Clear highlights and output once the player's turn ends.
        task.spawn(() => {
            while (board.isPlayerTurn()) task.wait()
            Highlighter.destroyAll()
        })
    })
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Tab
// ─────────────────────────────────────────────────────────────────────────────
const mainTab = window.CreateTab("Main", "cpu")

// ── Executor support notice ───────────────────────────────────────────────────
if (!ensure_executor_functions_access(queue_on_teleport)) {
    mainTab.CreateParagraph({
        Title: "queue_on_teleport() not supported",
        Content:
            "Your executor likely doesn't support this function. " +
            "You will need to re-execute the script manually after each rejoin.",
    })
} else {
    queue_on_teleport(`loadstring(game:HttpGet("${SCRIPT_URL}"))()`)
}

// ── Status ────────────────────────────────────────────────────────────────────
mainTab.CreateSection("Status")

const botStatusLabel = mainTab.CreateLabel("Status: Idle")
const botOutputParagraph = mainTab.CreateParagraph({
    Title: "Bot Output",
    Content: "",
})

let currentBotStatus = "Status: Idle"

// Cancel tokens: incrementing before scheduling a clear means any previously
// scheduled clear will see a stale token and bail out, acting as a cancellation.
let statusClearToken = 0
let outputClearToken = 0

function setBotStatus(status: string, autoClearDelay?: number): void {
    currentBotStatus = `Status: ${status}`
    botStatusLabel.Set(currentBotStatus)

    if (autoClearDelay !== undefined) {
        const token = statusClearToken++
        task.delay(autoClearDelay, () => {
            if (statusClearToken === token) {
                currentBotStatus = "Status: Idle"
                botStatusLabel.Set("Status: Idle")
            }
        })
    }
}

function setBotOutput(
    content: string,
    autoClearDelay = OUTPUT_CLEAR_DELAY
): void {
    botOutputParagraph.Set({ Title: "Bot Output", Content: content })

    const token = outputClearToken++
    task.delay(autoClearDelay, () => {
        if (outputClearToken === token)
            botOutputParagraph.Set({ Title: "Bot Output", Content: "" })
    })
}

function clearBotOutput(): void {
    outputClearToken++ // cancels any pending clear timer
    botOutputParagraph.Set({ Title: "Bot Output", Content: "" })
}

// ── Bot Options ───────────────────────────────────────────────────────────────
mainTab.CreateSection("Bot Options")

const depthSlider = mainTab.CreateSlider({
    Name: "Depth",
    Range: [10, 30],
    Increment: 1,
    Suffix: "moves",
    CurrentValue: 17,
    Flag: "Depth",
    Callback: () => {},
})

const thinkTimeSlider = mainTab.CreateSlider({
    Name: "Think Time",
    Range: [10, 5_000],
    CurrentValue: 100,
    Flag: "MaxThinkTime",
    Suffix: "ms",
    Increment: 10,
    Callback: () => {},
})

mainTab.CreateDivider() //-=========== DIVIDER

mainTab.CreateLabel(
    "When enabled, Stockfish won't stop thinking until it reaches the target depth."
)

const disregardTimeToggle = mainTab.CreateToggle({
    Name: "Disregard Think Time",
    CurrentValue: false,
    Flag: "DisregardThinkTime",
    Callback: () => {},
})

// ── Run section ───────────────────────────────────────────────────────────────
mainTab.CreateSection("Run")

mainTab.CreateButton({
    Name: "Run (Highlight Only)",
    Callback: () => calculateBestMove(false),
})

mainTab.CreateButton({
    Name: "Run (Auto Execute)",
    Callback: () => calculateBestMove(true),
})

// ─────────────────────────────────────────────────────────────────────────────
// Auto Play Tab
// ─────────────────────────────────────────────────────────────────────────────
const autoPlayTab = window.CreateTab("Auto Play", "bot")

autoPlayTab.CreateSection("Status")

const autoPlayStatusLabel = autoPlayTab.CreateLabel("Auto Play: Inactive")

autoPlayTab.CreateSection("Automation")

const autoCalculateToggle = autoPlayTab.CreateToggle({
    Name: "Auto Calculate",
    Flag: "AutoCalculate",
    CurrentValue: false,
    Callback: () => {},
})

autoPlayTab.CreateParagraph({
    Title: "Auto Execute",
    Content:
        "When enabled, the bot will automatically click the tiles to perform the move. " +
        "Disabled in bot matches.",
})

const autoExecuteToggle = autoPlayTab.CreateToggle({
    Name: "Auto Execute Move",
    Flag: "AutoExecute",
    CurrentValue: false,
    Callback: () => {},
})

autoPlayTab.CreateSection("Timing")

autoPlayTab.CreateLabel(
    "Delay before the move is executed. A small delay looks more natural."
)

const executeDelaySlider = autoPlayTab.CreateSlider({
    Name: "Execute Delay",
    Range: [0, 3_000],
    Increment: 50,
    Suffix: "ms",
    CurrentValue: 300,
    Flag: "ExecuteDelay",
    Callback: () => {},
})

autoPlayTab.CreateDivider() //-=========== DIVIDER

autoPlayTab.CreateLabel(
    'On: Uses a delay auto calculated from how "hard" a move is (not 100% reliable)'
)
autoPlayTab.CreateLabel("Off: Uses manually set delay")

const useCalculatedDelay = autoPlayTab.CreateToggle({
    Name: "Use Calculated Delay",
    CurrentValue: false,
    Flag: "UseCalculatedDelay",
    Callback: () => {},
})

// ─────────────────────────────────────────────────────────────────────────────
// Skins Tab
// ─────────────────────────────────────────────────────────────────────────────
// const skinsTab = window.CreateTab("Skins", "brush")

// const skins = getSkins()

// skinsTab.CreateSection("Set Skin")

// skinsTab.CreateDropdown({
//     Name: "Set White Skin",
//     Options: skins.whiteSkins,
//     CurrentOption: ["BasicWhite"],
//     MultipleOptions: false,
//     Flag: "WhiteSkinsDropdown",
//     Callback: (options: string[]) => {
//         const remote = ReplicatedStorage.FindFirstChild(
//             "Connections"
//         )!.FindFirstChild("SelectSkin")! as RemoteEvent
//         remote.FireServer(options[0])
//     },
// })

// skinsTab.CreateDropdown({
//     Name: "Set Black Skin",
//     Options: skins.blackSkins,
//     CurrentOption: ["BasicBlck"],
//     MultipleOptions: false,
//     Flag: "BlackSkinsDropdown",
//     Callback: (options: string[]) => {
//         const remote = ReplicatedStorage.FindFirstChild(
//             "Connections"
//         )!.FindFirstChild("SelectSkin")! as RemoteEvent
//         remote.FireServer(options[0])
//     },
// })

// ─────────────────────────────────────────────────────────────────────────────
// Theme Tab
// ─────────────────────────────────────────────────────────────────────────────
const themesTab = window.CreateTab("Theme", "palette")
themesTab.CreateSection("Highlighter Options")

themesTab.CreateColorPicker({
    Name: "Highlight Fill Color",
    Color: highlight_options.FillColor,
    Flag: "HighlightFillColor",
    Callback: (color: Color3) => {
        highlight_options.FillColor = color
    },
})

themesTab.CreateColorPicker({
    Name: "Highlight Outline Color",
    Color: highlight_options.OutlineColor,
    Flag: "HighlightOutlintColor",
    Callback: (color: Color3) => {
        highlight_options.OutlineColor = color
    },
})

themesTab.CreateSection("Rayfield Options")
themesTab.CreateDropdown({
    Name: "Theme",
    Options: Object.values(RayfieldThemes),
    CurrentOption: [RayfieldThemes.Default],
    MultipleOptions: false,
    Flag: "RayfieldThemeDropdown",
    Callback: (options: string[]) => {
        window.ModifyTheme(options[0]! as RayfieldThemes)
    },
})

// ─────────────────────────────────────────────────────────────────────────────
Rayfield.LoadConfiguration()

// Watches for the player's turn and fires the bot automatically.
task.spawn(() => {
    while (true) {
        const isActive =
            autoCalculateToggle.CurrentValue &&
            board.isGameInProgress() &&
            board.isPlayerTurn()

        if (isActive) {
            autoPlayStatusLabel.Set("Auto Play: Running")
            calculateBestMove(autoExecuteToggle.CurrentValue)

            while (board.isPlayerTurn()) task.wait() // wait for our move to land
            autoPlayStatusLabel.Set("Auto Play: Waiting for turn")
            while (!board.isPlayerTurn()) task.wait() // wait for opponent to finish
        } else {
            if (!autoCalculateToggle.CurrentValue)
                autoPlayStatusLabel.Set("Auto Play: Inactive")

            task.wait()
        }
    }
})
