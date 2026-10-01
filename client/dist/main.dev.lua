-- Registry entries can contain arbitrary closures; enumerating their signatures is not useful.
local __DARKLUA_BUNDLE_MODULES={cache={}}do do local function __modImpl()








































































































































































































































































































































































































































































































































































































































































































































































































































































































































































return {}
end function __DARKLUA_BUNDLE_MODULES.a()local v=__DARKLUA_BUNDLE_MODULES.cache.a if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer


local executorDebug = (debug ) 

local Board = {}

Board.Pieces = {
	Pawn = "p",
	Knight = "n",
	Bishop = "b",
	Rook = "r",
	Queen = "q",
	King = "k",
}

local function samePosition(a, b)	
return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2]
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
					return upvalue 				
end
			end
		end
	end

	return nil
end

function Board.new()	
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

function Board.refreshClient(self)	
self.client = findClient()
	return self.client
end

function Board.getBoard(self)	
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
			return upvalue 		
end
	end

	return nil
end

function Board.isGameInProgress(_self)	
local boardFolder = Workspace:FindFirstChild("Board")
	return boardFolder ~= nil and #boardFolder:GetChildren() > 0
end

function Board.isBotMatch(self)	
local board = self:getBoard()

	return board ~= nil
		and board.players ~= nil
		and board.players[true] == LocalPlayer
		and board.players[false] == LocalPlayer
end

function Board.getLocalTeam(self)	
local board = self:getBoard()
	if not board then
		return nil
	end

	if self:isBotMatch() then
		return "w"
	end

	local players= board.players or {}
	for team, player in pairs(players) do
		if player == LocalPlayer then
			return if team then "w" else "b"
		end
	end

	return nil
end

function Board.isPlayerTurn(self)	
local team = self:getLocalTeam()
	local match = self:getBoard()
	if not team or not match or type(match.activeTeam) ~= "boolean" then
		return false
	end
	-- Use the same authoritative turn as FEN. The GUI may lag, disappear,
	-- or change visibility between moves and must not stall the next turn.
	return match.activeTeam == (team == "w")
end

function Board.willCauseDesync(self)	
local board = self:getBoard()
	if not board then
		return true
	end

	local team = self:getLocalTeam()
	return team == nil or type(board.activeTeam) ~= "boolean" or board.activeTeam ~= (team == "w")
end

function Board.getBoardPiece(self, position)	
local board = self:getBoard()
	if not board then
		return nil
	end

	return getPieceAtPosition(board, position)
end

function Board.createBoard(self)	
local board = self:getBoard()
	if not board then
		return nil
	end

	local boardMap= {}

	local function placePiece(piece, isWhite)		
if not (piece and piece.position and piece.Name) then
			return
		end

		local x, y = piece.position[1], piece.position[2]
		local symbols= Board.Pieces
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

function Board.board2fen(self)	
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

function Board.hasLegalMove(_self, piece, targetPosition)	
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
	self,
	fromPosition,
	toPosition,
	promotion,
	stillCurrent,
	isCancelled,
	onDestinationClick
)	
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

	local promotionNames= { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }
	local requestedName = if promotion then promotionNames[promotion] else nil
	local originalGetMoves = piece.getMoves
	local preparedGetMoves= nil
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
		preparedGetMoves = function(currentPiece)			
local moves= {}
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

	local completed, message = pcall(function()		
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
end function __DARKLUA_BUNDLE_MODULES.b()local v=__DARKLUA_BUNDLE_MODULES.cache.b if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.b=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Protocol = {}

--- Convert UCI notation into the game's mirrored board coordinates.
function Protocol.parseMove(move)	
if type(move) ~= "string" or not string.match(move, "^[a-h][1-8][a-h][1-8][qrbn]?$") then
		return nil, "The engine did not return a playable move."
	end
	return {
		fromPos = { 105 - string.byte(move, 1), assert(tonumber(string.sub(move, 2, 2))) },
		toPos = { 105 - string.byte(move, 3), assert(tonumber(string.sub(move, 4, 4))) },
		promotion = if #move == 5 then (string.sub(move, 5, 5) )else nil,
	},
		nil
end

--- Validate the transport envelope before interpreting endpoint-specific fields.
function Protocol.decodeResponse(
	response,
	decode
)	
if type(response) ~= "table" then
		return nil, "The HTTP function returned an invalid response.", nil
	end
	local envelope = response 	
local body = envelope.Body
	if type(body) ~= "string" or body == "" then
		return nil, "The server returned an empty response.", nil
	end
	local decoded, raw = pcall(decode, body)
	if not decoded or type(raw) ~= "table" then
		return nil, "The server returned invalid JSON. Check that the chess server is running.", nil
	end
	local data = raw 	
if data.ok == false and type(data.error) == "table" then
		local failure = (data.error )		
return nil,
			tostring(failure.message or "The server rejected the request."),
			if type(failure.code) == "string" then failure.code else nil
	end
	local status = tonumber(envelope.StatusCode)
	if envelope.Success == false or not status or status < 200 or status >= 300 then
		return nil, `Server request failed (HTTP {tostring(envelope.StatusCode)}).`, nil
	end
	if data.ok ~= true then
		return nil, "The server response is missing its success status.", nil
	end
	return data, nil, nil
end

function Protocol.delayMs(difficulty, useCalculated, manualDelay)	
local delay = if useCalculated and difficulty then difficulty.recommended_delay_ms else manualDelay
	if type(delay) ~= "number" or delay ~= delay or math.abs(delay) == math.huge then
		delay = manualDelay
	end
	return math.clamp(delay , 0, 120000)
end
return Protocol
end function __DARKLUA_BUNDLE_MODULES.c()local v=__DARKLUA_BUNDLE_MODULES.cache.c if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.c=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local HttpService = game:GetService("HttpService")
local Protocol = __DARKLUA_BUNDLE_MODULES.c()

local ChessServer = {}
ChessServer.API_BASE_URL = "http://127.0.0.1:57250/api/v1"



function ChessServer.new(httpRequest)	
return { request = httpRequest, call = ChessServer.call, findBestMove = ChessServer.findBestMove }
end

function ChessServer.call(
	self,
	path,
	payload
)	
local requestFunction = self.request
	if not requestFunction then
		return nil, "Your executor does not provide an HTTP request function.", nil
	end
	local ok, response = pcall(function()
		return requestFunction({
			Url = ChessServer.API_BASE_URL .. path,
			Method = if payload then "POST" else "GET",
			Headers = { ["Content-Type"] = "application/json" },
			Body = if payload then HttpService:JSONEncode(payload) else nil,
		})
	end)
	if not ok then
		return nil, "Cannot reach the chess server. Open the desktop app and try again. " .. tostring(response), nil
	end
	return Protocol.decodeResponse(response, function(body)
		return HttpService:JSONDecode(body)
	end)
end

function ChessServer.findBestMove(self, board, options)	
local function fail(reason, code)		
return { success = false, reason = reason or "Unknown server error", code = code }
	end
	if not board:isGameInProgress() then
		return fail("Join a chess match first.")
	end
	if not board:isPlayerTurn() then
		return fail("Wait for your turn.")
	end
	if board:willCauseDesync() then
		return fail("The board is still updating. Try again shortly.")
	end
	local match = board:getBoard()
	local fen = board:board2fen()
	if not fen or not match then
		return fail("Could not read the board. Try Refresh board.")
	end
	local data, reason, code = self:call("/analyze", {
		fen = fen,
		depth = options.depth,
		max_think_time_ms = options.thinkTime,
		disregard_think_time = options.disregardTime,
	})
	if not data then
		return fail(reason, code)
	end
	if board:getBoard() ~= match or not board:isPlayerTurn() or board:board2fen() ~= fen then
		return fail("The position changed while the engine was thinking.", "stale_position")
	end
	local parsed, moveError = Protocol.parseMove(data.best_move)
	if not parsed then
		return fail(moveError)
	end
	local piece = board:getBoardPiece(parsed.fromPos)
	if not piece or not board:hasLegalMove(piece, parsed.toPos) then
		return fail("The engine move is no longer legal. Refresh the board and try again.")
	end
	local folder = workspace:FindFirstChild("Board")
	-- Highlight stable board squares; skinned piece geometry is not required to move.
	local source = folder and folder:FindFirstChild(table.concat(parsed.fromPos, ","))
	local destination = folder and folder:FindFirstChild(table.concat(parsed.toPos, ","))
	if not source or not destination then
		return fail("Could not find the move's tiles in the game.")
	end

	local difficulty= nil
	if type(data.difficulty) == "table" then
		local raw = (data.difficulty )		
if type(raw.recommended_delay_ms) == "number" then
			difficulty = { recommended_delay_ms = raw.recommended_delay_ms }
		end
	end
	local move = (data.best_move )	
return {
		success = true,
		best_move = move,
		move = move,
		piece = source,
		destination = destination,
		fromPos = parsed.fromPos,
		toPos = parsed.toPos,
		promotion = parsed.promotion,
		fen = fen,
		match = match,
		difficulty = difficulty,
	}
end

return ChessServer
end function __DARKLUA_BUNDLE_MODULES.d()local v=__DARKLUA_BUNDLE_MODULES.cache.d if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.d=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Highlighter = {}



function Highlighter.new()	
local folder = Instance.new("Folder")
	folder.Name = "ChessMoveHighlights"
	folder.Parent = workspace
	return { folder = folder, clear = Highlighter.clear, show = Highlighter.show, destroy = Highlighter.destroy }
end

function Highlighter.clear(self)	
self.folder:ClearAllChildren()
end

function Highlighter.show(self, piece, destination, options)	
self:clear()
	for _, target in ipairs({ piece, destination }) do
		local highlight = Instance.new("Highlight")
		highlight.Adornee = target
		highlight.FillColor = options.fillColor
		highlight.OutlineColor = options.outlineColor
		highlight.FillTransparency = options.fillTransparency
		highlight.OutlineTransparency = options.outlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = self.folder
	end
end

function Highlighter.destroy(self)	
self.folder:Destroy()
end

return Highlighter
end function __DARKLUA_BUNDLE_MODULES.e()local v=__DARKLUA_BUNDLE_MODULES.cache.e if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.e=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Protocol = __DARKLUA_BUNDLE_MODULES.c()
local Controller = {}

local REQUEST_TIMEOUT_SECONDS = 130
local RETRY_DELAY_SECONDS = 3
local MOVE_CHECK_INTERVAL_SECONDS = 0.05
local PROMOTION_NAMES= { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }


























local function isRequestActive(self, version)	
return not self.destroyed and self.requestVersion == version and (not self.isAlive or self.isAlive())
end

local function isPositionCurrent(
	self,
	result,
	version,
	automatic
)	
return isRequestActive(self, version)
		and (not automatic or self.options.autoCalculate)
		and self.board:isGameInProgress()
		and self.board:isPlayerTurn()
		and self.board:getBoard() == result.match
		and self.board:board2fen() == result.fen
		and not self.board:willCauseDesync()
end

local function stopAutomation(self)	
self.options.autoCalculate = false
	if self.onAutomationStopped then
		self.onAutomationStopped()
	end
end

--- A highlighted result is not a completed move. Permit another attempt when
--- execution was abandoned before submission, without retrying sent moves.
local function retryPosition(self)	
self.lastAnalyzedFen = nil
	self.retryAfter = os.clock() + RETRY_DELAY_SECONDS
end

local function executeMove(self, result, version, automatic)	
if self.board:isBotMatch() then
		self.emit("output", `Best move: {result.move}. Auto execute is disabled in bot matches.`)
		return
	end
	local delayMs = Protocol.delayMs(result.difficulty, self.options.useCalculatedDelay, self.options.executeDelay)
	self.emit("status", `Waiting {delayMs} ms before moving…`)
	self.requestPhase = "Waiting before moving…"
	local deadline = os.clock() + delayMs / 1000
	repeat
		if not isPositionCurrent(self, result, version, automatic) then
			if isRequestActive(self, version) then
				retryPosition(self)
			end
			return
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(MOVE_CHECK_INTERVAL_SECONDS)
	until false

	self.requestPhase = "Selecting the piece…"
	local moved, reason = self.board:autoMove(result.fromPos, result.toPos, result.promotion, function()
		return isPositionCurrent(self, result, version, automatic)
	end, function()
		-- Once a move is submitted the position should change; only session cancellation applies.
		return not isRequestActive(self, version)
	end, function()
		if isRequestActive(self, version) then
			self.submittedMove = result
			self.requestPhase = "Waiting for the game to finish the move…"
		end
	end)
	if not isRequestActive(self, version) then
		return
	end
	if moved then
		self.emit("status", if result.promotion then "Promotion confirmed" else "Move sent")
		self.emit("output", reason)
	elseif result.promotion then
		stopAutomation(self)
		self.emit("status", "Promotion needs attention; Auto Play stopped")
		self.emit("instruction", reason)
	else
		retryPosition(self)
		self.emit("status", "Move highlighted")
		self.emit("output", `Best move: {result.move}. {reason}`)
	end
end

local function analyzePosition(self, version, autoExecute, automatic)	
if not isRequestActive(self, version) then
		return
	end
	local result = self.server:findBestMove(self.board, table.clone(self.options))
	if not isRequestActive(self, version) then
		return
	end
	if not result.success then
		self.emit("output", result.reason)
		self.emit("status", "Needs attention")
		self.retryAfter = os.clock() + RETRY_DELAY_SECONDS
		return
	end
	if not isPositionCurrent(self, result, version, automatic) then
		return
	end

	self.highlighter:show(result.piece, result.destination, self.options)
	self.highlightedFen = result.fen
	self.lastAnalyzedFen = result.fen
	self.lastMatch = result.match
	if result.promotion and (not autoExecute or not self.options.experimentalPromotion) then
		self.emit("status", "Promotion: manual move required")
		self.emit(
			"instruction",
			`Play {result.move} manually and choose {PROMOTION_NAMES[result.promotion]}. Auto Play will resume after the position changes.`
		)
		return
	end
	self.emit("output", `Best move: {result.move}`)
	self.emit("status", "Move highlighted")
	if autoExecute then
		executeMove(self, result, version, automatic)
	end
end

function Controller.new(
	board,
	server,
	highlighter,
	options,
	emit
)	
return {
		board = board,
		server = server,
		highlighter = highlighter,
		options = options,
		emit = emit,
		busy = false,
		destroyed = false,
		requestVersion = 0,
		retryAfter = 0,
		cancel = Controller.cancel,
		run = Controller.run,
		tick = Controller.tick,
		destroy = Controller.destroy,
	}
end

--- Invalidates pending work without waiting for a blocked HTTP request to finish.
function Controller.cancel(self)	
self.requestVersion += 1
	self.busy = false
	self.activeRequest = nil
	self.requestPhase = nil
	self.submittedMove = nil
	self.lastAnalyzedFen = nil
	self.lastMatch = nil
	self.highlightedFen = nil
	self.highlighter:clear()
	if not self.destroyed then
		self.emit("status", "Idle")
	end
end

function Controller.run(self, autoExecute, automatic)	
if self.busy or self.destroyed then
		return false
	end
	self.busy = true
	self.requestVersion += 1
	local version = self.requestVersion
	self.activeRequest = version
	self.requestPhase = "Calculating with Stockfish…"
	self.submittedMove = nil
	self.emit("status", "Calculating…")

	task.delay(REQUEST_TIMEOUT_SECONDS, function()
		if not isRequestActive(self, version) or self.activeRequest ~= version or not self.busy then
			return
		end
		self:cancel()
		self.retryAfter = os.clock() + RETRY_DELAY_SECONDS
		self.emit("status", "Request timed out")
		self.emit("output", "The server took too long to respond. Check the desktop app and retry.")
	end)
	task.spawn(function()
		local success, problem = pcall(function()			
analyzePosition(self, version, autoExecute, automatic)
			return true
		end)
		if not success and isRequestActive(self, version) then
			retryPosition(self)
			self.emit("status", "Needs attention")
			self.emit("output", tostring(problem))
			self.retryAfter = os.clock() + RETRY_DELAY_SECONDS
		end
		-- An old response must never release a newer request's busy state.
		if self.activeRequest == version then
			self.busy = false
			self.activeRequest = nil
			self.requestPhase = nil
			self.submittedMove = nil
		end
	end)
	return true
end

--- Poll the board; analyze at most once per unchanged position and match.
function Controller.tick(self)	
if self.destroyed then
		return
	end
	local playing = self.board:isGameInProgress()
	local playerTurn = playing and self.board:isPlayerTurn()
	local fen = if playerTurn then self.board:board2fen() else nil
	local match = self.board:getBoard()
	local submitted = self.submittedMove
	if self.busy and submitted and not submitted.promotion then
		local currentFen = if playing then self.board:board2fen() else nil
		if match ~= submitted.match or (currentFen ~= nil and currentFen ~= submitted.fen) then
			-- clickOnTile is game-owned and can yield after applying the move.
			-- A changed board retires this request without waiting for that call
			-- to return. Its eventual result must not affect the next request.
			self.requestVersion += 1
			self.activeRequest = nil
			self.busy = false
			self.submittedMove = nil
			self.requestPhase = nil
			self.emit("status", "Board updated; ready for the next turn")
		end
	end
	if self.highlightedFen and (fen ~= self.highlightedFen or match ~= self.lastMatch) then
		self.highlighter:clear()
		self.highlightedFen = nil
	end
	if not playerTurn then
		self.lastAnalyzedFen = nil
	end
	local status = if playing and self.board:isBotMatch()
		then "⚠ Bot match detected — automatic moves unavailable. Suggestions still work."
		elseif not self.options.autoCalculate then "Inactive"
		elseif not playing then "Waiting for a match"
		elseif not playerTurn then "Waiting for your turn"
		elseif self.busy then self.requestPhase or "Calculating or moving…"
		else "Waiting for your move"
	if status ~= self.automationStatus then
		self.emit("auto", status)
		self.automationStatus = status
	end
	if
		self.options.autoCalculate
		and playerTurn
		and fen
		and not self.busy
		and os.clock() >= self.retryAfter
		and (fen ~= self.lastAnalyzedFen or match ~= self.lastMatch)
	then
		self:run(self.options.autoExecute, true)
	end
end

function Controller.destroy(self)	
self.destroyed = true
	self.requestVersion += 1
	self.highlighter:destroy()
end
return Controller
end function __DARKLUA_BUNDLE_MODULES.f()local v=__DARKLUA_BUNDLE_MODULES.cache.f if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.f=v end return v.c end end do local function __modImpl()








































































































































































































































































































































































































































































































































































































































































return {}
end function __DARKLUA_BUNDLE_MODULES.g()local v=__DARKLUA_BUNDLE_MODULES.cache.g if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.g=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local RayfieldTypes = __DARKLUA_BUNDLE_MODULES.g()
local ControllerTypes = __DARKLUA_BUNDLE_MODULES.f()
local Controls = {}

















function Controls.build(context)	
local window = context.window
	local mainTab = context.mainTab
	local engineTab = context.engineTab
	local autoTab = context.autoTab
	local themeTab = context.themeTab
	local options = context.options
	local controller = context.controller
	local board = context.board
	local server = context.server
	local session = context.session
	local emit = context.emit
	local clearOutput = context.clearOutput

	local function run(autoExecute)		
if not controller:run(autoExecute, false) then
			window:Notify({ title = "Already working", content = "Wait for the current request or cancel it first." })
		end
	end

	mainTab:CreateSection({ name = "Your next move" })
	local actions = mainTab:CreateGroup({ direction = "row" })
	actions:CreateButton({
		name = "Suggest move",
		callback = function()
			run(false)
		end,
	})
	actions:CreateButton({
		name = "Play best move",
		callback = function()
			run(true)
		end,
	})
	mainTab:CreateButton({
		name = "Stop & clear",
		description = "Cancel pending moves, stop Auto Play, and clear highlights.",
		callback = function()
			window:Set("AutoCalculate", false)
			controller:cancel()
			clearOutput()
		end,
	})
	mainTab:CreateText({
		name = "How to play",
		text = "Suggest move marks the two squares. Play best move calculates and clicks for you. Open Auto Play to repeat this on every turn.",
	})
	mainTab:CreateSection({ name = "Connection" })
	local connection = mainTab:CreateText({
		name = "Desktop server",
		text = "Not checked. Open the desktop app, then check the connection.",
	})
	local checkingConnection = false
	mainTab:CreateButton({
		name = "Check connection",
		callback = function()
			if checkingConnection then
				return
			end
			checkingConnection = true
			connection:Set("Checking the desktop server…")
			local data, reason = server:call("/status")
			checkingConnection = false
			if session.stopped or window.unloaded then
				return
			end
			local engine = data and data.engine
			local engineStatus = if type(engine) == "table"
				then tostring((engine ).status or "unknown")
				else "unknown"
			connection:Set(
				if data
					then (if engineStatus == "ready"
						then "Connected · Stockfish is ready"
						else `Connected · Engine: {engineStatus}`)
					else "Offline · Open the desktop app and try again."
			)
			window:Notify({
				title = if data then "Server connected" else "Connection failed",
				content = if type(engine) == "table"
					then `Engine: {tostring((engine ).status or "unknown")}`
					else reason or "Server responded.",
			})
		end,
	})
	engineTab:CreateSection({ name = "Search strength" })
	engineTab:CreateSlider({
		name = "Search depth",
		description = "Higher depth searches further when time allows.",
		range = { 1, 40 },
		increment = 1,
		value = 17,
		flag = "Depth",
		callback = function(value)
			options.depth = value
		end,
	})
	engineTab:CreateSlider({
		name = "Time per suggestion",
		range = { 10, 5000 },
		increment = 10,
		suffix = "ms",
		value = 100,
		flag = "MaxThinkTime",
		callback = function(value)
			options.thinkTime = value
		end,
	})
	engineTab:CreateToggle({
		name = "Search until depth is reached",
		description = "Ignore the time limit. Deep searches can take longer.",
		value = false,
		flag = "DisregardThinkTime",
		callback = function(value)
			options.disregardTime = value
		end,
	})

	engineTab:CreateSection({ name = "Troubleshooting" })
	engineTab:CreateButton({
		name = "Reconnect to board",
		description = "Try this if the board cannot be read after joining a match.",
		callback = function()
			controller:cancel()
			board:refreshClient()
			emit(
				"output",
				if board.client
					then "Board client found."
					else "Board client not found. Check executor support and join a match."
			)
		end,
	})
	engineTab:CreateButton({ name = "Close chess assistant", callback = session.cleanup })

	autoTab:CreateSection({ name = "Automation" })
	autoTab:CreateText({
		name = "⚠ Auto Play limitations",
		text = "Bot matches: automatic moves are unavailable.\n\nCastling & en passant: play these moves manually.\n\nPromotion: promote the pawn manually.",
	})

	local autoCalculateToggle = autoTab:CreateToggle({
		name = "Auto calculate",
		flag = "AutoCalculate",
		value = false,
		description = "Keep suggestions up to date whenever your turn begins. Does not move pieces on its own.",
		callback = function(value)
			options.autoCalculate = value
			controller:cancel()
		end,
	})
	autoTab:CreateToggle({
		name = "Auto execute move",
		flag = "AutoExecute",
		value = false,
		description = "Play suggestions automatically when Auto calculate is on.",
		callback = function(value)
			options.autoExecute = value
			controller:cancel()
		end,
	})

	autoTab:CreateSection({ name = "Timing" })
	autoTab:CreateSlider({
		name = "Pause before moving",
		range = { 0, 3000 },
		increment = 50,
		suffix = "ms",
		value = 300,
		flag = "ExecuteDelay",
		callback = function(value)
			options.executeDelay = value
		end,
	})
	autoTab:CreateToggle({
		name = "Use suggested pause",
		flag = "UseCalculatedDelay",
		value = false,
		description = "Use the server's timing when available; otherwise use the pause above. (VERY experimental, don't recommend)",
		callback = function(value)
			options.useCalculatedDelay = value
		end,
	})

	themeTab:CreateSection({ name = "Look & feel" })
	themeTab:CreateDropdown({
		name = "Theme",
		options = { "Default", "Cobalt", "Ember", "Amethyst", "Frost", "Rose" },
		value = "cobalt",
		flag = "RayfieldTheme",
		callback = function(value)
			window:ChangeTheme((string.lower(value) ))
		end,
	})

	themeTab:CreateSection({ name = "Highlight colors" })
	themeTab:CreateColorPicker({
		name = "Highlight fill",
		color = options.fillColor,
		alpha = 0.5,
		flag = "HighlightFillColor",
		callback = function(color, alpha)
			options.fillColor = color
			options.fillTransparency = 1 - alpha
		end,
	})
	themeTab:CreateColorPicker({
		name = "Highlight outline",
		color = options.outlineColor,
		alpha = 1,
		flag = "HighlightOutlineColor",
		callback = function(color, alpha)
			options.outlineColor = color
			options.outlineTransparency = 1 - alpha
		end,
	})

	controller.onAutomationStopped = function()
		autoCalculateToggle:Set(false, true)
	end
end
return Controls
end function __DARKLUA_BUNDLE_MODULES.h()local v=__DARKLUA_BUNDLE_MODULES.cache.h if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.h=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Rayfield = __DARKLUA_BUNDLE_MODULES.g()
local StatusView = {}

--- Keep the last result visible until a new result or explicit clear replaces it.

function StatusView.new(mainTab, autoTab, isAlive)	
local status = mainTab:CreateText({ name = "Status", text = "Ready when you are" })
	local output =
		mainTab:CreateText({ name = "Suggested move", text = "Join a match, then choose Suggest move below." })
	local automation = autoTab:CreateText({ name = "Auto Play", text = "Off · Enable Auto calculate to begin" })
	local function clearOutput()		
output:Set("No move selected. Choose Suggest move to analyze the board.")
	end
	local function report(kind, message)		
if not isAlive() then
			return
		end
		if kind == "auto" then
			automation:Set(if message == "Inactive" then "Off · Enable Auto calculate to begin" else message)
		elseif kind == "status" then
			status:Set(if message == "Idle" then "Ready when you are" else message)
		else
			-- Do not overwrite the useful move with an acknowledgement of the clicks.
			if message == "Move attempted" then
				return
			end
			local display = string.gsub(message, "Best move: ([a-h][1-8])([a-h][1-8])", "%1 → %2", 1)
			output:Set(display)
		end
	end
	return { report = report, clearOutput = clearOutput }
end
return StatusView
end function __DARKLUA_BUNDLE_MODULES.i()local v=__DARKLUA_BUNDLE_MODULES.cache.i if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.i=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Runtime = {}

--- One application namespace, shared only through the executor's global environment.
function Runtime.getState()	
assert(type(getgenv) == "function", "This client requires getgenv().")
	local environment = (getgenv() )	
if not environment.ChessClient then
		environment.ChessClient = { teleportQueued = false }
	end
	return (environment.ChessClient )
end

--- Executor compatibility is kept at the edge of the application.
function Runtime.getRequest()	
return request or http_request or (syn and syn.request) or (http and http.request)
end

function Runtime.queueTeleport(state, scriptUrl)	
if state.teleportQueued then
		return true
	end
	local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
	if not queue then
		return false
	end
	local success = pcall(queue, `loadstring(game:HttpGet("{scriptUrl}"))()`)
	state.teleportQueued = success
	return success
end
return Runtime
end function __DARKLUA_BUNDLE_MODULES.j()local v=__DARKLUA_BUNDLE_MODULES.cache.j if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.j=v end return v.c end end do local function __modImpl()--!strict

local Types = __DARKLUA_BUNDLE_MODULES.a()
local Settings = {}
function Settings.defaults()	
return {
		depth = 17,
		thinkTime = 100,
		disregardTime = false,
		autoCalculate = false,
		autoExecute = false,
		experimentalPromotion = false,
		executeDelay = 300,
		useCalculatedDelay = false,
		fillColor = Color3.fromRGB(59, 235, 223),
		outlineColor = Color3.fromRGB(255, 255, 255),
		fillTransparency = 0.5,
		outlineTransparency = 0,
	}
end
return Settings
end function __DARKLUA_BUNDLE_MODULES.k()local v=__DARKLUA_BUNDLE_MODULES.cache.k if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.k=v end return v.c end end end--!strict
-- Native Luau entry point. Bundle with Darklua before executing.

local Board = __DARKLUA_BUNDLE_MODULES.b()
local ChessServer = __DARKLUA_BUNDLE_MODULES.d()
local Highlighter = __DARKLUA_BUNDLE_MODULES.e()
local Controller = __DARKLUA_BUNDLE_MODULES.f()

local CHESS_PLACE_ID = 6222531507
local SCRIPT_URL = "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"
local Controls = __DARKLUA_BUNDLE_MODULES.h()
local StatusView = __DARKLUA_BUNDLE_MODULES.i()
local Runtime = __DARKLUA_BUNDLE_MODULES.j()
local Settings = __DARKLUA_BUNDLE_MODULES.k()
local Types = __DARKLUA_BUNDLE_MODULES.a()
local RayfieldTypes = __DARKLUA_BUNDLE_MODULES.g()
local runtimeState = Runtime.getState()
local httpRequest = Runtime.getRequest()

local function queueRejoin()	
return Runtime.queueTeleport(runtimeState, SCRIPT_URL)
end

if game.PlaceId ~= CHESS_PLACE_ID then
	local callback = Instance.new("BindableFunction")
	callback.OnInvoke = function(button)
		if button == "Join" then
			queueRejoin()
			game:GetService("TeleportService"):Teleport(CHESS_PLACE_ID)
		end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Chess by Haloxx",
			Text = "Open the supported CHESS game to use this script.",
			Button1 = "Join",
			Duration = 10,
			Callback = callback,
		})
	end)
	task.delay(15, function()
		callback:Destroy()
	end)
	return
end

local loaded, Rayfield = pcall(function()
	local executorGame = (game ) 	
local source = executorGame.HttpGet(game, "https://sirius.menu/gen2")
	local chunk, reason = loadstring(source)
	assert(chunk, reason)
	return chunk()
end)
if not loaded then
	warn("Could not load Rayfield Gen2: " .. tostring(Rayfield))
	return
end

if runtimeState.session then
	runtimeState.session.cleanup()
end

local options = Settings.defaults()
local library = Rayfield 
local window = library:CreateWindow({
	name = "Chess by Haloxx",
	subtitle = "A clearer next move",
	theme = "cobalt",
	showName = "Chess",
	sidebarLayout = false,
	configuration = {
		autoSave = true,
		autoLoad = true,
		customFolder = "keplerHaloxx-Chess",
		fileName = "chess-gen2",
	},
})
-- Label symbols avoid a dependency on externally hosted tab images.
local mainTab = window:CreateTab({ name = "🏠 Play" })
local autoTab = window:CreateTab({ name = "▶ Auto Play" })
local engineTab = window:CreateTab({ name = "⚙ Engine" })
local themeTab = window:CreateTab({ name = "🎨 Appearance" })
local board = Board.new()
local server = ChessServer.new(httpRequest)
local highlighter = Highlighter.new()
local session= { stopped = false, cleanup = function() end }
local statusView = StatusView.new(mainTab, autoTab, function()	
return not session.stopped and not window.unloaded
end)
local emit = statusView.report

local controller = Controller.new(board, server, highlighter, options, emit)
controller.isAlive = function()
	return not session.stopped and not window.unloaded
end
function session.cleanup()
	if session.stopped then
		return
	end
	session.stopped = true
	controller:destroy()
	if not window.unloaded then
		window:Unload()
	end
	if runtimeState.session == session then
		runtimeState.session = nil
	end
end
runtimeState.session = session

Controls.build({
	window = window,
	mainTab = mainTab,
	engineTab = engineTab,
	autoTab = autoTab,
	themeTab = themeTab,
	options = options,
	controller = controller,
	board = board,
	server = server,
	session = session,
	emit = emit,
	clearOutput = statusView.clearOutput,
})

if not queueRejoin() then
	mainTab:CreateText({
		name = "Rejoin support unavailable",
		text = "Run this script again after teleporting or rejoining.",
	})
end
if not board.client then
	emit(
		"output",
		"Board client not found. Join a match and use Refresh board. Your executor needs getreg and debug.getupvalues."
	)
end
if type(httpRequest) ~= "function" then
	emit("output", "Your executor needs request or http_request to connect to the desktop server.")
end

task.spawn(function()
	local nextPollAt = 0
	while not session.stopped and not window.unloaded do
		if os.clock() >= nextPollAt then
			local ok, reason = pcall(function()
				controller:tick()
			end)
			if not ok then
				-- Board objects may be replaced between turns. Keep the user's
				-- automation settings and retry instead of silently switching off.
				nextPollAt = os.clock() + 3
				emit("status", "Waiting for the board to update")
				emit("output", "Board read failed; retrying shortly. " .. tostring(reason))
			end
		end
		task.wait(0.2)
	end
	session.cleanup()
end)
