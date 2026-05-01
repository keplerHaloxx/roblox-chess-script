/* eslint-disable @typescript-eslint/no-explicit-any */

type Position = [number, number]

interface Move extends Position {
    promote?: {
        pieceName?: string
    }
}

interface ChessPiece {
    Name: string
    team: boolean
    position?: Position
    getMoves(): Move[]
}

type Team = "w" | "b"

interface Board {
    client: Map<string, any> | undefined

    refreshClient(): Map<string, any> | undefined
    getBoard(): Map<string, any> | undefined

    isGameInProgress(): boolean
    isBotMatch(): boolean
    getLocalTeam(): Team | undefined
    isPlayerTurn(): boolean
    willCauseDesync(): boolean

    getBoardPiece(position: Position): ChessPiece | undefined
    getWorkspacePiece(tileName: string): Instance | undefined

    createBoard(): any[] | undefined
    board2fen(): string | undefined

    hasLegalMove(piece: ChessPiece, targetPosition: Position): boolean
    autoMove(
        fromPosition: Position,
        toPosition: Position
    ): LuaTuple<[boolean, string]>
}

interface BoardConstructor {
    new (): Board

    Pieces: {
        Pawn: string
        Knight: string
        Bishop: string
        Rook: string
        Queen: string
        King: string
    }
}

declare const Board: BoardConstructor
export = Board
