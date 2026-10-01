--!strict
local Types = require("../Types/Chess")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
-- Registry entries can contain arbitrary closures; enumerating their signatures is not useful.
type ExecutorDebug = { getregistry: (() -> { unknown })?, getupvalues: (((...any) -> ...any) -> { unknown })? }
local executorDebug = (debug :: unknown) :: ExecutorDebug

local Board = {}

Board.Pieces = {
	Pawn = "p",
	Knight = "n",
	Bishop = "b",
	Rook = "r",
	Queen = "q",
	King = "k",
}

local function samePosition(a: Types.Position?, b: Types.Position?): boolean
	return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2]
end

local function getPieceAtPosition(board: Types.Match, position: Types.Position): Types.Piece?
	for _, piece in pairs(board.whitePieces or {}) do
		if piece.position and samePosition(piece.position, position) then
			return piece
		end
	end

	for _, piece in pairs(board.blackPieces or {}) do
		if piece.position and samePosition(piece.position, position) then
			return piece
		end
	end

	return nil
end

local function findClient(): Types.GameClient?
	local registry = getreg or (debug and executorDebug.getregistry)
	if type(registry) ~= "function" or type(executorDebug.getupvalues) ~= "function" then
		return nil
	end
	local ok, entries = pcall(registry)
	if not ok or type(entries) ~= "table" then
		return nil
	end
	for _, fn in pairs(entries) do
		if type(fn) == "function" and (not iscclosure or not iscclosure(fn)) then
			local readable, values =
				pcall(assert(executorDebug.getupvalues, "Executor upvalue inspection is unavailable"), fn)
			for _, upvalue in pairs(if readable and type(values) == "table" then values else {}) do
				if type(upvalue) == "table" and type(upvalue.processRound) == "function" then
					return upvalue :: Types.GameClient
				end
			end
		end
	end

	return nil
end

function Board.new(): Types.Board
	return {
		client = findClient(),
		refreshClient = Board.refreshClient,
		getBoard = Board.getBoard,
		isGameInProgress = Board.isGameInProgress,
		isBotMatch = Board.isBotMatch,
		getLocalTeam = Board.getLocalTeam,
		isPlayerTurn = Board.isPlayerTurn,
		willCauseDesync = Board.willCauseDesync,
		getBoardPiece = Board.getBoardPiece,
		createBoard = Board.createBoard,
		board2fen = Board.board2fen,
		hasLegalMove = Board.hasLegalMove,
		autoMove = Board.autoMove,
	}
end

function Board.refreshClient(self: Types.Board): Types.GameClient?
	self.client = findClient()
	return self.client
end

function Board.getBoard(self: Types.Board): Types.Match?
	if self.client and self.client.currentMatch then
		return self.client.currentMatch
	end

	if not (self.client and self.client.processRound) then
		return nil
	end

	local getUpvalues = executorDebug.getupvalues
	if not getUpvalues then
		return nil
	end
	local ok, values = pcall(getUpvalues, self.client.processRound)
	for _, upvalue in pairs(if ok and type(values) == "table" then values else {}) do
		if type(upvalue) == "table" and upvalue.tiles and upvalue.boardExists then
			return upvalue :: Types.Match
		end
	end

	return nil
end

function Board.isGameInProgress(_self: Types.Board): boolean
	local boardFolder = Workspace:FindFirstChild("Board")
	return boardFolder ~= nil and #boardFolder:GetChildren() > 0
end

function Board.isBotMatch(self: Types.Board): boolean
	local board = self:getBoard()

	return board ~= nil
		and board.players ~= nil
		and board.players[true] == LocalPlayer
		and board.players[false] == LocalPlayer
end

function Board.getLocalTeam(self: Types.Board): Types.Team?
	local board = self:getBoard()
	if not board then
		return nil
	end

	if self:isBotMatch() then
		return "w"
	end

	local players: { [boolean]: Player } = board.players or {}
	for team, player in pairs(players) do
		if player == LocalPlayer then
			return if team then "w" else "b"
		end
	end

	return nil
end

function Board.isPlayerTurn(self: Types.Board): boolean
	local team = self:getLocalTeam()
	local match = self:getBoard()
	if not team or not match or type(match.activeTeam) ~= "boolean" then
		return false
	end
	-- Use the same authoritative turn as FEN. The GUI may lag, disappear,
	-- or change visibility between moves and must not stall the next turn.
	return match.activeTeam == (team == "w")
end

function Board.willCauseDesync(self: Types.Board): boolean
	local board = self:getBoard()
	if not board then
		return true
	end

	local team = self:getLocalTeam()
	return team == nil or type(board.activeTeam) ~= "boolean" or board.activeTeam ~= (team == "w")
end

function Board.getBoardPiece(self: Types.Board, position: Types.Position): Types.Piece?
	local board = self:getBoard()
	if not board then
		return nil
	end

	return getPieceAtPosition(board, position)
end

function Board.createBoard(self: Types.Board): Types.BoardMap?
	local board = self:getBoard()
	if not board then
		return nil
	end

	local boardMap: Types.BoardMap = {}

	local function placePiece(piece: Types.Piece, isWhite: boolean): ()
		if not (piece and piece.position and piece.Name) then
			return
		end

		local x, y = piece.position[1], piece.position[2]
		local symbols: { [string]: string } = Board.Pieces
		local symbol = symbols[piece.Name]

		if not symbol then
			return
		end

		boardMap[x] = boardMap[x] or {}
		boardMap[x][y] = isWhite and string.upper(symbol) or symbol
	end

	for _, piece in pairs(board.whitePieces or {}) do
		placePiece(piece, true)
	end

	for _, piece in pairs(board.blackPieces or {}) do
		placePiece(piece, false)
	end

	return boardMap
end

function Board.board2fen(self: Types.Board): string?
	local match = self:getBoard()
	if not match or type(match.activeTeam) ~= "boolean" then
		return nil
	end
	local boardMap = self:createBoard()
	if not boardMap then
		return nil
	end

	local result = {}

	for y = 8, 1, -1 do
		local empty = 0
		local row = {}

		for x = 8, 1, -1 do
			local piece = boardMap[x] and boardMap[x][y]

			if piece then
				if empty > 0 then
					table.insert(row, tostring(empty))
					empty = 0
				end

				table.insert(row, piece)
			else
				empty += 1
			end
		end

		if empty > 0 then
			table.insert(row, tostring(empty))
		end

		table.insert(result, table.concat(row))
	end

	-- FEN describes the match, not the viewer's color. In bot games the local
	-- player owns both seats, so deriving this from players always chose White.
	local team = if match.activeTeam then "w" else "b"
	-- The game adapter exposes placement and turn but no verified castling/en-passant history.
	-- Preserve the TypeScript client's conservative treatment of those rights.
	return table.concat(result, "/") .. " " .. team .. " - - 0 1"
end

function Board.hasLegalMove(_self: Types.Board, piece: Types.Piece, targetPosition: Types.Position): boolean
	if not (piece and piece.getMoves) then
		return false
	end

	for _, move in pairs(piece:getMoves()) do
		if samePosition(move, targetPosition) then
			return true
		end
	end

	return false
end

function Board.autoMove(
	self: Types.Board,
	fromPosition: Types.Position,
	toPosition: Types.Position,
	promotion: Types.Promotion?,
	stillCurrent: (() -> boolean)?,
	isCancelled: (() -> boolean)?,
	onDestinationClick: (() -> ())?
): (boolean, string)
	if stillCurrent and not stillCurrent() then
		return false, "The position changed."
	end
	local client = self.client
	local board = self:getBoard()

	if not client then
		return false, "Client not found"
	end

	if not board then
		return false, "Board not found"
	end

	if self:isBotMatch() then
		return false, "AutoMove disabled in bot matches"
	end

	if not client.clickOnTile then
		return false, "clickOnTile not found"
	end

	if self:willCauseDesync() then
		return false, "Not safe to move right now"
	end

	local piece = getPieceAtPosition(board, fromPosition)
	if not piece then
		return false, "No piece at source"
	end
	-- Also guard callers that omit the UCI promotion suffix.
	if not promotion and piece.Name == "Pawn" and (toPosition[2] == 1 or toPosition[2] == 8) then
		return false, "Play this promotion manually and choose the promotion piece."
	end

	if piece.team ~= board.activeTeam then
		return false, "Piece is not active team"
	end

	if not self:hasLegalMove(piece, toPosition) then
		return false, "Illegal move"
	end

	local promotionNames: { [Types.Promotion]: string } = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }
	local requestedName = if promotion then promotionNames[promotion] else nil
	local originalGetMoves = piece.getMoves
	local preparedGetMoves: ((Types.Piece) -> { Types.GameMove })? = nil
	if requestedName then
		if piece.Name ~= "Pawn" or (toPosition[2] ~= 1 and toPosition[2] ~= 8) then
			return false, "Promotion metadata does not match a pawn reaching the last rank."
		end
		local hasPromotionMetadata = false
		for _, move in pairs(piece:getMoves()) do
			if samePosition(move, toPosition) and move.promote then
				hasPromotionMetadata = true
			end
		end
		if not hasPromotionMetadata then
			return false, "Promotion experiment stopped: the legal move has no promote metadata. Play manually."
		end
		-- Hypothesis: clickOnTile reads getMoves() to build the move it sends.
		-- Clone matching moves, retaining special fields, and fill the known pieceName slot.
		-- The override exists only around the two clicks; it is restored even on error.
		preparedGetMoves = function(currentPiece: Types.Piece): { Types.GameMove }
			local moves: { Types.GameMove } = {}
			for _, move in pairs(originalGetMoves(currentPiece)) do
				if samePosition(move, toPosition) and move.promote then
					local prepared = table.clone(move)
					prepared.promote = table.clone(move.promote)
					assert(prepared.promote, "Promotion metadata disappeared")
					prepared.promote.pieceName = requestedName
					table.insert(moves, prepared)
				else
					table.insert(moves, move)
				end
			end
			return moves
		end
		piece.getMoves = assert(preparedGetMoves, "Promotion move provider was not prepared")
	end

	local completed, message = pcall(function(): string
		local clickOnTile = assert(client.clickOnTile, "The game tile handler is unavailable")
		clickOnTile(client, fromPosition[1], fromPosition[2])
		task.wait(0.15)
		if stillCurrent and not stillCurrent() then
			return "Move cancelled before the destination click."
		end
		if onDestinationClick then
			onDestinationClick()
		end
		clickOnTile(client, toPosition[1], toPosition[2])
		return "Move attempted"
	end)
	if preparedGetMoves and piece.getMoves == preparedGetMoves then
		piece.getMoves = originalGetMoves
	end
	if not completed then
		return false, "Tile click failed: " .. tostring(message)
	end
	if message ~= "Move attempted" then
		return false, tostring(message)
	end
	if not requestedName then
		return true, "Move attempted"
	end

	-- A submitted move is not proof that promotion succeeded. Do not retry automatically.
	local deadline = os.clock() + 3
	repeat
		if (isCancelled and isCancelled()) or self:getBoard() ~= board then
			return false, "Promotion verification cancelled. Check the game before retrying."
		end
		local promoted = self:getBoardPiece(toPosition)
		if promoted and promoted.team == piece.team and promoted.Name ~= "Pawn" then
			if promoted.Name == requestedName then
				return true, "Promotion confirmed: " .. requestedName
			end
			return false,
				"Promotion produced "
					.. promoted.Name
					.. " instead of "
					.. requestedName
					.. ". Disable Experimental promotion."
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return false,
		"Promotion was not confirmed. Check the selector or board, and disable Experimental promotion before retrying."
end

return Board
