--!strict
local Types = require("../Types/Chess")
local HttpService = game:GetService("HttpService")
local Protocol = require("./Protocol")

local ChessServer = {}
ChessServer.API_BASE_URL = "http://127.0.0.1:57250/api/v1"

type Server = Types.Server

function ChessServer.new(httpRequest: Types.Request?): Server
	return { request = httpRequest, call = ChessServer.call, findBestMove = ChessServer.findBestMove }
end

function ChessServer.call(
	self: Server,
	path: string,
	payload: Types.AnalysisRequest?
): ({ [string]: unknown }?, string?, string?)
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

function ChessServer.findBestMove(self: Server, board: Types.Board, options: Types.Settings): Types.MoveResult
	local function fail(reason: string?, code: string?): Types.MoveFailure
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

	local difficulty: Types.Difficulty? = nil
	if type(data.difficulty) == "table" then
		local raw = data.difficulty :: { [string]: unknown }
		if type(raw.recommended_delay_ms) == "number" then
			difficulty = { recommended_delay_ms = raw.recommended_delay_ms }
		end
	end
	local move = data.best_move :: string -- parseMove validated the UCI string above.
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
