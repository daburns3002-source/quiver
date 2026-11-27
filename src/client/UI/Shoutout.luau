--!strict
--[[
	Hatch shout-outs on screen (`Config/Shoutouts`, `Data/Shoutouts`): a
	short banner across the top in the rarity's colour, glowing (CLAUDE.md
	rule 12), "NAME HATCHED A MYTHIC GLIMMERHORN!", and the same line in chat
	in that colour. A shout from another server is a chat line only.

	A banner and its chat line wait while this player's own reveal is up
	(`UI/Reveal`), so whoever hatched it sees their own pet before the
	shout. At most `Config.queue` banners wait; any more are chat lines.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Shoutouts)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local ShoutoutRules = require(ReplicatedStorage.Shared.Util.ShoutoutRules)

local Chunky = require(script.Parent.Chunky)
local Reveal = require(script.Parent.Reveal)

local Shoutout = {}

--[[ The banner, in points, and how far down the screen it rests. ]]
local WIDTH = 520
local HEIGHT = 50
local MARGIN = 12
local DROP = 0.13

type Waiting = { line: string, rarity: string }
local waiting: { Waiting } = {}
local running = false
local screen: ScreenGui? = nil

local function nameOf(kind: string, item: string): string?
	if kind == "Pet" then
		local pet = Pets[item]
		return if pet then pet.name else nil
	end
	local entry = ShopRules.find(item)
	return if entry then entry.label else nil
end

local function escape(words: string): string
	return (string.gsub(string.gsub(string.gsub(words, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

--[[ The line in chat, in the rarity's colour (Roblox's own system line). ]]
local function chat(line: string, rarity: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels
		and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
	if not channel or not channel:IsA("TextChannel") then
		return
	end
	local colour: Color3 = (Chunky.rarity :: any)[rarity] or Chunky.gold
	pcall(function()
		channel:DisplaySystemMessage(`<font color="#{colour:ToHex()}">{escape(line)}</font>`)
	end)
end

--[[ One banner: drops in, holds, and goes back up. Yields until it is gone. ]]
local function banner(line: string, rarity: string)
	local gui = screen
	if not gui then
		return
	end
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = RunHudRules.fit(view, WIDTH, HEIGHT, MARGIN)
	local colour: Color3 = (Chunky.rarity :: any)[rarity] or Chunky.gold

	local holder = Instance.new("Frame")
	holder.Name = "Shoutout"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(WIDTH * fit, HEIGHT * fit)
	holder.Position = UDim2.new(0.5, 0, 0, -HEIGHT * fit * 2)
	holder.Parent = gui
	local sheet = Chunky.pointSheet(holder, WIDTH, HEIGHT)

	-- the glow behind it, the rarity's own colour (rule 12)
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = GearAssets.fx.glow
	glow.ImageColor3 = Chunky.lit(colour)
	glow.ScaleType = Enum.ScaleType.Stretch
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.35, 4.2)
	glow.ZIndex = 1
	glow.Parent = holder

	local strip = Instance.new("Frame")
	strip.BorderSizePixel = 0
	strip.ZIndex = 4
	Chunky.put(sheet, strip, 0, 0, sheet.w, sheet.h)
	Chunky.light(strip, colour)
	Chunky.round(strip, 26)
	Chunky.outline(strip, 5, Chunky.edge)
	Chunky.gleam(strip)
	Chunky.twinkle(strip)
	local words = Chunky.textOn(strip, line, colour, 5)
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.Size = UDim2.fromScale(0.92, 0.62)

	local ease = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(holder, ease, { Position = UDim2.fromScale(0.5, DROP) }):Play()
	task.wait(0.35 + Config.hold)
	local away = TweenService:Create(
		holder,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0, -HEIGHT * fit * 2) }
	)
	away:Play()
	away.Completed:Wait()
	holder:Destroy()
end

local function run()
	if running then
		return
	end
	running = true
	while #waiting > 0 do
		while Reveal.busy() do
			task.wait(0.25)
		end
		local shout = table.remove(waiting, 1) :: Waiting
		chat(shout.line, shout.rarity)
		banner(shout.line, shout.rarity)
		task.wait(Config.gap)
	end
	running = false
end

--[[ A shout to show (also the in-Roblox spec's way in). ]]
function Shoutout.show(who: string, kind: string, item: string, rarity: string, far: boolean)
	local name = nameOf(kind, item)
	if not name or not ShoutoutRules.loud(rarity) or (kind ~= "Pet" and kind ~= "Weapon") then
		return
	end
	local line = ShoutoutRules.line(
		who,
		kind :: ShoutoutRules.Kind,
		rarity,
		name,
		if far then Config.far.suffix else nil
	)
	if far or #waiting >= Config.queue then
		task.spawn(function()
			while Reveal.busy() do
				task.wait(0.25)
			end
			chat(line, rarity)
		end)
		return
	end
	table.insert(waiting, { line = line, rarity = rarity })
	task.spawn(run)
end

function Shoutout.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("Shoutouts")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shoutouts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the station screens (115-120) and the reward toasts (140), under
	-- purchase effects and first-time tips
	gui.DisplayOrder = 145
	gui.Parent = playerGui
	screen = gui
	Remotes.event(Remotes.Shoutout).OnClientEvent
		:Connect(function(who: unknown, kind: unknown, item: unknown, rarity: unknown, far: unknown)
			if
				type(who) == "string"
				and type(kind) == "string"
				and type(item) == "string"
				and type(rarity) == "string"
			then
				Shoutout.show(who, kind, item, rarity, far == true)
			end
		end)
end

return Shoutout
