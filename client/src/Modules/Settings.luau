--!strict
local Types = require("../Types/Chess")
local Settings = {}
function Settings.defaults(): Types.Settings
	return {
		depth = 17,
		thinkTime = 100,
		disregardTime = false,
		autoCalculate = false,
		autoExecute = false,
		executeDelay = 300,
		useCalculatedDelay = false,
		fillColor = Color3.fromRGB(59, 235, 223),
		outlineColor = Color3.fromRGB(255, 255, 255),
		fillTransparency = 0.5,
		outlineTransparency = 0,
	}
end
return Settings
