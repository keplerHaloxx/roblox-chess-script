import { HttpService, Workspace } from "@rbxts/services"
import HttpGet from "./HttpGet"
import Board from "./LuaFuncs/board"
import getPosFromResult from "./getPosFromResult"

interface MoveJsonData {
    success: boolean
    result: string
}

/**
 * Does a ton of checks and gets the best move
 */
export = (
    board: Board,
    depth: number,
    maxThinkTime: number,
    disregardThinkTime: boolean
): [boolean, string, Instance?, Instance?] => {
    if (!board.isPlayerTurn()) return [false, "not your turn"]

    if (board.willCauseDesync()[1] !== undefined) {
        // has errored :(
        return [false, "will cause desync"]
    }

    const ret = HttpGet(
        "http://127.0.0.1:3000/api/solve?fen=" + // localhost is the same as this but Wave flags it as dangerous
            HttpService.UrlEncode(board.board2fen()!) +
            `&depth=${depth}` +
            `&max_think_time=${maxThinkTime}` +
            `&disregard_think_time=${disregardThinkTime}`
    )
    // eslint-disable-next-line roblox-ts/lua-truthiness
    if (!ret) {
        return [false, "no response from server"]
    }
    const data = HttpService.JSONDecode(ret) as MoveJsonData

    if (!data.success) {
        return [false, data.result]
    }

    const [x1, y1, x2, y2] = getPosFromResult(data.result)

    const pieceToMove = Board.getPiece(tostring(x1 + "," + y1))
    if (!pieceToMove) {
        return [false, "no piece to move"]
    }

    const placeToMove = Workspace.FindFirstChild("Board")?.FindFirstChild(
        tostring(x2 + "," + y2)
    )
    if (!placeToMove) {
        return [false, "no place to move to"]
    }

    return [true, data.result, pieceToMove, placeToMove]
}
