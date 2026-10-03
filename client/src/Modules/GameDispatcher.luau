--!strict
-- Submit coordinates from an existing game callback. No input injection,
-- camera projection, or thread-identity changes are involved.
type Closure = (...any) -> ...any
type ExecutorDebug = { getconstants: ((Closure) -> { unknown })? }
local executorDebug = (debug :: unknown) :: ExecutorDebug
local GameDispatcher = {}

function GameDispatcher.run(action: () -> string, stillCurrent: (() -> boolean)?): (boolean, string)
	local connections, hook, restore, hooked = getconnections, hookfunction, restorefunction, isfunctionhooked
	if not connections or not hook or not restore or not hooked or not executorDebug.getconstants then
		return false, "Bot execution requires game callback inspection and reversible function hooks."
	end
	local target: Closure? = nil
	for _, connection in ipairs(connections(game:GetService("RunService").Heartbeat)) do
		local fn = connection.Function
		if fn then
			local ok, constants = pcall(executorDebug.getconstants, fn)
			if ok then
				for _, value in pairs(constants) do
					-- Verified CHESS game-owned heartbeat callback; unlike RenderStepped,
					-- Heartbeat continues when rendering is suspended.
					if value == "MovingPlatformsFolder" then
						target = fn
					end
				end
			end
		end
	end
	if not target or hooked(target) then
		return false, "An unmodified game heartbeat callback was not found; no move was submitted."
	end
	local callback = target
	local started, finished = false, false
	local success, message = false, "Game callback did not process the move."
	local original: Closure? = nil
	local installed, failure = pcall(function()
		original = hook(callback, function(...: any): ()
			assert(original)(...)
			if started then
				return
			end
			started = true
			restore(callback)
			if stillCurrent and not stillCurrent() then
				message = "Move cancelled before game callback submission."
			else
				success, message = pcall(action)
			end
			finished = true
		end)
	end)
	if not installed then
		return false, "Game callback hook failed: " .. tostring(failure)
	end
	local deadline = os.clock() + 5
	while not finished do
		if not started and ((stillCurrent and not stillCurrent()) or os.clock() >= deadline) then
			started = true
			restore(callback)
			return false, "Game callback submission expired or was cancelled; no move was submitted."
		end
		task.wait(0.05)
	end
	return success, tostring(message)
end

return GameDispatcher
