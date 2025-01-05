import Rayfield from "libs/Rayfield"
import CoreGui from "utils/CoreGui"
import findOrCreateFolder from "utils/findOrCreateFolder"
import destroyErrorLogging from "utils/destoryErrorLogging"
import Board from "utils/LuaFuncs/board"
import { Highlighter } from "utils/Highlighter"
import findBestMove from "utils/findBestMove"
import { StarterGui } from "@rbxts/services"
import { ensure_executor_functions_access, queue_on_teleport } from "libs/Unc"

const notiBindableFunc = new Instance("BindableFunction")
notiBindableFunc.OnInvoke = (buttonName: string) => {
    if (buttonName === "Join")
        game.GetService("TeleportService").Teleport(6222531507)
}

if (game.PlaceId !== 6222531507) {
    StarterGui.SetCore("SendNotification", {
        Title: "Wrong Game",
        Text: "This script is not meant for this game, press the Join button to join it",
        Button1: "Join",
        Duration: 10,
        Callback: notiBindableFunc,
    })
}

// init
Highlighter.destroyAll() // clear all old highlights
destroyErrorLogging() // this remote reports client errors (we don't want that)
findOrCreateFolder(CoreGui, "HighlightCache", "Folder") // create highlight cache

const window = Rayfield.CreateWindow({
    Name: "Chess",
    LoadingTitle: "Chess ♟️",
    LoadingSubtitle: "By Haloxx",

    DisableBuildWarnings: false,
    DisableRayfieldPrompts: false,

    ConfigurationSaving: {
        Enabled: true,
        FolderName: "keplerHaloxx-Chess",
        FileName: "chess-script-config",
    },
})

const board = new Board()

function bestMove() {
    setBotStatus("Calculating")

    const output = findBestMove(
        board,
        depthSlider.CurrentValue,
        thinkTimeSlider.CurrentValue
    )

    task.spawn(() => {
        if (output[0] === false) {
            // has errored
            setBotStatus("Error!")
            task.spawn(() => {
                task.wait(2.5)
                if (botStatus === "Status: Error!") setBotStatus("Idle")
            })
            setBotOutputContent(output[1])
            return
        }

        new Highlighter(output[2]!) // piece
        new Highlighter(output[3]!) // place

        setBotOutputContent(`Received: ${output[1]}`)

        // spawn a new thread to destory all pieces once it's no longer the players turn
        task.spawn(() => {
            while (board.isPlayerTurn()) {
                task.wait()
            }
            Highlighter.destroyAll()
        })

        setBotStatus("Idle")
    })
}

const mainTab = window.CreateTab("Main")

if (!ensure_executor_functions_access(queue_on_teleport))
    mainTab.CreateParagraph({
        Title: "Your executor probably doesn't support queue_on_teleport()",
        Content: `Do not worry that is OKAY but you will have to manually re-execute the script on rejoin.`,
    })
else
    queue_on_teleport(
        `loadstring(game:HttpGet("https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"))()`
    )

mainTab.CreateSection("Status")

let botStatus = ""
const botStatusLabel = mainTab.CreateLabel("Status: Idle")
const setBotStatus = (status: string): string => {
    const stat = `Status: ${status}`
    botStatus = stat
    botStatusLabel.Set(stat)
    return stat
}
setBotStatus("Idle")

const botOutput = mainTab.CreateParagraph({
    Title: "Bot Output",
    Content: "",
})
const setBotOutputContent = (content: string) =>
    botOutput.Set({ Title: "Bot Output", Content: content })

mainTab.CreateSection("Run")

mainTab.CreateButton({
    Name: "Run",
    Callback: bestMove,
})

const autoCalculateToggle = mainTab.CreateToggle({
    Name: "Auto Calculate",
    Flag: "AutoCalculate",
    CurrentValue: false,
    Callback: () => {},
})

task.spawn(() => {
    // keep waiting until the toggle is on
    while (true) {
        if (
            autoCalculateToggle.CurrentValue &&
            Board.gameInProgress() &&
            board.isPlayerTurn()
        ) {
            bestMove()
            while (board.isPlayerTurn()) task.wait()
            while (!board.isPlayerTurn()) task.wait()
        } else {
            task.wait()
        }
    }
})

mainTab.CreateSection("Bot Options")

// mainTab.CreateLabel("How many moves Stockfish thinks ahead")
const depthSlider = mainTab.CreateSlider({
    Name: "Depth",
    Range: [10, 30],
    Increment: 1,
    Suffix: "moves",
    CurrentValue: 17,
    Flag: "Depth",
    Callback: () => {},
})

// mainTab.CreateSection("")

// mainTab.CreateLabel("Maximum amount of time Stockfish has to think")
const thinkTimeSlider = mainTab.CreateSlider({
    Name: "Max Think Time",
    Range: [100, 5_000],
    CurrentValue: 100,
    Flag: "MaxThinkTime",
    Suffix: "ms",
    Increment: 10,
    Callback: () => {},
})

Rayfield.LoadConfiguration()
