local a = { cache = {} }
do
	do
		local function __modImpl()
			return {}
		end
		function a.a()
			local b = a.cache.a
			if not b then
				b = { c = __modImpl() }
				a.cache.a = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = game:GetService("Players")
			local c = game:GetService("Workspace")

			local d = b.LocalPlayer

			local e = debug

			local f = {}

			f.Pieces = {
				Pawn = "p",
				Knight = "n",
				Bishop = "b",
				Rook = "r",
				Queen = "q",
				King = "k",
			}

			local function samePosition(g, h)
				return g ~= nil and h ~= nil and g[1] == h[1] and g[2] == h[2]
			end

			local function getPieceAtPosition(g, h)
				for i, j in pairs(g.whitePieces or {}) do
					if j.position and samePosition(j.position, h) then
						return j
					end
				end

				for i, j in pairs(g.blackPieces or {}) do
					if j.position and samePosition(j.position, h) then
						return j
					end
				end

				return nil
			end

			local function findClient()
				local g = getreg or (debug and e.getregistry)
				if type(g) ~= "function" or type(e.getupvalues) ~= "function" then
					return nil
				end
				local h, i = pcall(g)
				if not h or type(i) ~= "table" then
					return nil
				end
				for j, k in pairs(i) do
					if type(k) == "function" and (not iscclosure or not iscclosure(k)) then
						local l, m = pcall(assert(e.getupvalues, "Executor upvalue inspection is unavailable"), k)
						for n, o in pairs(if l and type(m) == "table" then m else {}) do
							if type(o) == "table" and type(o.processRound) == "function" then
								return o
							end
						end
					end
				end

				return nil
			end

			function f.new()
				return {
					client = findClient(),
					refreshClient = f.refreshClient,
					getBoard = f.getBoard,
					isGameInProgress = f.isGameInProgress,
					isBotMatch = f.isBotMatch,
					getLocalTeam = f.getLocalTeam,
					isPlayerTurn = f.isPlayerTurn,
					willCauseDesync = f.willCauseDesync,
					getBoardPiece = f.getBoardPiece,
					createBoard = f.createBoard,
					board2fen = f.board2fen,
					hasLegalMove = f.hasLegalMove,
					autoMove = f.autoMove,
				}
			end

			function f.refreshClient(g)
				g.client = findClient()
				return g.client
			end

			function f.getBoard(g)
				if g.client and g.client.currentMatch then
					return g.client.currentMatch
				end

				if not (g.client and g.client.processRound) then
					return nil
				end

				local h = e.getupvalues
				if not h then
					return nil
				end
				local i, j = pcall(h, g.client.processRound)
				for k, l in pairs(if i and type(j) == "table" then j else {}) do
					if type(l) == "table" and l.tiles and l.boardExists then
						return l
					end
				end

				return nil
			end

			function f.isGameInProgress(g)
				local h = c:FindFirstChild("Board")
				return h ~= nil and #h:GetChildren() > 0
			end

			function f.isBotMatch(g)
				local h = g:getBoard()

				return h ~= nil and h.players ~= nil and h.players[true] == d and h.players[false] == d
			end

			function f.getLocalTeam(g)
				local h = g:getBoard()
				if not h then
					return nil
				end

				if g:isBotMatch() then
					return "w"
				end

				local i = h.players or {}
				for j, k in pairs(i) do
					if k == d then
						return if j then "w" else "b"
					end
				end

				return nil
			end

			function f.isPlayerTurn(g)
				local h = g:getLocalTeam()
				local i = g:getBoard()
				if not h or not i or type(i.activeTeam) ~= "boolean" then
					return false
				end

				return i.activeTeam == (h == "w")
			end

			function f.willCauseDesync(g)
				local h = g:getBoard()
				if not h then
					return true
				end

				local i = g:getLocalTeam()
				return i == nil or type(h.activeTeam) ~= "boolean" or h.activeTeam ~= (i == "w")
			end

			function f.getBoardPiece(g, h)
				local i = g:getBoard()
				if not i then
					return nil
				end

				return getPieceAtPosition(i, h)
			end

			function f.createBoard(g)
				local h = g:getBoard()
				if not h then
					return nil
				end

				local i = {}

				local function placePiece(j, k)
					if not (j and j.position and j.Name) then
						return
					end

					local l, m = j.position[1], j.position[2]
					local n = f.Pieces
					local o = n[j.Name]

					if not o then
						return
					end

					i[l] = i[l] or {}
					i[l][m] = k and string.upper(o) or o
				end

				for j, k in pairs(h.whitePieces or {}) do
					placePiece(k, true)
				end

				for j, k in pairs(h.blackPieces or {}) do
					placePiece(k, false)
				end

				return i
			end

			function f.board2fen(g)
				local h = g:getBoard()
				if not h or type(h.activeTeam) ~= "boolean" then
					return nil
				end
				local i = g:createBoard()
				if not i then
					return nil
				end

				local j = {}

				for k = 8, 1, -1 do
					local l = 0
					local m = {}

					for n = 8, 1, -1 do
						local o = i[n] and i[n][k]

						if o then
							if l > 0 then
								table.insert(m, tostring(l))
								l = 0
							end

							table.insert(m, o)
						else
							l += 1
						end
					end

					if l > 0 then
						table.insert(m, tostring(l))
					end

					table.insert(j, table.concat(m))
				end

				local k = if h.activeTeam then "w" else "b"

				return table.concat(j, "/") .. " " .. k .. " - - 0 1"
			end

			function f.hasLegalMove(g, h, i)
				if not (h and h.getMoves) then
					return false
				end

				for j, k in pairs(h:getMoves()) do
					if samePosition(k, i) then
						return true
					end
				end

				return false
			end

			function f.autoMove(g, h, i, j, k, l, m)
				if k and not k() then
					return false, "The position changed."
				end
				local n = g.client
				local o = g:getBoard()

				if not n then
					return false, "Client not found"
				end

				if not o then
					return false, "Board not found"
				end

				if g:isBotMatch() then
					return false, "AutoMove disabled in bot matches"
				end

				if not n.clickOnTile then
					return false, "clickOnTile not found"
				end

				if g:willCauseDesync() then
					return false, "Not safe to move right now"
				end

				local p = getPieceAtPosition(o, h)
				if not p then
					return false, "No piece at source"
				end

				if not j and p.Name == "Pawn" and (i[2] == 1 or i[2] == 8) then
					return false, "Play this promotion manually and choose the promotion piece."
				end

				if p.team ~= o.activeTeam then
					return false, "Piece is not active team"
				end

				if not g:hasLegalMove(p, i) then
					return false, "Illegal move"
				end

				local q = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }
				local r = if j then q[j] else nil
				local s = p.getMoves
				local t
				if r then
					if p.Name ~= "Pawn" or (i[2] ~= 1 and i[2] ~= 8) then
						return false, "Promotion metadata does not match a pawn reaching the last rank."
					end
					local u = false
					for v, w in pairs(p:getMoves()) do
						if samePosition(w, i) and w.promote then
							u = true
						end
					end
					if not u then
						return false,
							"Promotion experiment stopped: the legal move has no promote metadata. Play manually."
					end

					t = function(v)
						local w = {}
						for x, y in pairs(s(v)) do
							if samePosition(y, i) and y.promote then
								local z = table.clone(y)
								z.promote = table.clone(y.promote)
								assert(z.promote, "Promotion metadata disappeared")
								z.promote.pieceName = r
								table.insert(w, z)
							else
								table.insert(w, y)
							end
						end
						return w
					end
					p.getMoves = assert(t, "Promotion move provider was not prepared")
				end

				local u, v = pcall(function()
					local u = assert(n.clickOnTile, "The game tile handler is unavailable")
					u(n, h[1], h[2])
					task.wait(0.15)
					if k and not k() then
						return "Move cancelled before the destination click."
					end
					if m then
						m()
					end
					u(n, i[1], i[2])
					return "Move attempted"
				end)
				if t and p.getMoves == t then
					p.getMoves = s
				end
				if not u then
					return false, "Tile click failed: " .. tostring(v)
				end
				if v ~= "Move attempted" then
					return false, tostring(v)
				end
				if not r then
					return true, "Move attempted"
				end

				local w = os.clock() + 3
				repeat
					if (l and l()) or g:getBoard() ~= o then
						return false, "Promotion verification cancelled. Check the game before retrying."
					end
					local x = g:getBoardPiece(i)
					if x and x.team == p.team and x.Name ~= "Pawn" then
						if x.Name == r then
							return true, "Promotion confirmed: " .. r
						end
						return false,
							"Promotion produced "
								.. x.Name
								.. " instead of "
								.. r
								.. ". Disable Experimental promotion."
					end
					task.wait(0.1)
				until os.clock() >= w
				return false,
					"Promotion was not confirmed. Check the selector or board, and disable Experimental promotion before retrying."
			end

			return f
		end
		function a.b()
			local b = a.cache.b
			if not b then
				b = { c = __modImpl() }
				a.cache.b = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = {}

			function b.parseMove(c)
				if type(c) ~= "string" or not string.match(c, "^[a-h][1-8][a-h][1-8][qrbn]?$") then
					return nil, "The engine did not return a playable move."
				end
				return {
					fromPos = { 105 - string.byte(c, 1), assert(tonumber(string.sub(c, 2, 2))) },
					toPos = { 105 - string.byte(c, 3), assert(tonumber(string.sub(c, 4, 4))) },
					promotion = if #c == 5 then (string.sub(c, 5, 5)) else nil,
				},
					nil
			end

			function b.decodeResponse(c, d)
				if type(c) ~= "table" then
					return nil, "The HTTP function returned an invalid response.", nil
				end
				local e = c
				local f = e.Body
				if type(f) ~= "string" or f == "" then
					return nil, "The server returned an empty response.", nil
				end
				local g, h = pcall(d, f)
				if not g or type(h) ~= "table" then
					return nil, "The server returned invalid JSON. Check that the chess server is running.", nil
				end
				local i = h
				if i.ok == false and type(i.error) == "table" then
					local j = i.error
					return nil,
						tostring(j.message or "The server rejected the request."),
						if type(j.code) == "string" then j.code else nil
				end
				local j = tonumber(e.StatusCode)
				if e.Success == false or not j or j < 200 or j >= 300 then
					return nil, `Server request failed (HTTP {tostring(e.StatusCode)}).`, nil
				end
				if i.ok ~= true then
					return nil, "The server response is missing its success status.", nil
				end
				return i, nil, nil
			end

			function b.delayMs(c, d, e)
				local f = if d and c then c.recommended_delay_ms else e
				if type(f) ~= "number" or f ~= f or math.abs(f) == math.huge then
					f = e
				end
				return math.clamp(f, 0, 120000)
			end
			return b
		end
		function a.c()
			local b = a.cache.c
			if not b then
				b = { c = __modImpl() }
				a.cache.c = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = game:GetService("HttpService")
			local c = a.c()

			local d = {}
			d.API_BASE_URL = "http://127.0.0.1:57250/api/v1"

			function d.new(e)
				return { request = e, call = d.call, findBestMove = d.findBestMove }
			end

			function d.call(e, f, g)
				local h = e.request
				if not h then
					return nil, "Your executor does not provide an HTTP request function.", nil
				end
				local i, j = pcall(function()
					return h({
						Url = d.API_BASE_URL .. f,
						Method = if g then "POST" else "GET",
						Headers = { ["Content-Type"] = "application/json" },
						Body = if g then b:JSONEncode(g) else nil,
					})
				end)
				if not i then
					return nil,
						"Cannot reach the chess server. Open the desktop app and try again. " .. tostring(j),
						nil
				end
				return c.decodeResponse(j, function(k)
					return b:JSONDecode(k)
				end)
			end

			function d.findBestMove(e, f, g)
				local function fail(h, i)
					return { success = false, reason = h or "Unknown server error", code = i }
				end
				if not f:isGameInProgress() then
					return fail("Join a chess match first.")
				end
				if not f:isPlayerTurn() then
					return fail("Wait for your turn.")
				end
				if f:willCauseDesync() then
					return fail("The board is still updating. Try again shortly.")
				end
				local h = f:getBoard()
				local i = f:board2fen()
				if not i or not h then
					return fail("Could not read the board. Try Refresh board.")
				end
				local j, k, l = e:call("/analyze", {
					fen = i,
					depth = g.depth,
					max_think_time_ms = g.thinkTime,
					disregard_think_time = g.disregardTime,
				})
				if not j then
					return fail(k, l)
				end
				if f:getBoard() ~= h or not f:isPlayerTurn() or f:board2fen() ~= i then
					return fail("The position changed while the engine was thinking.", "stale_position")
				end
				local m, n = c.parseMove(j.best_move)
				if not m then
					return fail(n)
				end
				local o = f:getBoardPiece(m.fromPos)
				if not o or not f:hasLegalMove(o, m.toPos) then
					return fail("The engine move is no longer legal. Refresh the board and try again.")
				end
				local p = workspace:FindFirstChild("Board")

				local q = p and p:FindFirstChild(table.concat(m.fromPos, ","))
				local r = p and p:FindFirstChild(table.concat(m.toPos, ","))
				if not q or not r then
					return fail("Could not find the move's tiles in the game.")
				end

				local s
				if type(j.difficulty) == "table" then
					local t = j.difficulty
					if type(t.recommended_delay_ms) == "number" then
						s = { recommended_delay_ms = t.recommended_delay_ms }
					end
				end
				local t = j.best_move
				return {
					success = true,
					best_move = t,
					move = t,
					piece = q,
					destination = r,
					fromPos = m.fromPos,
					toPos = m.toPos,
					promotion = m.promotion,
					fen = i,
					match = h,
					difficulty = s,
				}
			end

			return d
		end
		function a.d()
			local b = a.cache.d
			if not b then
				b = { c = __modImpl() }
				a.cache.d = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = {}

			function b.new()
				local c = Instance.new("Folder")
				c.Name = "ChessMoveHighlights"
				c.Parent = workspace
				return { folder = c, clear = b.clear, show = b.show, destroy = b.destroy }
			end

			function b.clear(c)
				c.folder:ClearAllChildren()
			end

			function b.show(c, d, e, f)
				c:clear()
				for g, h in ipairs({ d, e }) do
					local i = Instance.new("Highlight")
					i.Adornee = h
					i.FillColor = f.fillColor
					i.OutlineColor = f.outlineColor
					i.FillTransparency = f.fillTransparency
					i.OutlineTransparency = f.outlineTransparency
					i.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					i.Parent = c.folder
				end
			end

			function b.destroy(c)
				c.folder:Destroy()
			end

			return b
		end
		function a.e()
			local b = a.cache.e
			if not b then
				b = { c = __modImpl() }
				a.cache.e = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = a.c()
			local c = {}

			local d = 130
			local e = 3
			local f = 0.05
			local g = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }

			local function isRequestActive(h, i)
				return not h.destroyed and h.requestVersion == i and (not h.isAlive or h.isAlive())
			end

			local function isPositionCurrent(h, i, j, k)
				return isRequestActive(h, j)
					and (not k or h.options.autoCalculate)
					and h.board:isGameInProgress()
					and h.board:isPlayerTurn()
					and h.board:getBoard() == i.match
					and h.board:board2fen() == i.fen
					and not h.board:willCauseDesync()
			end

			local function stopAutomation(h)
				h.options.autoCalculate = false
				if h.onAutomationStopped then
					h.onAutomationStopped()
				end
			end

			local function retryPosition(h)
				h.lastAnalyzedFen = nil
				h.retryAfter = os.clock() + e
			end

			local function executeMove(h, i, j, k)
				if h.board:isBotMatch() then
					h.emit("output", `Best move: {i.move}. Auto execute is disabled in bot matches.`)
					return
				end
				local l = b.delayMs(i.difficulty, h.options.useCalculatedDelay, h.options.executeDelay)
				h.emit("status", `Waiting {l} ms before moving…`)
				h.requestPhase = "Waiting before moving…"
				local m = os.clock() + l / 1000
				repeat
					if not isPositionCurrent(h, i, j, k) then
						if isRequestActive(h, j) then
							retryPosition(h)
						end
						return
					end
					if os.clock() >= m then
						break
					end
					task.wait(f)
				until false

				h.requestPhase = "Selecting the piece…"
				local n, o = h.board:autoMove(i.fromPos, i.toPos, i.promotion, function()
					return isPositionCurrent(h, i, j, k)
				end, function()
					return not isRequestActive(h, j)
				end, function()
					if isRequestActive(h, j) then
						h.submittedMove = i
						h.requestPhase = "Waiting for the game to finish the move…"
					end
				end)
				if not isRequestActive(h, j) then
					return
				end
				if n then
					h.emit("status", if i.promotion then "Promotion confirmed" else "Move sent")
					h.emit("output", o)
				elseif i.promotion then
					stopAutomation(h)
					h.emit("status", "Promotion needs attention; Auto Play stopped")
					h.emit("instruction", o)
				else
					retryPosition(h)
					h.emit("status", "Move highlighted")
					h.emit("output", `Best move: {i.move}. {o}`)
				end
			end

			local function analyzePosition(h, i, j, k)
				if not isRequestActive(h, i) then
					return
				end
				local l = h.server:findBestMove(h.board, table.clone(h.options))
				if not isRequestActive(h, i) then
					return
				end
				if not l.success then
					h.emit("output", l.reason)
					h.emit("status", "Needs attention")
					h.retryAfter = os.clock() + e
					return
				end
				if not isPositionCurrent(h, l, i, k) then
					return
				end

				h.highlighter:show(l.piece, l.destination, h.options)
				h.highlightedFen = l.fen
				h.lastAnalyzedFen = l.fen
				h.lastMatch = l.match
				if l.promotion and (not j or not h.options.experimentalPromotion) then
					h.emit("status", "Promotion: manual move required")
					h.emit(
						"instruction",
						`Play {l.move} manually and choose {g[l.promotion]}. Auto Play will resume after the position changes.`
					)
					return
				end
				h.emit("output", `Best move: {l.move}`)
				h.emit("status", "Move highlighted")
				if j then
					executeMove(h, l, i, k)
				end
			end

			function c.new(h, i, j, k, l)
				return {
					board = h,
					server = i,
					highlighter = j,
					options = k,
					emit = l,
					busy = false,
					destroyed = false,
					requestVersion = 0,
					retryAfter = 0,
					cancel = c.cancel,
					run = c.run,
					tick = c.tick,
					destroy = c.destroy,
				}
			end

			function c.cancel(h)
				h.requestVersion += 1
				h.busy = false
				h.activeRequest = nil
				h.requestPhase = nil
				h.submittedMove = nil
				h.lastAnalyzedFen = nil
				h.lastMatch = nil
				h.highlightedFen = nil
				h.highlighter:clear()
				if not h.destroyed then
					h.emit("status", "Idle")
				end
			end

			function c.run(h, i, j)
				if h.busy or h.destroyed then
					return false
				end
				h.busy = true
				h.requestVersion += 1
				local k = h.requestVersion
				h.activeRequest = k
				h.requestPhase = "Calculating with Stockfish…"
				h.submittedMove = nil
				h.emit("status", "Calculating…")

				task.delay(d, function()
					if not isRequestActive(h, k) or h.activeRequest ~= k or not h.busy then
						return
					end
					h:cancel()
					h.retryAfter = os.clock() + e
					h.emit("status", "Request timed out")
					h.emit("output", "The server took too long to respond. Check the desktop app and retry.")
				end)
				task.spawn(function()
					local l, m = pcall(function()
						analyzePosition(h, k, i, j)
						return true
					end)
					if not l and isRequestActive(h, k) then
						retryPosition(h)
						h.emit("status", "Needs attention")
						h.emit("output", tostring(m))
						h.retryAfter = os.clock() + e
					end

					if h.activeRequest == k then
						h.busy = false
						h.activeRequest = nil
						h.requestPhase = nil
						h.submittedMove = nil
					end
				end)
				return true
			end

			function c.tick(h)
				if h.destroyed then
					return
				end
				local i = h.board:isGameInProgress()
				local j = i and h.board:isPlayerTurn()
				local k = if j then h.board:board2fen() else nil
				local l = h.board:getBoard()
				local m = h.submittedMove
				if h.busy and m and not m.promotion then
					local n = if i then h.board:board2fen() else nil
					if l ~= m.match or (n ~= nil and n ~= m.fen) then
						h.requestVersion += 1
						h.activeRequest = nil
						h.busy = false
						h.submittedMove = nil
						h.requestPhase = nil
						h.emit("status", "Board updated; ready for the next turn")
					end
				end
				if h.highlightedFen and (k ~= h.highlightedFen or l ~= h.lastMatch) then
					h.highlighter:clear()
					h.highlightedFen = nil
				end
				if not j then
					h.lastAnalyzedFen = nil
				end
				local n = if i and h.board:isBotMatch()
					then "⚠ Bot match detected — automatic moves unavailable. Suggestions still work."
					elseif not h.options.autoCalculate then "Inactive"
					elseif not i then "Waiting for a match"
					elseif not j then "Waiting for your turn"
					elseif h.busy then h.requestPhase or "Calculating or moving…"
					else "Waiting for your move"
				if n ~= h.automationStatus then
					h.emit("auto", n)
					h.automationStatus = n
				end
				if
					h.options.autoCalculate
					and j
					and k
					and not h.busy
					and os.clock() >= h.retryAfter
					and (k ~= h.lastAnalyzedFen or l ~= h.lastMatch)
				then
					h:run(h.options.autoExecute, true)
				end
			end

			function c.destroy(h)
				h.destroyed = true
				h.requestVersion += 1
				h.highlighter:destroy()
			end
			return c
		end
		function a.f()
			local b = a.cache.f
			if not b then
				b = { c = __modImpl() }
				a.cache.f = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			return {}
		end
		function a.g()
			local b = a.cache.g
			if not b then
				b = { c = __modImpl() }
				a.cache.g = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()
			a.g()
			a.f()

			local b = {}

			function b.build(c)
				local d = c.window
				local e = c.mainTab
				local f = c.engineTab
				local g = c.autoTab
				local h = c.themeTab
				local i = c.options
				local j = c.controller
				local k = c.board
				local l = c.server
				local m = c.session
				local n = c.emit
				local o = c.clearOutput

				local function run(p)
					if not j:run(p, false) then
						d:Notify({ title = "Already working", content = "Wait for the current request or cancel it first." })
					end
				end

				e:CreateSection({ name = "Your next move" })
				local p = e:CreateGroup({ direction = "row" })
				p:CreateButton({
					name = "Suggest move",
					callback = function()
						run(false)
					end,
				})
				p:CreateButton({
					name = "Play best move",
					callback = function()
						run(true)
					end,
				})
				e:CreateButton({
					name = "Stop & clear",
					description = "Cancel pending moves, stop Auto Play, and clear highlights.",
					callback = function()
						d:Set("AutoCalculate", false)
						j:cancel()
						o()
					end,
				})
				e:CreateText({
					name = "How to play",
					text = "Suggest move marks the two squares. Play best move calculates and clicks for you. Open Auto Play to repeat this on every turn.",
				})
				e:CreateSection({ name = "Connection" })
				local q = e:CreateText({
					name = "Desktop server",
					text = "Not checked. Open the desktop app, then check the connection.",
				})
				local r = false
				e:CreateButton({
					name = "Check connection",
					callback = function()
						if r then
							return
						end
						r = true
						q:Set("Checking the desktop server…")
						local s, t = l:call("/status")
						r = false
						if m.stopped or d.unloaded then
							return
						end
						local u = s and s.engine
						local v = if type(u) == "table" then tostring((u).status or "unknown") else "unknown"
						q:Set(
							if s
								then (if v == "ready"
									then "Connected · Stockfish is ready"
									else `Connected · Engine: {v}`)
								else "Offline · Open the desktop app and try again."
						)
						d:Notify({
							title = if s then "Server connected" else "Connection failed",
							content = if type(u) == "table"
								then `Engine: {tostring((u).status or "unknown")}`
								else t or "Server responded.",
						})
					end,
				})
				f:CreateSection({ name = "Search strength" })
				f:CreateSlider({
					name = "Search depth",
					description = "Higher depth searches further when time allows.",
					range = { 1, 40 },
					increment = 1,
					value = 17,
					flag = "Depth",
					callback = function(s)
						i.depth = s
					end,
				})
				f:CreateSlider({
					name = "Time per suggestion",
					range = { 10, 5000 },
					increment = 10,
					suffix = "ms",
					value = 100,
					flag = "MaxThinkTime",
					callback = function(s)
						i.thinkTime = s
					end,
				})
				f:CreateToggle({
					name = "Search until depth is reached",
					description = "Ignore the time limit. Deep searches can take longer.",
					value = false,
					flag = "DisregardThinkTime",
					callback = function(s)
						i.disregardTime = s
					end,
				})

				f:CreateSection({ name = "Troubleshooting" })
				f:CreateButton({
					name = "Reconnect to board",
					description = "Try this if the board cannot be read after joining a match.",
					callback = function()
						j:cancel()
						k:refreshClient()
						n(
							"output",
							if k.client
								then "Board client found."
								else "Board client not found. Check executor support and join a match."
						)
					end,
				})
				f:CreateButton({ name = "Close chess assistant", callback = m.cleanup })

				g:CreateSection({ name = "Automation" })
				g:CreateText({
					name = "⚠ Auto Play limitations",
					text = "Bot matches: automatic moves are unavailable.\nCastling & en passant: play these moves manually.\nPromotion: promote the pawn manually.",
				})

				g:CreateDivider()

				local s = g:CreateToggle({
					name = "Auto calculate",
					flag = "AutoCalculate",
					value = false,
					description = "Keep suggestions up to date whenever your turn begins. Does not move pieces on its own.",
					callback = function(s)
						i.autoCalculate = s
						j:cancel()
					end,
				})
				g:CreateToggle({
					name = "Auto execute move",
					flag = "AutoExecute",
					value = false,
					description = "Play suggestions automatically when Auto calculate is on.",
					callback = function(t)
						i.autoExecute = t
						j:cancel()
					end,
				})

				g:CreateSection({ name = "Timing" })
				g:CreateSlider({
					name = "Pause before moving",
					range = { 0, 3000 },
					increment = 50,
					suffix = "ms",
					value = 300,
					flag = "ExecuteDelay",
					callback = function(t)
						i.executeDelay = t
					end,
				})
				g:CreateToggle({
					name = "Use suggested pause",
					flag = "UseCalculatedDelay",
					value = false,
					description = "Use the server's timing when available; otherwise use the pause above. (VERY experimental, don't recommend)",
					callback = function(t)
						i.useCalculatedDelay = t
					end,
				})

				h:CreateSection({ name = "Look & feel" })
				h:CreateDropdown({
					name = "Theme",
					options = { "Default", "Cobalt", "Ember", "Amethyst", "Frost", "Rose" },
					value = "cobalt",
					flag = "RayfieldTheme",
					callback = function(t)
						d:ChangeTheme((string.lower(t)))
					end,
				})

				h:CreateSection({ name = "Highlight colors" })
				h:CreateColorPicker({
					name = "Highlight fill",
					color = i.fillColor,
					alpha = 0.5,
					flag = "HighlightFillColor",
					callback = function(t, u)
						i.fillColor = t
						i.fillTransparency = 1 - u
					end,
				})
				h:CreateColorPicker({
					name = "Highlight outline",
					color = i.outlineColor,
					alpha = 1,
					flag = "HighlightOutlineColor",
					callback = function(t, u)
						i.outlineColor = t
						i.outlineTransparency = 1 - u
					end,
				})

				j.onAutomationStopped = function()
					s:Set(false, true)
				end
			end
			return b
		end
		function a.h()
			local b = a.cache.h
			if not b then
				b = { c = __modImpl() }
				a.cache.h = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()
			a.g()

			local b = {}

			function b.new(c, d, e)
				local f = c:CreateText({ name = "Status", text = "Ready when you are" })
				local g =
					c:CreateText({ name = "Suggested move", text = "Join a match, then choose Suggest move below." })
				local h = d:CreateText({ name = "Auto Play", text = "Off · Enable Auto calculate to begin" })
				local function clearOutput()
					g:Set("No move selected. Choose Suggest move to analyze the board.")
				end
				local function report(i, j)
					if not e() then
						return
					end
					if i == "auto" then
						h:Set(if j == "Inactive" then "Off · Enable Auto calculate to begin" else j)
					elseif i == "status" then
						f:Set(if j == "Idle" then "Ready when you are" else j)
					else
						if j == "Move attempted" then
							return
						end
						local k = string.gsub(j, "Best move: ([a-h][1-8])([a-h][1-8])", "%1 → %2", 1)
						g:Set(k)
					end
				end
				return { report = report, clearOutput = clearOutput }
			end
			return b
		end
		function a.i()
			local b = a.cache.i
			if not b then
				b = { c = __modImpl() }
				a.cache.i = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = {}

			function b.getState()
				assert(type(getgenv) == "function", "This client requires getgenv().")
				local c = (getgenv())
				if not c.ChessClient then
					c.ChessClient = { teleportQueued = false }
				end
				return c.ChessClient
			end

			function b.getRequest()
				return request or http_request or (syn and syn.request) or (http and http.request)
			end

			function b.queueTeleport(c, d)
				if c.teleportQueued then
					return true
				end
				local e = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
				if not e then
					return false
				end
				local f = pcall(e, `loadstring(game:HttpGet("{d}"))()`)
				c.teleportQueued = f
				return f
			end
			return b
		end
		function a.j()
			local b = a.cache.j
			if not b then
				b = { c = __modImpl() }
				a.cache.j = b
			end
			return b.c
		end
	end
	do
		local function __modImpl()
			a.a()

			local b = {}
			function b.defaults()
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
			return b
		end
		function a.k()
			local b = a.cache.k
			if not b then
				b = { c = __modImpl() }
				a.cache.k = b
			end
			return b.c
		end
	end
end

local b = a.b()
local c = a.d()
local d = a.e()
local e = a.f()

local f = 6222531507
local g = "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"
local h = a.h()
local i = a.i()
local j = a.j()
local k = a.k()
a.a()
a.g()

local l = j.getState()
local m = j.getRequest()

local function queueRejoin()
	return j.queueTeleport(l, g)
end

if game.PlaceId ~= f then
	local n = Instance.new("BindableFunction")
	n.OnInvoke = function(o)
		if o == "Join" then
			queueRejoin()
			game:GetService("TeleportService"):Teleport(f)
		end
	end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Chess by Haloxx",
			Text = "Open the supported CHESS game to use this script.",
			Button1 = "Join",
			Duration = 10,
			Callback = n,
		})
	end)
	task.delay(15, function()
		n:Destroy()
	end)
	return
end

local n, o = pcall(function()
	local n = game
	local o = n.HttpGet(game, "https://sirius.menu/gen2")
	local p, q = loadstring(o)
	assert(p, q)
	return p()
end)
if not n then
	warn("Could not load Rayfield Gen2: " .. tostring(o))
	return
end

if l.session then
	l.session.cleanup()
end

local p = k.defaults()
local q = o
local r = q:CreateWindow({
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

local s = r:CreateTab({ name = "🏠 Play" })
local t = r:CreateTab({ name = "▶ Auto Play" })
local u = r:CreateTab({ name = "⚙ Engine" })
local v = r:CreateTab({ name = "🎨 Appearance" })
local w = b.new()
local x = c.new(m)
local y = d.new()
local z = { stopped = false, cleanup = function() end }
local A = i.new(s, t, function()
	return not z.stopped and not r.unloaded
end)
local B = A.report

local C = e.new(w, x, y, p, B)
C.isAlive = function()
	return not z.stopped and not r.unloaded
end
function z.cleanup()
	if z.stopped then
		return
	end
	z.stopped = true
	C:destroy()
	if not r.unloaded then
		r:Unload()
	end
	if l.session == z then
		l.session = nil
	end
end
l.session = z

h.build({
	window = r,
	mainTab = s,
	engineTab = u,
	autoTab = t,
	themeTab = v,
	options = p,
	controller = C,
	board = w,
	server = x,
	session = z,
	emit = B,
	clearOutput = A.clearOutput,
})

if not queueRejoin() then
	s:CreateText({
		name = "Rejoin support unavailable",
		text = "Run this script again after teleporting or rejoining.",
	})
end
if not w.client then
	B(
		"output",
		"Board client not found. Join a match and use Refresh board. Your executor needs getreg and debug.getupvalues."
	)
end
if type(m) ~= "function" then
	B("output", "Your executor needs request or http_request to connect to the desktop server.")
end

task.spawn(function()
	local D = 0
	while not z.stopped and not r.unloaded do
		if os.clock() >= D then
			local E, F = pcall(function()
				C:tick()
			end)
			if not E then
				D = os.clock() + 3
				B("status", "Waiting for the board to update")
				B("output", "Board read failed; retrying shortly. " .. tostring(F))
			end
		end
		task.wait(0.2)
	end
	z.cleanup()
end)
