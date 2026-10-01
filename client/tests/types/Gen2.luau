--!strict
-- Static contract examples: checked by mise run typecheck, never run in Roblox.
local Rayfield = require("../../src/Types/Rayfield")
return function(library: Rayfield.Library): ()
	local window = library:CreateWindow({
		name = "Type contract",
		sidebarLayout = true,
		configuration = { autoSave = true, autoLoad = true },
		theme = { AccentColor = Color3.new(1, 0, 0) },
		translator = function(source, locale)
			return if locale == "en" then source else nil
		end,
	})
	local tab = window:CreateTab({ name = "Controls" })
	tab:CreateToggle({
		callback = function(value: boolean)
			assert(value or not value)
		end,
	}):Set(true, true)
	tab:CreateSlider({
		callback = function(value: number, dragging: boolean)
			if not dragging then
				print(value)
			end
		end,
	})
	local single = tab:CreateDropdown({
		options = { "one" },
		callback = function(value: string)
			print(value)
		end,
	})
	local selection: { string } = single.value
	single:Set(selection)
	local multiple: Rayfield.MultiDropdownProps = {
		multiSelect = true,
		callback = function(values: { string })
			print(#values)
		end,
	}
	tab:CreateDropdown(multiple)
	tab:CreateKeybind({
		callback = function(key: EnumItem)
			print(key.Name)
		end,
	})
	local holdBinding: Rayfield.HoldKeybindProps = {
		hold = true,
		callback = function(held: boolean)
			print(held)
		end,
	}
	tab:CreateKeybind(holdBinding)
	tab:CreateColorPicker({
		color = "#ffffff",
		callback = function(color: Color3, alpha: number)
			print(color, alpha)
		end,
	}):SetAlpha(0.5)
	tab:CreateInput({
		numeric = true,
		callback = function(text: string)
			print(text)
		end,
	})
	local stat: Rayfield.StatProps = { changeMode = "absolute" }
	tab:CreateStat(stat):ResetBaseline()
	tab:CreateProgress({
		format = function(value: number, minimum: number, maximum: number)
			return tostring(value - minimum) .. "/" .. tostring(maximum)
		end,
	}):SetRange(0, 10)
	tab:CreateConsole({ follow = true }):Append("line")
	tab:CreateText({ text = "body" }):SetTitle("title")
	tab:CreateDivider():Set("advanced")
	tab:CreateGroup({ direction = "column" }):CreateButton({ callback = function() end }):Lock("locked")
	window:CreateTag({ text = "test" }):SetColor(Color3.new(1, 1, 1))
	local popup: Rayfield.PopupProps = { options = { { text = "Close", style = "primary" :: "primary" } } }
	window:Popup(popup):Close()
	window:RegisterTranslations({ fr = { Controls = "Contrôles" } })
	window:Toast({ position = "Bottom", title = "Saved" })
	window:Save("test")
	local directory: string, path: string = window:GetPath()
	print(directory, path)
end
