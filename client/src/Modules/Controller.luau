--!strict
local Types = require("../Types/Chess")
local Protocol = require("./Protocol")
local Controller = {}

local REQUEST_TIMEOUT_SECONDS = 130
local RETRY_DELAY_SECONDS = 3
local MOVE_CHECK_INTERVAL_SECONDS = 0.05
local PROMOTION_NAMES: { [Types.Promotion]: string } = { q = "Queen", r = "Rook", b = "Bishop", n = "Knight" }

export type Controller = {
	board: Types.Board,
	server: Types.Server,
	highlighter: Types.Highlighter,
	options: Types.Settings,
	emit: Types.Reporter,
	busy: boolean,
	destroyed: boolean,
	requestVersion: number,
	activeRequest: number?,
	requestPhase: string?,
	submittedMove: Types.MoveSuccess?,
	retryAfter: number,
	lastAnalyzedFen: string?,
	lastMatch: Types.Match?,
	highlightedFen: string?,
	automationStatus: string?,
	isAlive: (() -> boolean)?,
	onAutomationStopped: (() -> ())?,
	cancel: (self: Controller) -> (),
	run: (self: Controller, autoExecute: boolean, automatic: boolean) -> boolean,
	tick: (self: Controller) -> (),
	destroy: (self: Controller) -> (),
}

local function isRequestActive(self: Controller, version: number): boolean
	return not self.destroyed and self.requestVersion == version and (not self.isAlive or self.isAlive())
end

local function isPositionCurrent(
	self: Controller,
	result: Types.MoveSuccess,
	version: number,
	automatic: boolean
): boolean
	return isRequestActive(self, version)
		and (not automatic or self.options.autoCalculate)
		and self.board:isGameInProgress()
		and self.board:isPlayerTurn()
		and self.board:getBoard() == result.match
		and self.board:board2fen() == result.fen
		and not self.board:willCauseDesync()
end

local function stopAutomation(self: Controller): ()
	self.options.autoCalculate = false
	if self.onAutomationStopped then
		self.onAutomationStopped()
	end
end

--- A highlighted result is not a completed move. Permit another attempt when
--- execution was abandoned before submission, without retrying sent moves.
local function retryPosition(self: Controller): ()
	self.lastAnalyzedFen = nil
	self.retryAfter = os.clock() + RETRY_DELAY_SECONDS
end

local function executeMove(self: Controller, result: Types.MoveSuccess, version: number, automatic: boolean): ()
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

local function analyzePosition(self: Controller, version: number, autoExecute: boolean, automatic: boolean): ()
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
	board: Types.Board,
	server: Types.Server,
	highlighter: Types.Highlighter,
	options: Types.Settings,
	emit: Types.Reporter
): Controller
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
function Controller.cancel(self: Controller): ()
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

function Controller.run(self: Controller, autoExecute: boolean, automatic: boolean): boolean
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
		local success, problem = pcall(function(): boolean
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
function Controller.tick(self: Controller): ()
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
	local status = if not self.options.autoCalculate
		then "Inactive"
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

function Controller.destroy(self: Controller): ()
	self.destroyed = true
	self.requestVersion += 1
	self.highlighter:destroy()
end
return Controller
