--!strict
--[[
	The loading screen's tip, on its plate (owner, 2026-11-12, of the lobby
	and "the tips": "awful bland colors. make it have nice soft colors but
	still have everything be readable").

	The tip (`Config/LoadingTips`) used to be pale words written straight on
	the spotlight picture, so the picture behind them decided whether they
	could be read. Now it stands on a white plate with a sunny TIP tag, in
	dark ink: `tests/UiPalette.spec` holds both pairs to 4.5:1.

	Drawn by the join screen (`first/Loading`) and by an area's loading
	screen (`UI/ClassScreen.loadingCover`, which `UI/AreaLoading` holds up),
	each over a spotlight laid out in the picture's own pixels.
]]

local UiPalette = require(script.Parent.Parent.Config.UiPalette)

local TipPlate = {}

export type Box = { x: number, y: number, w: number, h: number }

--[[ How far the plate stands out round the tip's box, the tallest the tag
     is and the gap after it, in picture pixels; the largest the words go,
     in points. ]]
local PAD_X = 18
local PAD_Y = 12
local TAG_HEIGHT = 40
local TAG_GAP = 14
local MAX_TEXT = 28

local function rounded(item: GuiObject, share: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(share, 0)
	corner.Parent = item
end

local function outlined(item: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = UiPalette.edge
	stroke.Thickness = thickness
	stroke.Parent = item
end

local function words(parent: GuiObject, text: string, colour: Color3, z: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = colour
	label.TextScaled = true
	label.ZIndex = z
	label.Parent = parent
	return label
end

--[[ The plate round `box`, a tip's place on a picture `size` pixels big
     that fills `parent`, saying `text`. Its pieces draw at `z` and just
     above. Returns the plate. ]]
function TipPlate.draw(parent: GuiObject, size: Vector2, box: Box, text: string, z: number): Frame
	local w, h = box.w + PAD_X * 2, box.h + PAD_Y * 2
	local plate = Instance.new("Frame")
	plate.Name = "TipPlate"
	plate.BorderSizePixel = 0
	plate.BackgroundColor3 = UiPalette.card
	plate.Position = UDim2.fromScale((box.x - PAD_X) / size.X, (box.y - PAD_Y) / size.Y)
	plate.Size = UDim2.fromScale(w / size.X, h / size.Y)
	plate.ZIndex = z
	plate.Parent = parent
	rounded(plate, 0.28)
	outlined(plate, 3)

	local tagH = math.min(box.h, TAG_HEIGHT)
	local tagW = tagH * 1.9
	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.BorderSizePixel = 0
	tag.BackgroundColor3 = UiPalette.tag
	tag.Position = UDim2.fromScale(PAD_X / w, (h - tagH) / 2 / h)
	tag.Size = UDim2.fromScale(tagW / w, tagH / h)
	tag.ZIndex = z + 1
	tag.Parent = plate
	rounded(tag, 0.28)
	outlined(tag, 2)
	local name = words(tag, "TIP", UiPalette.tagText, z + 2)
	name.Position, name.Size = UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76)

	local left = PAD_X + tagW + TAG_GAP
	local tip = words(plate, text, UiPalette.ink, z + 1)
	tip.Name = "Tip"
	tip.Position = UDim2.fromScale(left / w, PAD_Y / h)
	tip.Size = UDim2.fromScale((w - left - PAD_X) / w, box.h / h)
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Left
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = MAX_TEXT
	limit.Parent = tip
	return plate
end

return TipPlate
