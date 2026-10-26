--!strict
--[[
	The room sign (owner, 2026-10-24): "a prompt that comes from and goes
	back to the top of the door that tells you what room you are in". As
	each room of a Rooms stage starts, a blocky stone sign with a moss cap
	flies out of the top of the exit gate, hangs at the top of the screen
	saying ROOM <n>, and flies back into the gate. Everything is squares:
	the words from `Config/PixelFont`, each row's run of pixels one frame.

	It follows the gate on screen while it travels, so it leaves and
	returns to the door wherever the camera is; a gate above the top of the
	screen sends it in from the top edge.

	Displays only: the server says which room it is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Cards.Motion)
local PixelFont = require(ReplicatedStorage.Shared.Config.PixelFont)
local RoomSign = require(ReplicatedStorage.Shared.Config.RoomSign)

local RoomSignUI = {}

local gui: ScreenGui? = nil
local sign: Frame? = nil
local shownAt = 0
local lastRoom: number? = nil
local waiting = false
local pending: { number }? = nil
local token = 0

--[[ A square of `w` × `h` pixels at pixel (`x`, `y`) of the sign. ]]
local function square(
	parent: Frame,
	px: number,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3
)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Position = UDim2.fromOffset(x * px, y * px)
	f.Size = UDim2.fromOffset(w * px, h * px)
	f.Parent = parent
end

--[[ The words' width in pixels. ]]
local function measure(text: string): number
	local width = 0
	for i = 1, #text do
		local c = string.sub(text, i, i)
		width += (if c == " " then PixelFont.space else PixelFont.width)
		if i < #text then
			width += PixelFont.gap
		end
	end
	return width
end

--[[ Draws `text` with its top-left at pixel (`x`, `y`), each row's runs of
     filled pixels as one frame. ]]
local function write(parent: Frame, px: number, text: string, x: number, y: number, colour: Color3)
	local at = x
	for i = 1, #text do
		local c = string.sub(text, i, i)
		local glyph = PixelFont.glyphs[c]
		if glyph then
			for row, line in glyph do
				local start: number? = nil
				for col = 1, #line + 1 do
					local on = string.sub(line, col, col) == "#"
					if on and not start then
						start = col
					elseif not on and start then
						square(parent, px, at + start - 1, y + row - 1, col - start, 1, colour)
						start = nil
					end
				end
			end
		end
		at += (if c == " " then PixelFont.space else PixelFont.width) + PixelFont.gap
	end
end

--[[ Builds the sign for room `index` of `total`, its top centre at its
     own position. ]]
local function build(index: number, total: number): Frame
	local colors = RoomSign.colors
	local camera = workspace.CurrentCamera
	local px = math.clamp(
		math.floor(camera.ViewportSize.Y * RoomSign.pixelShare + 0.5),
		RoomSign.pixelMin,
		RoomSign.pixelMax
	)
	local word, number = "ROOM ", tostring(index)
	local pad = RoomSign.padding
	-- The words, plus a pixel for their shadow.
	local textW = measure(word .. number) + 1
	local bodyW = textW + pad * 2
	local bodyH = PixelFont.height + 1 + pad * 2
	local cap = 2

	local root = Instance.new("Frame")
	root.Name = "RoomSign"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset((bodyW + 2) * px, (bodyH + cap + 1) * px)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	-- Everything in pixel units, from the outline's top-left.
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = root

	local top = cap - 1
	-- The outline, its corners notched off.
	square(canvas, px, 1, top, bodyW, 1, colors.outline)
	square(canvas, px, 1, top + bodyH + 1, bodyW, 1, colors.outline)
	square(canvas, px, 0, top + 1, 1, bodyH, colors.outline)
	square(canvas, px, bodyW + 1, top + 1, 1, bodyH, colors.outline)
	-- The stone, lit along its top and shaded along its bottom.
	square(canvas, px, 1, top + 1, bodyW, bodyH, colors.body)
	square(canvas, px, 1, top + 1, bodyW, RoomSign.bevel, colors.bodyTop)
	square(
		canvas,
		px,
		1,
		top + bodyH + 1 - RoomSign.bevel,
		bodyW,
		RoomSign.bevel,
		colors.bodyBottom
	)
	-- The moss cap, a pixel wider than the stone, with a few drips.
	square(canvas, px, 0, 0, bodyW + 2, cap, colors.moss)
	square(canvas, px, 1, 0, bodyW, 1, colors.mossTop)
	for _, share in { 0.15, 0.4, 0.72, 0.9 } do
		square(canvas, px, 1 + math.floor(bodyW * share), cap, 1, 1, colors.moss)
	end

	local tx, ty = 1 + pad, top + 1 + pad
	local numberColour = if index >= total then colors.bossText else colors.text
	write(canvas, px, word .. number, tx + 1, ty + 1, colors.textShadow)
	write(canvas, px, word, tx, ty, colors.text)
	write(canvas, px, number, tx + measure(word) + PixelFont.gap, ty, numberColour)
	return root
end

--[[ The top of the exit gate on screen, or the top centre of the screen
     when there is no gate. ]]
local function doorPoint(): Vector2
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local gate = workspace:FindFirstChild("ExitGate", true)
	local lintel = gate and gate:FindFirstChild("Lintel")
	if lintel and lintel:IsA("BasePart") then
		local top = lintel.Position + Vector3.new(0, lintel.Size.Y / 2, 0)
		local at = camera:WorldToViewportPoint(top)
		return Vector2.new(math.clamp(at.X, 0, viewport.X), math.max(at.Y, -40))
	end
	return Vector2.new(viewport.X / 2, -40)
end

local function pose(root: Frame, uiScale: UIScale, t: number): boolean
	local out, hold, back = RoomSign.outTime, RoomSign.hold, RoomSign.backTime
	local viewport = workspace.CurrentCamera.ViewportSize
	local hang = Vector2.new(viewport.X / 2, viewport.Y * RoomSign.hangY)
	local door = doorPoint()
	local f
	if t < out then
		f = Motion.backOut(t / out)
	elseif t < out + hold then
		f = 1
	elseif t < out + hold + back then
		f = 1 - Motion.quadIn((t - out - hold) / back)
	else
		return false
	end
	local at = door:Lerp(hang, f)
	root.Position = UDim2.fromOffset(at.X, at.Y)
	uiScale.Scale = RoomSign.startScale + (1 - RoomSign.startScale) * math.clamp(f, 0, 1.2)
	return true
end

function RoomSignUI.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("RoomSign")
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("ScreenGui")
	created.Name = "RoomSign"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = 5
	created.Parent = playerGui
	gui = created
end

--[[ Shows room `index` of `total`, out of the door and back. ]]
function RoomSignUI.show(index: number, total: number)
	local created = gui
	if not created then
		return
	end
	local old = sign
	if old then
		old:Destroy()
	end
	token += 1
	local mine = token
	local root = build(index, total)
	local uiScale = root:FindFirstChildOfClass("UIScale") :: UIScale
	root.Visible = false
	root.Parent = created
	sign = root
	shownAt = os.clock() + RoomSign.delay
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - shownAt
		if token ~= mine then
			(connection :: RBXScriptConnection):Disconnect()
			return
		end
		if t < 0 then
			return
		end
		root.Visible = true
		if not pose(root, uiScale, t) then
			(connection :: RBXScriptConnection):Disconnect()
			root:Destroy()
			if sign == root then
				sign = nil
			end
		end
	end)
end

--[[ Behind the intro's title screen (`UI/IntroCutscene`) the first room's
     sign waits, and flies out when BEGIN ADVENTURE is pressed. ]]
function RoomSignUI.setWaiting(value: boolean)
	waiting = value
	local due = pending
	if not value and due then
		pending = nil
		RoomSignUI.show(due[1], due[2])
	end
end

--[[ Argument order matches `Remotes.RunStateChanged`. Each room is shown
     once, as its fight starts; a death or a finished run forgets the last,
     so the next run's first room is shown again. ]]
function RoomSignUI.onRunStateChanged(
	index: number,
	total: number,
	state: string,
	_name: string,
	unit: string?
)
	if unit == "Wave" then
		return
	end
	if state == "Fighting" then
		if index ~= lastRoom then
			lastRoom = index
			if waiting then
				pending = { index, total }
			else
				RoomSignUI.show(index, total)
			end
		end
	elseif state == "Dead" or state == "Complete" or state == "Lobby" then
		lastRoom = nil
	end
end

return RoomSignUI
