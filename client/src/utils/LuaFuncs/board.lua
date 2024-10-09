local mod = {
	pieces = {
		["Pawn"] = "p",
		["Knight"] = "n",
		["Bishop"] = "b",
		["Rook"] = "r",
		["Queen"] = "q",
		["King"] = "k",
	},
}
mod.__index = mod

local lplayer = game:GetService("Players").LocalPlayer

---@return any[]
function mod.getClient()
	for _, v in pairs(getreg()) do
		if type(v) == "function" and not iscclosure(v) then
			for _, v in pairs(debug.getupvalues(v)) do
				if type(v) == "table" and v.processRound then
					return v
				end
			end
		end
	end
end

---@return Instance | nil
function mod.getPiece(tile)
	local rayOrigin
	local boardTile = game:GetService("Workspace").Board[tile]

	if boardTile.ClassName == "Model" then
		if game:GetService("Workspace").Board[tile]:FindFirstChild("Meshes/tile_a") then
			rayOrigin = game:GetService("Workspace").Board[tile]["Meshes/tile_a"].Position
		else
			rayOrigin = game:GetService("Workspace").Board[tile]["Tile"].Position
		end
	else
		rayOrigin = game:GetService("Workspace").Board[tile].Position
	end

	local rayDirection = Vector3.new(0, 10, 0)

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection)

	if raycastResult ~= nil then
		return raycastResult.Instance.Parent
	end

	return nil
end

function mod.gameInProgress()
	return #game:GetService("Workspace").Board:GetChildren() > 0
end

function mod.new()
	local self = setmetatable({}, mod)
	self.client = self.getClient()

	return self
end

---@return any[] | nil
function mod:getBoard()
	for _, v in pairs(debug.getupvalues(self.client.processRound)) do
		if type(v) == "table" and v.tiles then
			return v
		end
	end

	return nil
end

---@return boolean
function mod:isBotMatch()
	local board = self:getBoard()

	if not board or not board.players then
		return false
	end
	if board.players[false] == lplayer and board.players[true] == lplayer then
		return true
	end

	return false
end

---@return "w" | "b" | nil
function mod:getLocalTeam()
	local board = self:getBoard()
	if not board then
		return nil
	end
	-- Bot match detection
	if self:isBotMatch() then
		return "w"
	end

	for i, v in pairs(board.players) do
		if v == lplayer then
			-- If the index is true, they are white
			if i then
				return "w"
			else
				return "b"
			end
		end
	end

	return nil
end

---@return boolean
function mod:isPlayerTurn()
	local team = self:getLocalTeam()
	local guiName = if team == "w" then "White" else "Black"
	if lplayer.PlayerGui.GameStatus[guiName].Visible then
		return true
	end
	return false
end

---Check if we're able to run without desyncing
---@return boolean
function mod:willCauseDesync()
	local board = self:getBoard()

	if not board then
		return false
	end

	local state, _ = pcall(function()
		if self:isBotMatch() then
			return board.activeTeam == false
		end
	end)

	if not state then
		return false
	end

	for i, v in pairs(board.players) do
		if v == lplayer then
			-- If the index is true, they are white
			return not (board.activeTeam == i)
		end
	end

	return true
end

---Converts awful format of board table to a sensible one
---@return any[] | nil
function mod:createBoard()
	local board = self:getBoard()
	if not board then
		return nil
	end

	local newBoard = {}
	for _, v in pairs(board.whitePieces) do
		if v and v.position then
			local x, y = v.position[1], v.position[2]
			if not newBoard[x] then
				newBoard[x] = {}
			end
			newBoard[x][y] = string.upper(self.pieces[v.object.Name])
		end
	end
	for _, v in pairs(board.blackPieces) do
		if v and v.position then
			local x, y = v.position[1], v.position[2]
			if not newBoard[x] then
				newBoard[x] = {}
			end
			newBoard[x][y] = self.pieces[v.object.Name]
		end
	end

	return newBoard
end

---@return string | nil
function mod:board2fen()
	local board = self:createBoard()
    if not board then return nil end

	local result = ""
	local boardPieces = self:createBoard(board)
	for y = 8, 1, -1 do
		local empty = 0
		for x = 8, 1, -1 do
			if not boardPieces[x] then
				boardPieces[x] = {}
			end
			local piece = boardPieces[x][y]
			if piece then
				if empty > 0 then
					result = result .. tostring(empty)
					empty = 0
				end
				result = result .. piece
			else
				empty += 1
			end
		end
		if empty > 0 then
			result = result .. tostring(empty)
		end
		if not (y == 1) then
			result = result .. "/"
		end
	end
	result = result .. " " .. self:getLocalTeam(board)
	return result
end

return mod
