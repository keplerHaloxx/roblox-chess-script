--!strict
-- Native Luau entry point. Bundle with Darklua before executing.
local Board = require("./Modules/Board")
local ChessServer = require("./Modules/ChessServer")
local Highlighter = require("./Modules/Highlighter")
local Controller = require("./Modules/Controller")

local CHESS_PLACE_ID = 6222531507
local SCRIPT_URL = "https://github.com/keplerHaloxx/roblox-chess-script/releases/latest/download/main.lua"
local Controls = require("./UI/Controls")
local StatusView = require("./UI/StatusView")
local Runtime = require("./Modules/Runtime")
local Settings = require("./Modules/Settings")
local Types = require("./Types/Chess")
local RayfieldTypes = require("./Types/Rayfield")
local runtimeState = Runtime.getState()
local httpRequest = Runtime.getRequest()

local function queueRejoin(): boolean
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
	assert(httpRequest, "Your executor needs request or http_request to download the UI.")
	local response = httpRequest({ Url = "https://sirius.menu/gen2", Method = "GET", Headers = {} })
	assert(type(response) == "table", "The UI download returned an invalid response.")
	local envelope = response :: { [string]: unknown }
	local status = tonumber(envelope.StatusCode)
	assert(envelope.Success ~= false and status and status >= 200 and status < 300, "The UI download failed.")
	local source = envelope.Body
	assert(type(source) == "string" and source ~= "", "The UI download returned an empty response.")
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
local library = Rayfield :: RayfieldTypes.Library
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
local warnedAboutCompatibility = false
server.onIncompatible = function(message: string)
	if warnedAboutCompatibility or window.unloaded then
		return
	end
	warnedAboutCompatibility = true
	local popup: RayfieldTypes.PopupProps = {
		title = "Server update required",
		content = message,
		options = {
			{ text = "Dismiss" },
			{
				text = "Copy release link",
				callback = function()
					local ok = pcall(function()
						assert(setclipboard, "Clipboard access unavailable")
						setclipboard("https://github.com/keplerHaloxx/roblox-chess-script/releases/latest")
					end)
					if ok then
						window:Notify({
							title = "Release link copied",
							content = "Paste it into your browser to download the latest server.",
						})
					else
						window:Popup({
							title = "Open the release page",
							content = "Your executor could not copy the link. Open this address:\nhttps://github.com/keplerHaloxx/roblox-chess-script/releases/latest",
							options = { { text = "Dismiss" } },
						})
					end
				end,
			},
		},
	}
	window:Popup(popup)
end
local highlighter = Highlighter.new()
local session: Types.Session = { stopped = false, cleanup = function() end }
local statusView = StatusView.new(mainTab, autoTab, function(): boolean
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

task.spawn(function()
	local _, reason = server:call("/status")
	if reason and not session.stopped then
		emit("output", reason)
	end
end)

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
		"Waiting for the board client to load; reconnecting automatically. Your executor needs getreg and debug.getupvalues."
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
