/* eslint-disable @typescript-eslint/no-explicit-any */
interface Board {
    getBoard(): Map<string, any> | undefined
    isBotMatch(): boolean
    willCauseDesync(): LuaTuple<[boolean]>
    createBoard(): any[] | undefined
    board2fen(): string | undefined
    isPlayerTurn(): boolean
}

interface BoardConstructor {
    new (): Board
    getClient: () => Map<string, any>
    getPiece: (tile: string) => Instance | undefined
    gameInProgress: () => boolean
    pieces: {
        ["Pawn"]: string
        ["Knight"]: string
        ["Bishop"]: string
        ["Rook"]: string
        ["Queen"]: string
        ["King"]: string
    }
}

declare const Board: BoardConstructor
export = Board
