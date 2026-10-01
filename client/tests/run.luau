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
	local server = Server.new(function()
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
	local server = Server.new(function()
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

test("Promotion hands off without clicking and resumes after manual play", function()
	for _, promotion in ipairs({ "q", "r", "b", "n" }) do
		local controller, board, server, _, options, step, _, messages = controllerFixture()
		options.autoExecute = true
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
local function promotionFixture(team, targetFile)
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

test("Experimental promotion covers both colors, captures, and all four choices", function()
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

test("Unconfirmed experimental promotion stops automation without retrying", function()
	local controller, board, server, _, options, step, _, messages = controllerFixture()
	options.autoExecute = true
	options.experimentalPromotion = true
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
			HttpGet = function(_, url)
				assert(url == "https://sirius.menu/gen2")
				return "return library"
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
		request = function()
			return { StatusCode = 200, Body = '{"ok":true,"engine":{"status":"ready"}}' }
		end,
		Color3 = {
			fromRGB = function(r, g, b)
				return { r = r, g = g, b = b }
			end,
		},
		task = { spawn = function() end, delay = function() end },
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

print(`{passed} tests passed`)
