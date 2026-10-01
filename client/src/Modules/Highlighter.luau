--!strict
local Types = require("../Types/Chess")
local Highlighter = {}

type Highlighter = Types.Highlighter

function Highlighter.new(): Highlighter
	local folder = Instance.new("Folder")
	folder.Name = "ChessMoveHighlights"
	folder.Parent = workspace
	return { folder = folder, clear = Highlighter.clear, show = Highlighter.show, destroy = Highlighter.destroy }
end

function Highlighter.clear(self: Highlighter): ()
	self.folder:ClearAllChildren()
end

function Highlighter.show(self: Highlighter, piece: Instance, destination: Instance, options: Types.Settings): ()
	self:clear()
	for _, target in ipairs({ piece, destination }) do
		local highlight = Instance.new("Highlight")
		highlight.Adornee = target
		highlight.FillColor = options.fillColor
		highlight.OutlineColor = options.outlineColor
		highlight.FillTransparency = options.fillTransparency
		highlight.OutlineTransparency = options.outlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = self.folder
	end
end

function Highlighter.destroy(self: Highlighter): ()
	self.folder:Destroy()
end

return Highlighter
