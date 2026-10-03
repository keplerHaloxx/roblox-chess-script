--!strict
--- Domain contracts. Game internals are inferred from the existing adapter, not an official API.
export type Position = { number }
export type Team = "w" | "b"
export type Promotion = "q" | "r" | "b" | "n"
export type PieceName = "Pawn" | "Knight" | "Bishop" | "Rook" | "Queen" | "King"
export type PromotionMetadata = { pieceName: string? }
export type GameMove = { [number]: number, promote: PromotionMetadata?, enpassant: unknown? }
export type Piece = {
	Name: string,
	team: boolean,
	position: Position?,
	getMoves: (self: Piece) -> { GameMove },
	unmoved: boolean?,
}
export type Match = {
	whitePieces: { Piece }?,
	blackPieces: { Piece }?,
	players: { [boolean]: Player }?,
	activeTeam: boolean,
	tiles: unknown,
	boardExists: boolean?,
	botInfo: { team: boolean }?,
}
export type GameClient = {
	currentMatch: Match?,
	processRound: (...unknown) -> (),
	--- Inferred: first call selects a piece; second call attempts a destination.
	clickOnTile: ((self: GameClient, x: number, y: number) -> ())?,
}
export type BoardMap = { [number]: { [number]: string } }
export type Board = {
	lastDiscoveryAt: number?,
	client: GameClient?,
	refreshClient: (self: Board) -> GameClient?,
	getBoard: (self: Board) -> Match?,
	isGameInProgress: (self: Board) -> boolean,
	isBotMatch: (self: Board) -> boolean,
	getLocalTeam: (self: Board) -> Team?,
	isPlayerTurn: (self: Board) -> boolean,
	willCauseDesync: (self: Board) -> boolean,
	getBoardPiece: (self: Board, position: Position) -> Piece?,
	createBoard: (self: Board) -> BoardMap?,
	board2fen: (self: Board) -> string?,
	hasLegalMove: (self: Board, piece: Piece, targetPosition: Position) -> boolean,
	autoMove: (
		self: Board,
		fromPosition: Position,
		toPosition: Position,
		promotion: Promotion?,
		stillCurrent: (() -> boolean)?,
		isCancelled: (() -> boolean)?,
		onDestinationClick: (() -> ())?
	) -> (boolean, string),
}
export type Settings = {
	depth: number,
	thinkTime: number,
	disregardTime: boolean,
	autoCalculate: boolean,
	autoExecute: boolean,
	executeDelay: number,
	useCalculatedDelay: boolean,
	fillColor: Color3,
	outlineColor: Color3,
	fillTransparency: number,
	outlineTransparency: number,
}
export type HttpRequest = { Url: string, Method: string, Headers: { [string]: string }, Body: string? }
export type HttpResponse = { Body: string, StatusCode: number?, Success: boolean? }
export type Request = (HttpRequest) -> unknown
export type AnalysisRequest = { fen: string, depth: number, max_think_time_ms: number, disregard_think_time: boolean }
export type Difficulty = { recommended_delay_ms: number? }
export type ParsedMove = { fromPos: Position, toPos: Position, promotion: Promotion? }
export type MoveSuccess = {
	success: true,
	best_move: string,
	move: string,
	piece: Instance,
	destination: Instance,
	fromPos: Position,
	toPos: Position,
	promotion: Promotion?,
	fen: string,
	match: Match,
	difficulty: Difficulty?,
}
export type MoveFailure = { success: false, reason: string, code: string? }
export type MoveResult = MoveSuccess | MoveFailure
export type Server = {
	request: Request?,
	onIncompatible: ((string) -> ())?,
	call: (self: Server, path: string, payload: AnalysisRequest?) -> ({ [string]: unknown }?, string?, string?),
	findBestMove: (self: Server, board: Board, settings: Settings) -> MoveResult,
}
export type Highlighter = {
	folder: Folder,
	clear: (self: Highlighter) -> (),
	show: (self: Highlighter, source: Instance, destination: Instance, settings: Settings) -> (),
	destroy: (self: Highlighter) -> (),
}
export type MessageKind = "status" | "output" | "instruction" | "auto"
export type Reporter = (kind: MessageKind, message: string) -> ()
export type Session = { stopped: boolean, cleanup: () -> () }
export type RuntimeState = { session: Session?, teleportQueued: boolean }
export type Environment = { ChessClient: RuntimeState? }
return {}
