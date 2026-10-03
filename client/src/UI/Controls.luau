--!strict
local Types = require("../Types/Chess")
local RayfieldTypes = require("../Types/Rayfield")
local ControllerTypes = require("../Modules/Controller")
local Controls = {}

--- Build controls after the controller exists, because saved values invoke callbacks immediately.
export type Context = {
	window: RayfieldTypes.Window,
	mainTab: RayfieldTypes.Tab,
	engineTab: RayfieldTypes.Tab,
	autoTab: RayfieldTypes.Tab,
	themeTab: RayfieldTypes.Tab,
	options: Types.Settings,
	controller: ControllerTypes.Controller,
	board: Types.Board,
	server: Types.Server,
	session: Types.Session,
	emit: Types.Reporter,
	clearOutput: () -> (),
}

function Controls.build(context: Context): ()
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

	local function run(autoExecute: boolean): ()
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
				then tostring((engine :: { [string]: unknown }).status or "unknown")
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
					then `Engine: {tostring((engine :: { [string]: unknown }).status or "unknown")}`
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
		callback = function(value: string)
			window:ChangeTheme(string.lower(value) :: RayfieldTypes.ThemeName)
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
