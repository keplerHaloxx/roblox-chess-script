import Rayfield from "libs/Rayfield"
import CoreGui from "utils/CoreGui"
import findOrCreateFolder from "utils/findOrCreateFolder"
import destoryErrorLogging from "utils/destoryErrorLogging"
import Board from "utils/LuaFuncs/board"
import { Highlighter } from "utils/Highlighter"
import findBestMove from "utils/findBestMove"
import { StarterGui } from "@rbxts/services"

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
Highlighter.destoryAll() // clear all old highlights
destoryErrorLogging() // this remote reports client errors (we don't want that)
findOrCreateFolder(CoreGui, "HighlightCache", "Folder") // create highlight cache

const window = Rayfield.CreateWindow({
    Name: "Chess",
    LoadingTitle: "Loading 🔃",
    LoadingSubtitle: "By Haloxx",
})

const board = new Board()

function bestMove() {
    setBotStatus("Calculating")

    const output = findBestMove(board)

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
        Highlighter.destoryAll()
    })

    setBotStatus("Idle")
}

const mainTab = window.CreateTab("Main")

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

const runButton = mainTab.CreateButton({
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
    while (typeOf(task.wait(0.5)) === "number") {
        // keep waiting until the toggle is on
        if (autoCalculateToggle.CurrentValue) {
            if (Board.gameInProgress() && board.isPlayerTurn()) {
                bestMove()
                while (board.isPlayerTurn()) task.wait(0.2)
                while (!board.isPlayerTurn()) task.wait(0.2)
            }
        }
    }
})
