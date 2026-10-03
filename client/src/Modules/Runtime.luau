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
	local loader = string.format([[
local fetch = request or http_request or (syn and syn.request) or (http and http.request)
assert(fetch, "Your executor needs request or http_request.")
local response = fetch({Url = %q, Method = "GET"})
assert(type(response) == "table", "Invalid client download response.")
local status = tonumber(response.StatusCode)
assert(response.Success ~= false and status and status >= 200 and status < 300, "Client download failed.")
assert(type(response.Body) == "string" and response.Body ~= "", "Empty client download.")
local chunk, reason = loadstring(response.Body)
assert(chunk, reason)
chunk()
]], scriptUrl)
	local success = pcall(queue, loader)
	state.teleportQueued = success
	return success
end
return Runtime
