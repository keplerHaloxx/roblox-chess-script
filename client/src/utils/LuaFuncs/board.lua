local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local ChessHelper = {}

ChessHelper.__index = ChessHelper

ChessHelper.Pieces = {
	Pawn = "p",
	Knight = "n",
	Bishop = "b",
	Rook = "r",
	Queen = "q",
	King = "k",
}

local function samePosition(a, b)
	return a and b and a[1] == b[1] and a[2] == b[2]
end

local function getPieceAtPosition(board, position)
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

local function findClient()
	for _, fn in pairs(getreg()) do
		if type(fn) == "function" and not iscclosure(fn) then
			for _, upvalue in pairs(debug.getupvalues(fn)) do
				if type(upvalue) == "table" and upvalue.processRound then
					return upvalue
				end
			end
		end
	end

	return nil
end

function ChessHelper.new()
	local self = setmetatable({}, ChessHelper)

	self.client = findClient()

	return self
end

function ChessHelper:refreshClient()
	self.client = findClient()
	return self.client
end

function ChessHelper:getBoard()
	if self.client and self.client.currentMatch then
		return self.client.currentMatch
	end

	if not (self.client and self.client.processRound) then
		return nil
	end

	for _, upvalue in pairs(debug.getupvalues(self.client.processRound)) do
		if type(upvalue) == "table" and upvalue.tiles and upvalue.boardExists then
			return upvalue
		end
	end

	return nil
end

function ChessHelper:isGameInProgress()
	local boardFolder = Workspace:FindFirstChild("Board")
	return boardFolder ~= nil and #boardFolder:GetChildren() > 0
end

function ChessHelper:isBotMatch()
	local board = self:getBoard()

	return board ~= nil
		and board.players ~= nil
		and board.players[true] == LocalPlayer
		and board.players[false] == LocalPlayer
end

function ChessHelper:getLocalTeam()
	local board = self:getBoard()
	if not board then
		return nil
	end

	if self:isBotMatch() then
		return "w"
	end

	for team, player in pairs(board.players or {}) do
		if player == LocalPlayer then
			return team and "w" or "b"
		end
	end

	return nil
end

function ChessHelper:isPlayerTurn()
	local team = self:getLocalTeam()
	if not team then
		return false
	end

	local gameStatus = LocalPlayer.PlayerGui:FindFirstChild("GameStatus")
	if not gameStatus then
		return false
	end

	local teamGui = gameStatus:FindFirstChild(team == "w" and "White" or "Black")
	return teamGui ~= nil and teamGui.Visible
end

function ChessHelper:willCauseDesync()
	local board = self:getBoard()
	if not board then
		return false
	end

	if self:isBotMatch() then
		return false
	end

	for team, player in pairs(board.players or {}) do
		if player == LocalPlayer then
			return board.activeTeam ~= team
		end
	end

	return true
end

function ChessHelper:getBoardPiece(position)
	local board = self:getBoard()
	if not board then
		return nil
	end

	return getPieceAtPosition(board, position)
end

function ChessHelper:getWorkspacePiece(tileName)
	local boardFolder = Workspace:FindFirstChild("Board")
	if not boardFolder then
		return nil
	end

	local tile = boardFolder:FindFirstChild(tileName)
	if not tile then
		return nil
	end

	local origin

	if tile:IsA("Model") then
		local meshTile = tile:FindFirstChild("Meshes/tile_a")
		local tilePart = tile:FindFirstChild("Tile")
		local part = meshTile or tilePart

		if not part then
			return nil
		end

		origin = part.Position
	else
		origin = tile.Position
	end

	local result = Workspace:Raycast(origin, Vector3.new(0, 10, 0))
	return result and result.Instance.Parent or nil
end

function ChessHelper:createBoard()
	local board = self:getBoard()
	if not board then
		return nil
	end

	local boardMap = {}

	local function placePiece(piece, isWhite)
		if not (piece and piece.position and piece.Name) then
			return
		end

		local x, y = piece.position[1], piece.position[2]
		local symbol = self.Pieces[piece.Name]

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

function ChessHelper:board2fen()
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

	return table.concat(result, "/") .. " " .. (self:getLocalTeam() or "-")
end

function ChessHelper:hasLegalMove(piece, targetPosition)
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

function ChessHelper:autoMove(fromPosition, toPosition)
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

	if piece.team ~= board.activeTeam then
		return false, "Piece is not active team"
	end

	if not self:hasLegalMove(piece, toPosition) then
		return false, "Illegal move"
	end

	client:clickOnTile(fromPosition[1], fromPosition[2])
	task.wait(0.15)
	client:clickOnTile(toPosition[1], toPosition[2])

	return true, "Move attempted"
end

return ChessHelper
