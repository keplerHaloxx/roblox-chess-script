import { HttpService, Workspace } from "@rbxts/services"
import Board from "@utils/LuaFuncs/board"
import getPosFromResult from "@utils/getPosFromResult"

const API_BASE_URL = "http://127.0.0.1:57250/api/v1"

interface HttpRequest {
    Url: string
    Method: string
    Body?: string
    Headers?: Record<string, string>
    Cookies?: Record<string, string>
}

interface HttpResponse {
    Body: string
    StatusCode: number
    StatusMessage: string
    Success: boolean
    Headers: Record<string, string>
}

declare function request(options: HttpRequest): HttpResponse

export interface Difficulty {
    score: number
    label: "trivial" | "easy" | "medium" | "hard" | "very_hard"
    recommended_delay_ms: number
    reason: string
    legal_move_count: number
    in_check: boolean
    candidate_moves: number
    best_second_gap_cp?: number
}

export interface AnalysisLine {
    rank: number
    depth?: number
    move_uci?: string
    score_cp?: number
    mate?: number
    pv: string[]
}

export interface AnalyzeEngineInfo {
    name?: string
    status: string
}

export interface AnalyzeSuccessResponse {
    ok: true
    request_id: string
    best_move: string
    ponder?: string
    depth: number
    time_taken_ms: number
    difficulty?: Difficulty
    lines: AnalysisLine[]
    engine: AnalyzeEngineInfo
}

export interface AnalyzeErrorResponse {
    ok: false
    error: {
        code: string
        message: string
    }
}

export type AnalyzeResponse = AnalyzeSuccessResponse | AnalyzeErrorResponse

export interface MoveSuccess extends AnalyzeSuccessResponse {
    success: true

    /**
     * Alias for `best_move`, kept for existing caller code.
     */
    move: string

    /** Workspace instance of the piece to move, for highlighting. */
    piece: Instance

    /** Workspace instance of the destination tile, for highlighting. */
    destination: Instance

    /** Board-space [x, y] of the piece. Passed directly to `board.autoMove`. */
    fromPos: [number, number]

    /** Board-space [x, y] of the destination. Passed directly to `board.autoMove`. */
    toPos: [number, number]
}

export interface MoveFailure {
    success: false
    reason: string
    code?: string
    statusCode?: number
    statusMessage?: string
    api?: AnalyzeErrorResponse
}

export type MoveResult = MoveSuccess | MoveFailure

/**
 * Validates the current game state, queries the local Stockfish server,
 * and returns the best move along with Workspace instances, board positions
 */
export default function findBestMove(
    board: Board,
    depth: number,
    maxThinkTime: number,
    disregardThinkTime: boolean
): MoveResult {
    const fail = (
        reason: string,
        code?: string,
        statusCode?: number,
        statusMessage?: string,
        api?: AnalyzeErrorResponse
    ): MoveFailure => ({
        success: false,
        reason,
        code,
        statusCode,
        statusMessage,
        api,
    })

    if (!board.isGameInProgress()) return fail("game not in progress")
    if (!board.isPlayerTurn()) return fail("not your turn")
    if (board.willCauseDesync()) return fail("will cause desync")

    const fen = board.board2fen()
    if (!fen) return fail("failed to create FEN string")

    const body = HttpService.JSONEncode({
        fen,
        depth,
        max_think_time_ms: maxThinkTime,
        disregard_think_time: disregardThinkTime,
    })

    let response: HttpResponse

    try {
        response = request({
            Url: `${API_BASE_URL}/analyze`,
            Method: "POST",
            Body: body,
            Headers: {
                "Content-Type": "application/json",
            },
        })
    } catch (err) {
        return fail(`server request failed: ${tostring(err)}`)
    }

    // Debug this while testing.
    print("HTTP Success:", response.Success)
    print("HTTP StatusCode:", response.StatusCode)
    print("HTTP StatusMessage:", response.StatusMessage)
    print("HTTP Body:", response.Body)

    const rawBody = response.Body

    if (!response.Success) {
        return fail(
            `server request failed: ${response.StatusCode} ${response.StatusMessage}${
                rawBody ? ` - ${rawBody}` : ""
            }`,
            undefined,
            response.StatusCode,
            response.StatusMessage
        )
    }

    if (rawBody === undefined || rawBody === "") {
        return fail(
            `server returned empty body: ${response.StatusCode} ${response.StatusMessage}`,
            undefined,
            response.StatusCode,
            response.StatusMessage
        )
    }

    let data: AnalyzeResponse

    try {
        data = HttpService.JSONDecode(rawBody) as AnalyzeResponse
    } catch (err) {
        return fail(
            `failed to decode server response: ${tostring(err)} - body: ${rawBody}`,
            undefined,
            response.StatusCode,
            response.StatusMessage
        )
    }

    if (!data.ok) {
        return fail(
            data.error.message,
            data.error.code,
            response.StatusCode,
            response.StatusMessage,
            data
        )
    }

    const move = data.best_move
    if (!move) return fail("server did not return a best move")

    const [x1, y1, x2, y2] = getPosFromResult(move)

    const boardPiece = board.getBoardPiece([x1, y1])
    if (!boardPiece) return fail("no board piece at source square")

    if (!board.hasLegalMove(boardPiece, [x2, y2])) {
        return fail("engine returned an illegal move")
    }

    const piece = board.getWorkspacePiece(tostring(`${x1},${y1}`))
    if (!piece) return fail("source piece not found in Workspace")

    const destination = Workspace.FindFirstChild("Board")?.FindFirstChild(
        tostring(`${x2},${y2}`)
    )

    if (!destination) return fail("destination tile not found in Workspace")

    return {
        success: true,
        ok: data.ok,
        request_id: data.request_id,
        best_move: data.best_move,
        ponder: data.ponder,
        depth: data.depth,
        time_taken_ms: data.time_taken_ms,
        difficulty: data.difficulty,
        lines: data.lines,
        engine: data.engine,
        move,
        piece,
        destination,
        fromPos: [x1, y1],
        toPos: [x2, y2],
    }
}
