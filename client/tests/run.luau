local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Protocol = require("../src/Modules/Protocol")
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function loadModule(name, env)
	env.require = function(path)
		if path == "../Types/Chess" or path == "../Types/Rayfield" then
			return {}
		end
		if path == "./GameDispatcher" then
			if env.dispatcherOverride then
				return env.dispatcherOverride
			end
			return luau.load(fs.readFile("src/Modules/GameDispatcher.luau"), { environment = env })()
		end
		assert(path == "./Protocol", path)
		return Protocol
	end
	return luau.load(fs.readFile("src/Modules/" .. name), { environment = env })()
end

test("UCI coordinates, promotions, and terminal moves", function()
	local move = assert(Protocol.parseMove("e2e4"))
	assert(move.fromPos[1] == 4 and move.fromPos[2] == 2 and move.toPos[2] == 4)
	assert(Protocol.parseMove("a7a8n").promotion == "n")
	for _, invalid in ipairs({ "0000", "(none)", "a0a9", "a1a2qq", "x1a2", "a1a2\n" }) do
		assert(not Protocol.parseMove(invalid))
	end
end)
test("HTTP success and structured errors", function()
	local decode = function(body)
		return serde.decode("json", body)
	end
	assert(Protocol.decodeResponse({ StatusCode = 200, Body = '{"ok":true}' }, decode).ok)
	local data, message, code = Protocol.decodeResponse({
		StatusCode = 503,
		Success = false,
		Body = '{"ok":false,"error":{"code":"engine_not_configured","message":"Set up Stockfish"}}',
	}, decode)
	assert(not data and message == "Set up Stockfish" and code == "engine_not_configured")
	for _, body in ipairs({ "", "invalid json", "null", "[]", '{"ok":false}' }) do
		assert(not Protocol.decodeResponse({ StatusCode = 200, Body = body }, decode))
	end
	assert(not Protocol.decodeResponse({ StatusCode = 500, Body = '{"ok":true}' }, decode))
end)
test("Missing difficulty uses manual delay", function()
	assert(Protocol.delayMs(nil, true, 300) == 300)
	assert(Protocol.delayMs({ recommended_delay_ms = 850 }, true, 300) == 850)
	assert(Protocol.delayMs({ recommended_delay_ms = 850 }, false, 300) == 300)
	assert(Protocol.delayMs({ recommended_delay_ms = 0 / 0 }, true, 300) == 300)
end)

local httpService = {
	JSONEncode = function(_, data)
		return serde.encode("json", data)
	end,
	JSONDecode = function(_, body)
		return serde.decode("json", body)
	end,
}
local Server = loadModule("ChessServer.luau", {
	game = {
		GetService = function()
			return httpService
		end,
	},
	workspace = {
		FindFirstChild = function()
			return {
				FindFirstChild = function()
					return {}
				end,
			}
		end,
	},
})
local function boardFixture()
	local board = { fen = "position", match = {}, turn = true, playing = true, clicks = 0 }
	function board:isGameInProgress()
		return self.playing
	end
	function board:isPlayerTurn()
		return self.turn
	end
	function board:willCauseDesync()
		return false
	end
	function board:board2fen()
		return self.fen
	end
	function board:getBoard()
		return self.match
	end
	function board:getBoardPiece()
		return {}
	end
	function board:hasLegalMove()
		return true
	end
	function board:getWorkspacePiece()
		return {}
	end
	function board:isBotMatch()
		return false
	end
	function board:autoMove()
		self.clicks += 1
		return true
	end
	return board
end
test("HTTP request uses colon JSON methods and preserves move alias", function()
	local server = Server.new(function(request)
		if string.match(request.Url, "/status$") then
			return { StatusCode = 200, Body = '{"ok":true,"protocol_revision":1}' }
		end
		assert(request.Url == "http://127.0.0.1:57250/api/v1/analyze")
		local body = serde.decode("json", request.Body)
		assert(body.depth == 17 and body.max_think_time_ms == 100 and body.fen == "position")
		return { StatusCode = 200, Success = true, Body = '{"ok":true,"best_move":"e2e4"}' }
	end)
	local result = server:findBestMove(boardFixture(), { depth = 17, thinkTime = 100, disregardTime = false })
	assert(result.success and result.move == "e2e4" and result.fromPos[1] == 4)
end)
test("Network failures and stale HTTP responses", function()
	assert(not Server.new(function()
		error("offline")
	end):call("/status"))
	local board = boardFixture()
	local server = Server.new(function(request)
		if string.match(request.Url, "/status$") then
			return { StatusCode = 200, Body = '{"ok":true,"protocol_revision":1}' }
		end
		board.fen = "new position"
		return { StatusCode = 200, Body = '{"ok":true,"best_move":"e2e4"}' }
	end)
	assert(server:findBestMove(board, {}).code == "stale_position")
end)

test("Skinned piece geometry is not needed for analysis or highlighting", function()
	local board = boardFixture()
	function board:getWorkspacePiece()
		error("Piece raycasts must not be required")
	end
	local server = Server.new(function(request)
		if string.match(request.Url, "/status$") then
			return { StatusCode = 200, Body = '{"ok":true,"protocol_revision":1}' }
		end
		return { StatusCode = 200, Body = '{"ok":true,"best_move":"a7a8n"}' }
	end)
	local result = server:findBestMove(board, {})
	assert(result.success and result.promotion == "n" and result.piece and result.destination)
end)

local function controllerFixture()
	local now, queued, timers = 0, {}, {}
	local tasks = {
		spawn = function(fn)
			table.insert(queued, coroutine.create(fn))
		end,
		delay = function(delay, fn)
			table.insert(timers, { time = now + delay, fn = fn })
		end,
		wait = function()
			coroutine.yield()
		end,
	}
	local Controller =
		loadModule("Controller.luau", { task = tasks, os = {
			clock = function()
				return now
			end,
		} })
	local board = boardFixture()
	local highlighter = { count = 0 }
	function highlighter:show()
		self.count += 1
	end
	function highlighter:clear()
		self.count = 0
	end
	function highlighter:destroy()
		self.destroyed = true
	end
	local server = { calls = 0 }
	function server:findBestMove()
		self.calls += 1
		if self.hook then
			self.hook()
		end
		return { success = true, move = "e2e4", fen = board.fen, match = board.match }
	end
	local options = { autoCalculate = true, autoExecute = false, executeDelay = 0 }
	local messages = {}
	local controller = Controller.new(board, server, highlighter, options, function(kind, text)
		messages[kind] = text
	end)
	local function step(seconds)
		now += seconds or 0
		local due = timers
		timers = {}
		for _, timer in ipairs(due) do
			if timer.time <= now then
				timer.fn()
			else
				table.insert(timers, timer)
			end
		end
		local pending = queued
		queued = {}
		for _, thread in ipairs(pending) do
			local ok, err = coroutine.resume(thread)
			assert(ok, err)
			if coroutine.status(thread) ~= "dead" then
				table.insert(queued, thread)
			end
		end
	end
	return controller, board, server, highlighter, options, step, tasks, messages
end
test("Auto Play calculates once per position and rejects overlap", function()
	local controller, board, server, _, _, step = controllerFixture()
	controller:tick()
	assert(not controller:run(false, false))
	step()
	controller:tick()
	step()
	assert(server.calls == 1)
	board.fen = "next position"
	controller:tick()
	step()
	assert(server.calls == 2)
end)
test("Auto execution continues over several turns without duplicate submissions", function()
	local controller, board, server, _, options, step = controllerFixture()
	options.autoExecute = true
	for turn = 1, 4 do
		board.turn = true
		board.fen = "position " .. turn
		controller:tick()
		step()
		assert(board.clicks == turn and server.calls == turn and not controller.busy)
		controller:tick()
		step()
		assert(board.clicks == turn, "An unchanged position must not be submitted twice")
		board.turn = false
		controller:tick()
		step()
		assert(board.clicks == turn)
	end
end)

test("A tile handler that yields after moving cannot block the next turn", function()
	local controller, board, server, _, options, step, tasks = controllerFixture()
	options.autoExecute = true
	local releaseFirst = false
	function board:autoMove(_, _, _, _, _, onDestinationClick)
		self.clicks += 1
		local attempt = self.clicks
		onDestinationClick()
		if attempt == 1 then
			self.fen = "after first move"
			self.turn = false
			repeat
				tasks.wait()
			until releaseFirst
		else
			tasks.wait() -- Keep the second request active while the first one returns.
			tasks.wait()
		end
		return true, "Move attempted"
	end
	controller:tick()
	step()
	assert(controller.busy and board.clicks == 1)
	controller:tick()
	assert(not controller.busy, "Observed move must release the busy state")
	board.turn = true
	board.fen = "after opponent reply"
	controller:tick()
	step()
	assert(server.calls == 2 and board.clicks == 2 and controller.busy)
	releaseFirst = true
	step()
	assert(controller.busy, "Late first result must not unlock the second request")
	step()
	assert(not controller.busy)
end)

test("Unchanged board never releases a submitted request early", function()
	local controller, board, server, _, options, step, tasks = controllerFixture()
	options.autoExecute = true
	function board:autoMove(_, _, _, _, _, onDestinationClick)
		self.clicks += 1
		onDestinationClick()
		tasks.wait()
		tasks.wait()
		return true, "Move attempted"
	end
	controller:tick()
	step()
	controller:tick()
	assert(controller.busy)
	assert(not controller:run(true, true) and server.calls == 1)
	step()
	step()
	controller:tick()
	assert(server.calls == 1 and board.clicks == 1)
end)

test("Interrupted execution releases the position for a later attempt", function()
	local controller, board, server, _, options, step = controllerFixture()
	options.autoExecute = true
	options.executeDelay = 500
	controller:tick()
	step()
	board.turn = false
	step(1) -- Request sees the transition even if the polling loop missed it.
	board.turn = true
	assert(not controller.busy and board.clicks == 0)
	step(3)
	controller:tick()
	step()
	step(1)
	assert(server.calls == 2 and board.clicks == 1)
end)

test("Rejected execution retries after backoff rather than stopping on the first position", function()
	local controller, board, server, _, options, step = controllerFixture()
	options.autoExecute = true
	local attempts = 0
	function board:autoMove()
		attempts += 1
		if attempts == 1 then
			return false, "Board is updating"
		end
		self.clicks += 1
		return true, "Move attempted"
	end
	controller:tick()
	step()
	controller:tick()
	step()
	assert(server.calls == 1)
	step(3)
	controller:tick()
	step()
	assert(server.calls == 2 and board.clicks == 1)
end)

test("Disabling automation during execution delay prevents clicking", function()
	local controller, board, _, _, options, step = controllerFixture()
	options.executeDelay = 500
	controller:run(true, true)
	step()
	options.autoCalculate = false
	controller:cancel()
	step(1)
	assert(board.clicks == 0 and not controller.busy)
end)

test("Suggestion-only promotion never clicks and resumes after manual play", function()
	for _, promotion in ipairs({ "q", "r", "b", "n" }) do
		local controller, board, server, _, options, step, _, messages = controllerFixture()
		options.autoExecute = false
		function server:findBestMove()
			self.calls += 1
			return {
				success = true,
				move = "a7a8" .. promotion,
				promotion = promotion,
				fen = board.fen,
				match = board.match,
			}
		end
		controller:tick()
		step()
		assert(board.clicks == 0 and not controller.busy)
		assert(messages.status == "Promotion: manual move required" and messages.instruction)
		controller:tick()
		step()
		assert(server.calls == 1)
		board.fen = "promoted position"
		controller:tick()
		step()
		assert(server.calls == 2)
	end
end)
test("Normal move execution promotes without an experimental setting", function()
	for _, suffix in ipairs({ "q", "r", "b", "n" }) do
		for _, automatic in ipairs({ false, true }) do
			local controller, board, server, _, options, step, _, messages = controllerFixture()
			options.autoExecute = true
			function server:findBestMove()
				self.calls += 1
				return { success = true, move = "a7a8" .. suffix, promotion = suffix,
					fromPos = { 8, 7 }, toPos = { 8, 8 }, fen = board.fen, match = board.match }
			end
			function board:autoMove(from, to, promotion)
				assert(from[2] == 7 and to[2] == 8 and promotion == suffix)
				self.clicks += 1
				return true, "Promotion confirmed"
			end
			if automatic then controller:tick() else controller:run(true, false) end
			step()
			assert(board.clicks == 1 and messages.status == "Promotion confirmed")
		end
	end
end)
test("Board changes during delay prevent stale execution", function()
	local controller, board, _, _, options, step = controllerFixture()
	options.executeDelay = 500
	controller:run(true, false)
	step()
	board.match = {}
	step(1)
	assert(board.clicks == 0)
end)
test("Unloading ignores in-flight results and destroys owned highlights", function()
	local controller, board, server, highlighter, _, step, tasks = controllerFixture()
	server.hook = tasks.wait
	controller:run(true, false)
	step()
	controller:destroy()
	step()
	assert(board.clicks == 0 and highlighter.count == 0 and highlighter.destroyed)
end)
test("Timeout unlocks requests and old responses cannot unlock a newer job", function()
	local controller, _, server, _, _, step, tasks = controllerFixture()
	server.hook = function()
		tasks.wait()
		tasks.wait()
	end
	controller:run(false, false)
	step()
	step(131)
	assert(not controller.busy)
	controller:run(false, false)
	step()
	assert(controller.busy)
	step()
	step()
	assert(not controller.busy)
end)

test("Board reconnects after teleport startup and skips unseated clients", function()
	local player = {}
	local now, scans = 0, 0
	local entries = {}
	local Board = loadModule("Board.luau", {
		game = {
			GetService = function(_, name)
				return if name == "Players" then { LocalPlayer = player } else {}
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		getreg = function()
			scans += 1
			return entries
		end,
		debug = {
			getupvalues = function(fn)
				return fn()
			end,
		},
	})
	local board = Board.new()
	assert(not board:getBoard() and scans == 1)
	local waiting = {
		processRound = function()
			return {}
		end,
	}
	local match = { activeTeam = true, players = { [true] = player }, whitePieces = {}, blackPieces = {} }
	local ready = {
		processRound = function()
			return {}
		end,
		currentMatch = match,
	}
	entries = {
		function()
			return { waiting }
		end,
		function()
			return { ready }
		end,
	}
	now = 0.5
	assert(not board:getBoard() and scans == 1)
	now = 1
	assert(board:getBoard() == match and board.client == ready and board:isPlayerTurn())
	assert(scans == 2)
	now = 2
	assert(board:getBoard() == match and scans == 2)
	-- A lobby client discovered at startup must also yield to the ranked client.
	board.client = waiting
	assert(board:getBoard() == match and board.client == ready and scans == 3)
end)

test("Board FEN uses mirrored files and team ownership is checked directly", function()
	local player = {}
	local Board = loadModule("Board.luau", {
		game = {
			GetService = function(_, name)
				return if name == "Players" then { LocalPlayer = player } else {}
			end,
		},
		getreg = function()
			return {}
		end,
		debug = {
			getupvalues = function()
				return {}
			end,
		},
		task = { wait = function() end },
	})
	local board = Board.new()
	local piece = {
		Name = "Pawn",
		position = { 4, 2 },
		team = true,
		getMoves = function()
			return { { 4, 4 } }
		end,
	}
	local clicks = 0
	board.client = {
		currentMatch = {
			whitePieces = { piece },
			blackPieces = {},
			activeTeam = true,
			players = { [true] = player, [false] = {} },
		},
		clickOnTile = function()
			clicks += 1
		end,
	}
	assert(board:board2fen() == "8/8/8/8/8/8/4P3/8 w - - 0 1")
	assert(board:autoMove({ 4, 2 }, { 4, 4 }))
	assert(clicks == 2)
	for _, rank in ipairs({ 1, 8 }) do
		assert(not board:autoMove({ 4, 2 }, { 4, rank }))
	end
	assert(clicks == 2)
	piece.team = false
	assert(not board:autoMove({ 4, 2 }, { 4, 4 }))
	assert(not board:autoMove({ 4, 2 }, { 4, 4 }, "n"))
end)

test("Reported checking positions serialize the match turn, including bot games", function()
	local visibleStatus = {
		Visible = true,
		IsA = function()
			return true
		end,
	}
	local gui = {
		FindFirstChild = function()
			return visibleStatus
		end,
	}
	local player = {
		FindFirstChild = function()
			return {
				FindFirstChild = function()
					return gui
				end,
			}
		end,
	}
	local Board = loadModule("Board.luau", {
		game = {
			GetService = function(_, name)
				return if name == "Players" then { LocalPlayer = player } else {}
			end,
		},
		getreg = function()
			return {}
		end,
		debug = {
			getupvalues = function()
				return {}
			end,
		},
	})
	local names = { p = "Pawn", n = "Knight", b = "Bishop", r = "Rook", q = "Queen", k = "King" }
	local placements = {
		"r3kb1r/p2Q1ppp/2Pp4/4p3/p3P1n1/P1NPB1Pq/1P3P1P/R3K2R",
		"r1b1kbnr/ppp2ppp/3p4/1B1Pp3/1n2P2q/2N1B3/PPP2PPP/R2QK1NR",
	}
	for _, placement in ipairs(placements) do
		local match =
			{ whitePieces = {}, blackPieces = {}, activeTeam = false, players = { [true] = player, [false] = {} } }
		local rank = 8
		for row in string.gmatch(placement, "[^/]+") do
			local file = 8
			for index = 1, #row do
				local symbol = string.sub(row, index, index)
				local empty = tonumber(symbol)
				if empty then
					file -= empty
				else
					local white = symbol == string.upper(symbol)
					table.insert(if white then match.whitePieces else match.blackPieces, {
						Name = names[string.lower(symbol)],
						team = white,
						position = { file, rank },
					})
					file -= 1
				end
			end
			rank -= 1
		end
		local board = Board.new()
		board.client = { currentMatch = match }
		assert(board:board2fen() == placement .. " b - - 0 1")
		assert(not board:isPlayerTurn() and board:willCauseDesync(), "Stale White GUI must not override Black's turn")
		match.players[false] = player -- The bot adapter records the same player in both seats.
		assert(board:isBotMatch())
		assert(board:board2fen() == placement .. " b - - 0 1")
		assert(not board:isPlayerTurn() and board:willCauseDesync())
		match.activeTeam = true
		assert(board:isPlayerTurn() and not board:willCauseDesync())
		visibleStatus.Visible = false
		assert(board:isPlayerTurn(), "A hidden GUI must not block the match turn")
		player.FindFirstChild = function()
			return nil
		end
		assert(board:isPlayerTurn(), "A missing GUI must not block the next turn")
		match.activeTeam = false
		match.players[true] = {} -- Also verify an actual Black player is allowed to analyze.
		assert(board:isPlayerTurn() and not board:willCauseDesync())
		match.activeTeam = nil
		assert(board:board2fen() == nil and not board:isPlayerTurn() and board:willCauseDesync())
	end
end)

-- These fixtures simulate the inferred game contract, not a verified live-game implementation.
local function promotionFixture(team, targetFile, withChooser)
	local player = {}
	local now, clicks = 0, 0
	local cancelled, throwOnDestination, applyPromotion = false, false, true
	local targetRank = if team then 8 else 1
	local from = { 4, if team then 7 else 2 }
	local destination = { targetFile or 4, targetRank }
	local move = { destination[1], destination[2], promote = { pieceName = nil } }
	local piece = { Name = "Pawn", team = team, position = from }
	local originalGetMoves = function()
		return { move }
	end
	piece.getMoves = originalGetMoves
	local promotionEnv = {}
	local originalChooser = function()
		error("The manual selector should not open")
	end
	if withChooser then
		promotionEnv.doPromotionInterface = originalChooser
	end
	local Board = loadModule("Board.luau", {
		getfenv = function()
			return promotionEnv
		end,
		dispatcherOverride = { run = function(action) return pcall(action) end },
		game = {
			GetService = function(_, name)
				return if name == "Players" then { LocalPlayer = player } else {}
			end,
		},
		getreg = function()
			return {}
		end,
		debug = {
			getupvalues = function()
				return {}
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		task = {
			wait = function(seconds)
				now += seconds
			end,
		},
	})
	local board = Board.new()
	board.client = {
		currentMatch = {
			whitePieces = if team then { piece } else {},
			blackPieces = if team then {} else { piece },
			activeTeam = team,
			players = { [team] = player, [not team] = {} },
		},
		clickOnTile = function(_, x, y)
			clicks += 1
			if clicks % 2 == 0 then
				if throwOnDestination then
					error("simulated destination failure")
				end
				if applyPromotion then
					local prepared = piece:getMoves()[1]
					if withChooser then
						local selectedPawn, selectedName = promotionEnv.doPromotionInterface(piece, prepared)
						assert(selectedPawn == piece, "The selector must also return the original pawn")
						prepared.promote.pieceName = selectedName
					end
					assert(prepared.promote and prepared.promote.pieceName)
					piece.Name = prepared.promote.pieceName
					piece.position = { x, y }
				end
			end
		end,
	}
	return {
		board = board,
		piece = piece,
		move = move,
		originalGetMoves = originalGetMoves,
		promotionEnv = promotionEnv,
		originalChooser = originalChooser,
		run = function(promotion)
			return board:autoMove(from, destination, promotion, function()
				return not cancelled
			end)
		end,
		clicks = function()
			return clicks
		end,
		cancel = function()
			cancelled = true
		end,
		fail = function()
			throwOnDestination = true
		end,
		timeout = function()
			applyPromotion = false
		end,
	}
end

test("Promotion selector returns the requested choice and is restored on success and failure", function()
	for _, suffix in ipairs({ "q", "r", "b", "n" }) do
		local fixture = promotionFixture(true, nil, true)
		assert(fixture.run(suffix))
		assert(fixture.promotionEnv.doPromotionInterface == fixture.originalChooser)
		assert(fixture.piece.getMoves == fixture.originalGetMoves)
	end
	local fixture = promotionFixture(false, nil, true)
	fixture.fail()
	assert(not fixture.run("n"))
	assert(fixture.promotionEnv.doPromotionInterface == fixture.originalChooser)
	assert(fixture.piece.getMoves == fixture.originalGetMoves)
end)

test("Promotion covers both colors, captures, and all four choices", function()
	local names = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }
	for _, team in ipairs({ true, false }) do
		for _, file in ipairs({ 3, 4, 5 }) do
			for suffix, name in pairs(names) do
				local fixture = promotionFixture(team, file)
				local success, message = fixture.run(suffix)
				assert(success and message == "Promotion confirmed: " .. name)
				assert(fixture.clicks() == 2 and fixture.piece.Name == name)
				assert(fixture.piece.getMoves == fixture.originalGetMoves)
				assert(fixture.move.promote.pieceName == nil, "Original game metadata was mutated")
			end
		end
	end
end)

test("Promotion failure and timeout restore the original move provider", function()
	local fixture = promotionFixture(true)
	fixture.fail()
	local success, message = fixture.run("q")
	assert(not success and string.find(message, "Tile click failed", 1, true))
	assert(fixture.piece.getMoves == fixture.originalGetMoves)
	fixture = promotionFixture(false)
	fixture.timeout()
	success, message = fixture.run("n")
	assert(not success and string.find(message, "not confirmed", 1, true))
	assert(fixture.clicks() == 2 and fixture.piece.getMoves == fixture.originalGetMoves)
end)

test("Missing promotion metadata and pre-click cancellation do not send moves", function()
	local fixture = promotionFixture(true)
	fixture.move.promote = nil
	assert(not fixture.run("q") and fixture.clicks() == 0)
	fixture = promotionFixture(false)
	fixture.cancel()
	assert(not fixture.run("q") and fixture.clicks() == 0)
end)

test("Promotion cancellation between clicks restores the hook", function()
	local fixture = promotionFixture(true)
	fixture.board.client.clickOnTile = function()
		fixture.cancel()
	end
	assert(not fixture.run("r"))
	assert(fixture.piece.getMoves == fixture.originalGetMoves)
end)

test("Unconfirmed promotion stops automation without retrying", function()
	local controller, board, server, _, options, step, _, messages = controllerFixture()
	options.autoExecute = true
	function server:findBestMove()
		self.calls += 1
		return { success = true, move = "a7a8q", promotion = "q", fen = board.fen, match = board.match }
	end
	function board:autoMove()
		return false, "Promotion was not confirmed"
	end
	local stopped = false
	controller.onAutomationStopped = function()
		stopped = true
	end
	controller:tick()
	step()
	assert(not options.autoCalculate and stopped and not controller.busy)
	assert(messages.instruction == "Promotion was not confirmed")
	controller:tick()
	step(4)
	assert(server.calls == 1)
end)

-- Compile every runtime module and both distributable bundles without executing remote code.
test("FEN preserves unmoved castling rights and current legal en-passant targets", function()
	local player = {}
	local Board = loadModule("Board.luau", {
		game = { GetService = function(_, name) return if name == "Players" then { LocalPlayer = player } else {} end },
		getreg = function() return {} end,
		debug = { getupvalues = function() return {} end },
	})
	local function piece(name, team, x, y)
		return { Name = name, team = team, position = { x, y }, unmoved = true, getMoves = function() return {} end }
	end
	local wk, wr, wq = piece("King", true, 4, 1), piece("Rook", true, 1, 1), piece("Rook", true, 8, 1)
	local bk, br, bq = piece("King", false, 4, 8), piece("Rook", false, 1, 8), piece("Rook", false, 8, 8)
	local pawn = piece("Pawn", true, 4, 5)
	local match = { activeTeam = true, players = { [true] = player }, whitePieces = { wk, wr, wq, pawn }, blackPieces = { bk, br, bq } }
	local board = Board.new()
	board.client = { currentMatch = match }
	assert(string.find(board:board2fen(), " w KQkq - ", 1, true))
	wr.unmoved = false -- A rook returning home must not regain its right.
	assert(string.find(board:board2fen(), " w Qkq - ", 1, true))
	wk.unmoved = false
	bq.position = nil -- Captured rook cannot grant a right.
	assert(string.find(board:board2fen(), " w k - ", 1, true))
	pawn.getMoves = function() return { { 5, 6, enpassant = { enemy = {} } } } end
	assert(string.find(board:board2fen(), " w k d6 ", 1, true))
	pawn.getMoves = function() return { { 5, 6 } } end
	assert(string.find(board:board2fen(), " w k - ", 1, true))
	match.activeTeam = false
	local blackPawn = piece("Pawn", false, 4, 4)
	blackPawn.getMoves = function() return { { 3, 3, enpassant = { enemy = {} } } } end
	table.insert(match.blackPieces, blackPawn)
	assert(string.find(board:board2fen(), " b k f3 ", 1, true))
	match.players[false] = player
	match.botInfo = { team = true }
	assert(board:getLocalTeam() == "b" and board:isPlayerTurn())
end)

test("Game dispatcher restores hooks before executing and cancels or expires without submission", function()
	local now, pending, restored, calls = 0, nil, 0, 0
	local pump = true
	local target = function() end
	local env = {
		game = { GetService = function() return { Heartbeat = {} } end },
		getconnections = function() return { { Function = target } } end,
		debug = { getconstants = function() return { "MovingPlatformsFolder" } end },
		isfunctionhooked = function() return false end,
		hookfunction = function(_, fn) pending = fn; return target end,
		restorefunction = function() pending = nil; restored += 1 end,
		os = { clock = function() return now end },
		task = { wait = function(seconds)
			now += seconds
			if pump and pending then pending() end
		end },
	}
	local D = loadModule("GameDispatcher.luau", env)
	local function action()
		assert(not pending, "Restore before running a potentially yielding tile handler")
		calls += 1
		return "submitted"
	end
	assert(D.run(action))
	assert(calls == 1 and restored == 1)
	local ok, reason = D.run(function() error("handler failure") end)
	assert(not ok and string.find(reason, "handler failure") and restored == 2)
	assert(not D.run(action, function() return false end))
	assert(calls == 1 and restored == 3)
	pump = false
	assert(not D.run(action))
	assert(calls == 1 and restored == 4 and not pending)
end)

test("All source files and bundles compile as Luau", function()
	for _, folder in ipairs({ "Modules", "Types", "UI" }) do
		for _, name in ipairs(fs.readDir("src/" .. folder)) do
			luau.compile(fs.readFile("src/" .. folder .. "/" .. name))
		end
	end
	luau.compile(fs.readFile("src/main.client.luau"))
	for _, name in ipairs({ "main.dev.lua", "main.lua" }) do
		local source = fs.readFile("dist/" .. name)
		luau.compile(source)
		assert(not string.find(source, 'require("./Modules/', 1, true))
	end
end)
local function uiEnvironment(placeId)
	local windows, created, queued, notices = {}, {}, {}, {}
	local shared = {}
	local methods = {
		CreateButton = true,
		CreateSlider = true,
		CreateToggle = true,
		CreateColorPicker = true,
		CreateDropdown = true,
		CreateSection = true,
		CreateText = true,
	}
	local saved = { AutoCalculate = true, RayfieldTheme = "cobalt", Depth = 23 }
	local library = {}
	function library:CreateWindow(props)
		assert(props.name and props.configuration.autoLoad and props.configuration.autoSave)
		assert(not props.ConfigurationSaving)
		local window = { controls = {}, flags = {}, props = props }
		function window:CreateTab(tabProps)
			assert(type(tabProps) == "table" and type(tabProps.name) == "string")
			local tab = {}
			function tab:CreateDivider() end
			function tab:CreateGroup()
				return self
			end
			for method in pairs(methods) do
				tab[method] = function(_, config)
					assert(type(config) == "table" and type(config.name) == "string")
					assert(not config.CurrentValue and not config.Callback and not config.CurrentOption)
					local control = { value = config.value or config.color, text = config.text, props = config }
					function control:Set(value, skipCallback)
						if method == "CreateText" then
							assert(type(value) == "string")
							self.text = value
						else
							self.value = value
							if config.callback and not skipCallback then
								config.callback(value)
							end
						end
					end
					window.controls[config.name] = control
					if config.flag then
						window.flags[config.flag] = control
					end
					if config.callback then
						if method == "CreateColorPicker" then
							config.callback(config.color, config.alpha)
						elseif config.flag then
							control:Set(saved[config.flag] or config.value)
						end
					end
					return control
				end
			end
			return tab
		end
		function window:ChangeTheme(theme)
			assert(type(theme) == "string")
			self.theme = theme
		end
		function window:Set(flag, value)
			self.flags[flag]:Set(value)
		end
		function window:Unload()
			self.unloaded = true
		end
		function window:Notify(props)
			table.insert(notices, props)
		end
		function window:Popup(props)
			window.popups = window.popups or {}
			table.insert(window.popups, props)
			return { Close = function() end }
		end
		table.insert(windows, window)
		return window
	end
	local world = {
		FindFirstChild = function()
			return nil
		end,
	}
	local player = {
		FindFirstChild = function()
			return nil
		end,
	}
	local services = {
		Players = { LocalPlayer = player },
		Workspace = world,
		HttpService = httpService,
		StarterGui = {
			SetCore = function(_, _, payload)
				notices.native = payload
			end,
		},
		TeleportService = {
			Teleport = function(_, id)
				notices.teleported = id
			end,
		},
	}
	local env = {
		game = {
			PlaceId = placeId,
			GetService = function(_, name)
				return services[name]
			end,
			HttpGet = function()
				error("Roblox HTTP must not be used")
			end,
		},
		workspace = world,
		getgenv = function()
			return shared
		end,
		getreg = function()
			return {}
		end,
		debug = {
			getupvalues = function()
				return {}
			end,
		},
		queue_on_teleport = function(source)
			table.insert(queued, source)
		end,
		request = function(request)
			if request.Url == "https://sirius.menu/gen2" then
				return { StatusCode = 200, Body = "return library" }
			end
			return { StatusCode = 200, Body = '{"ok":true,"protocol_revision":1,"engine":{"status":"ready"}}' }
		end,
		Color3 = {
			fromRGB = function(r, g, b)
				return { r = r, g = g, b = b }
			end,
		},
		task = { spawn = function(fn)
			shared.spawned = shared.spawned or {}
			table.insert(shared.spawned, fn)
		end, delay = function() end },
		Instance = {
			new = function(kind)
				local instance = {
					kind = kind,
					Destroy = function(self)
						self.destroyed = true
					end,
					ClearAllChildren = function() end,
				}
				table.insert(created, instance)
				return instance
			end,
		},
		loadstring = function(source)
			return luau.load(source, { environment = { library = library } })
		end,
	}
	return env, windows, created, queued, notices, shared
end

for _, file in ipairs({ "dist/main.dev.lua", "dist/main.lua" }) do
	test(file .. " incompatible-server popup has two actions and deduplicates", function()
		local env, windows, _, _, _, shared = uiEnvironment(6222531507)
		env.request = function(request)
			if request.Url == "https://sirius.menu/gen2" then
				return { StatusCode = 200, Body = "return library" }
			end
			return { StatusCode = 200, Body = '{"ok":true,"engine":{"status":"ready"}}' }
		end
		local copied
		local clipboardFails = false
		env.setclipboard = function(url)
			assert(not clipboardFails, "Clipboard access unavailable")
			copied = url
		end
		luau.load(fs.readFile(file), {environment = env})()
		shared.spawned[1]() -- startup compatibility check, without entering the polling loop
		local window = windows[1]
		local popup = window.popups[1]
		assert(popup.title == "Server update required" and #popup.options == 2)
		assert(popup.options[1].text == "Dismiss" and not popup.options[1].callback)
		popup.options[2].callback()
		assert(popup.options[2].text == "Copy release link")
		assert(copied == "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest")
		shared.spawned[1]()
		assert(#window.popups == 1)
		clipboardFails = true
		popup.options[2].callback()
		assert(window.popups[2].title == "Open the release page")
		assert(string.find(window.popups[2].content, "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest", 1, true))
	end)
	test(file .. " Gen2 UI, saved callbacks, reload and unload", function()
		local env, windows, created, queued, notices, shared = uiEnvironment(6222531507)
		local run = luau.load(fs.readFile(file), { environment = env })
		run()
		local window = windows[1]
		assert(window.theme == "cobalt" and window.flags.Depth.value == 23)
		assert(window.controls["Suggest move"] and window.controls["Play best move"])
		window.controls["Check connection"].props.callback()
		assert(notices[1].title == "Server connected")
		window.controls["Stop & clear"].props.callback()
		assert(window.flags.AutoCalculate.value == false)
		run()
		assert(window.unloaded and created[1].destroyed and #queued == 1)
		windows[2].controls["Close chess assistant"].props.callback()
		assert(windows[2].unloaded and shared.ChessClient.session == nil)
	end)
end
test("Polling recovers from a transient board-read failure without disabling Auto Play", function()
	local env, windows = uiEnvironment(6222531507)
	local poll, now = nil, 0
	env.os = {
		clock = function()
			return now
		end,
	}
	env.task.spawn = function(callback)
		poll = coroutine.create(callback)
	end
	env.task.wait = function()
		coroutine.yield()
	end
	local failed = false
	env.workspace.FindFirstChild = function()
		if not failed then
			failed = true
			error("board temporarily unavailable")
		end
		return nil
	end
	luau.load(fs.readFile("dist/main.lua"), { environment = env })()
	assert(poll)
	assert(coroutine.resume(poll))
	assert(windows[1].flags.AutoCalculate.value == true)
	assert(windows[1].controls.Status.text == "Waiting for the board to update")
	now = 3
	assert(coroutine.resume(poll))
	assert(windows[1].flags.AutoCalculate.value == true)
	assert(windows[1].controls["Auto Play"].text == "Waiting for a match")
	windows[1].controls["Close chess assistant"].props.callback()
	assert(coroutine.resume(poll))
end)

test("Wrong-game guard stops startup and Join queues re-execution", function()
	local env, windows, _, queued, notices = uiEnvironment(123)
	luau.load(fs.readFile("dist/main.lua"), { environment = env })()
	assert(#windows == 0 and notices.native.Button1 == "Join")
	notices.native.Callback.OnInvoke("Join")
	assert(notices.teleported == 6222531507 and #queued == 1)
end)

test("Incompatible servers cannot receive analysis; upgrading recovers", function()
	for _, revision in ipairs({ false, 0, 2, "1" }) do
		local notices, analyses = 0, 0
		local compatible = false
		local server = Server.new(function(request)
			if string.match(request.Url, "/status$") then
				local data = { ok = true, server_version = "2.0.0" }
				data.protocol_revision = if compatible then 1 else (if revision == false then nil else revision)
				return { StatusCode = 200, Body = serde.encode("json", data) }
			end
			analyses += 1
			return { StatusCode = 200, Body = '{"ok":true,"best_move":"e2e4"}' }
		end)
		server.onIncompatible = function() notices += 1 end
		local result = server:findBestMove(boardFixture(), {})
		assert(not result.success and result.code == "incompatible_server")
		assert(notices == 1 and analyses == 0)
		compatible = true
		assert(server:findBestMove(boardFixture(), {}).success)
		assert(analyses == 1)
	end
	assert(not Protocol.compatibilityError({protocol_revision = 1, server_version = "99.0.0"}))
end)

test("Teleport loader uses executor HTTP and rejects failed downloads", function()
	local queued
	local runtime = loadModule("Runtime.luau", {
		queue_on_teleport = function(source) queued = source end,
	})
	assert(runtime.queueTeleport({teleportQueued = false}, "https://example.com/main.lua"))
	local downloads, executions = 0, 0
	local status = 200
	local run = luau.load(queued, {environment = {
		request = function(input)
			assert(input.Url == "https://example.com/main.lua" and input.Method == "GET")
			downloads += 1
			return {StatusCode = status, Body = "client source"}
		end,
		loadstring = function(body)
			assert(body == "client source")
			return function() executions += 1 end
		end,
	}})
	run()
	assert(downloads == 1 and executions == 1)
	status = 503
	assert(not pcall(run) and executions == 1)
end)

print(`{passed} tests passed`)
