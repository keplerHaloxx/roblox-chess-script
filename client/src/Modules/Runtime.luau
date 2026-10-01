--!strict
local Types = require("../Types/Chess")
local Runtime = {}

--- One application namespace, shared only through the executor's global environment.
function Runtime.getState(): Types.RuntimeState
	assert(type(getgenv) == "function", "This client requires getgenv().")
	local environment = getgenv() :: Types.Environment
	if not environment.ChessClient then
		environment.ChessClient = { teleportQueued = false }
	end
	return environment.ChessClient :: Types.RuntimeState
end

--- Executor compatibility is kept at the edge of the application.
function Runtime.getRequest(): Types.Request?
	return request or http_request or (syn and syn.request) or (http and http.request)
end

function Runtime.queueTeleport(state: Types.RuntimeState, scriptUrl: string): boolean
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
