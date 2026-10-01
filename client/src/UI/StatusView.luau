--!strict
local Types = require("../Types/Chess")
local Rayfield = require("../Types/Rayfield")
local StatusView = {}
export type StatusView = { report: Types.Reporter, clearOutput: () -> () }

--- Keep the last result visible until a new result or explicit clear replaces it.
function StatusView.new(mainTab: Rayfield.Tab, autoTab: Rayfield.Tab, isAlive: () -> boolean): StatusView
	local status = mainTab:CreateText({ name = "Status", text = "Ready when you are" })
	local output =
		mainTab:CreateText({ name = "Suggested move", text = "Join a match, then choose Suggest move below." })
	local automation = autoTab:CreateText({ name = "Auto Play", text = "Off · Enable Auto calculate to begin" })
	local function clearOutput(): ()
		output:Set("No move selected. Choose Suggest move to analyze the board.")
	end
	local function report(kind: Types.MessageKind, message: string): ()
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
