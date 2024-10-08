import { HttpService, Workspace } from "@rbxts/services"
import HttpGet from "./HttpGet"
import Board from "./LuaFuncs/board"
import rprint from "./rprint"
import { Highlighter } from "./Highlighter"
import getPosFromResult from "./getPosFromResult"

interface MoveJsonData {
    success: boolean
    result: string
}

/**
 * Does a ton of checks and gets the best move
 */
export = (board: Board): [boolean, string, Instance?, Instance?] => {
    if (!board.isPlayerTurn()) return [false, "not your turn"]

    if (board.willCauseDesync()[1] !== undefined) {
        // has errored :(
        return [false, "will cause desync"]
    }

    const ret = HttpGet(
        "http://localhost:3000/api/solve?fen=" +
            HttpService.UrlEncode(board.board2fen()!)
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
