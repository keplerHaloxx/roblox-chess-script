--!strict
local Types = require("../Types/Chess")
local Protocol = {}
Protocol.REQUIRED_REVISION = 1

function Protocol.compatibilityError(data: { [string]: unknown }): string?
	if data.protocol_revision == Protocol.REQUIRED_REVISION then
		return nil
	end
	local version = if type(data.server_version) == "string" then data.server_version else "unknown (older build)"
	return `The desktop server ({version}) is incompatible with this client. Download the latest server and restart it. Analysis is paused until a compatible server is running.`
end

--- Convert UCI notation into the game's mirrored board coordinates.
function Protocol.parseMove(move: unknown): (Types.ParsedMove?, string?)
	if type(move) ~= "string" or not string.match(move, "^[a-h][1-8][a-h][1-8][qrbn]?$") then
		return nil, "The engine did not return a playable move."
	end
	return {
		fromPos = { 105 - string.byte(move, 1), assert(tonumber(string.sub(move, 2, 2))) },
		toPos = { 105 - string.byte(move, 3), assert(tonumber(string.sub(move, 4, 4))) },
		promotion = if #move == 5 then string.sub(move, 5, 5) :: Types.Promotion else nil,
	},
		nil
end

--- Validate the transport envelope before interpreting endpoint-specific fields.
function Protocol.decodeResponse(
	response: unknown,
	decode: (string) -> unknown
): ({ [string]: unknown }?, string?, string?)
	if type(response) ~= "table" then
		return nil, "The HTTP function returned an invalid response.", nil
	end
	local envelope = response :: { [string]: unknown }
	local body = envelope.Body
	if type(body) ~= "string" or body == "" then
		return nil, "The server returned an empty response.", nil
	end
	local decoded, raw = pcall(decode, body)
	if not decoded or type(raw) ~= "table" then
		return nil, "The server returned invalid JSON. Check that the chess server is running.", nil
	end
	local data = raw :: { [string]: unknown }
	if data.ok == false and type(data.error) == "table" then
		local failure = data.error :: { [string]: unknown }
		return nil,
			tostring(failure.message or "The server rejected the request."),
			if type(failure.code) == "string" then failure.code else nil
	end
	local status = tonumber(envelope.StatusCode)
	if envelope.Success == false or not status or status < 200 or status >= 300 then
		return nil, `Server request failed (HTTP {tostring(envelope.StatusCode)}).`, nil
	end
	if data.ok ~= true then
		return nil, "The server response is missing its success status.", nil
	end
	return data, nil, nil
end

function Protocol.delayMs(difficulty: Types.Difficulty?, useCalculated: boolean, manualDelay: number): number
	local delay = if useCalculated and difficulty then difficulty.recommended_delay_ms else manualDelay
	if type(delay) ~= "number" or delay ~= delay or math.abs(delay) == math.huge then
		delay = manualDelay
	end
	return math.clamp(delay :: number, 0, 120000)
end
return Protocol
