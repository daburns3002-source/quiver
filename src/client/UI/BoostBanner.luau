--!strict
--[[
	The boosts' banner in the lobby (docs/LIVE-EVENTS.md): a pill for each
	boost running, top centre (under the coin and gem pills on a touch
	layout, whose top right they hold), its countdown ticking: "2x LUCK
	WEEKEND 2D 5H", "LIVE EVENT! 2x COINS 29:59", "THANKS NAME! 2x LUCK
	14:59". A luck pill carries the Server Luck's lucky egg, a coin pill the
	one coin (rule 15).
	A new Server Luck pops its pill. It shows when the lobby HUD does.

	The owner (the `LiveEventOwner` attribute, set by the server from their
	user id) also has the LIVE switch under it: 2x LUCK or 2x COINS for 30
	minutes in every server, or END. The server checks the id again; this
	only shows the buttons.

	Displays only: the boosts are the server's (`Util/LiveState`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Chunky = require(script.Parent.Chunky)
local Config = require(ReplicatedStorage.Shared.Config.LobbyHud)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local LiveState = require(ReplicatedStorage.Shared.Util.LiveState)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StationScreen = require(script.Parent.StationScreen)

local BoostBanner = {}

--[[ A pill's height and widest, in points. ]]
local ROW_H = 40
local ROW_W = 440
local ROW_GAP = 6

local started = false

--[[ The lucky egg: the Server Luck's own picture. ]]
local function luckPicture(): string
	for _, product in RobuxStore.products do
		if product.serverLuck and product.icon then
			return product.icon
		end
	end
	return ""
end

local function line(boost: LiveBoosts.Boost, now: number): string
	return LiveBoosts.words(boost) .. "  " .. LiveBoosts.clock(boost.endsAt - now)
end

function BoostBanner.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoostBanner"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 111
	gui.Enabled = false
	gui.Parent = playerGui
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui

	local k = 2
	local shown = ""
	local drawnSize = Vector2.zero
	local switchOpen = false
	--[[ The Server Luck's end last seen: nil until the first look, so a
	     boost already running as the player joins does not pop. ]]
	local lastLuckEnds: number? = nil
	local labels: { { label: TextLabel, boost: LiveBoosts.Boost } } = {}

	local function draw(boosts: { LiveBoosts.Boost }, now: number)
		canvas:ClearAllChildren()
		table.clear(labels)
		drawnSize = gui.AbsoluteSize
		local size = gui.AbsoluteSize
		local sheet = Chunky.pointSheet(canvas, math.max(size.X, 1), math.max(size.Y, 1))
		local g = Config.gutter
		local touch = StationScreen.touchLayout(gui)
		local w = math.min(sheet.w - g * 2 * k, ROW_W * k)
		local x = (sheet.w - w) / 2
		local y = if touch then (g / 2 + Config.pillHeight + 8) * k else g * k / 2
		for _, boost in boosts do
			local icon = if boost.kind == "Coins" then ShopAssets.coin else luckPicture()
			local pill = Chunky.pill(sheet, icon, line(boost, now), x, y, w, ROW_H * k)
			pill.Name = "Boost" .. boost.source
			local label = pill:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				-- a line of words, not an amount: the whole pill past the picture
				label.Position, label.Size = UDim2.fromScale(0.07, 0.1), UDim2.fromScale(0.9, 0.8)
				label.TextXAlignment = Enum.TextXAlignment.Center
				table.insert(labels, { label = label, boost = boost })
			end
			y += (ROW_H + ROW_GAP) * k
		end
		if player:GetAttribute(LiveEvents.ownerAttribute) ~= true then
			return
		end
		-- the owner's switch
		local bw, bh = 120 * k, 36 * k
		Chunky.button(
			sheet,
			if switchOpen then "CLOSE" else "LIVE",
			Chunky.purple,
			x,
			y,
			bw,
			bh,
			function()
				switchOpen = not switchOpen
				shown = ""
			end
		).Name =
			"LiveSwitch"
		if not switchOpen then
			return
		end
		local choices = {
			{ words = "2x LUCK 30M", kind = "Luck", colour = Chunky.green },
			{ words = "2x COINS 30M", kind = "Coins", colour = Chunky.gold },
			{ words = "END", kind = "End", colour = Chunky.red },
		}
		local cx = x + bw + 8 * k
		local cw = (x + w - cx - 2 * 8 * k) / #choices
		for _, choice in choices do
			Chunky.button(sheet, choice.words, choice.colour, cx, y, cw, bh, function()
				Remotes.event(Remotes.LiveEventStart):FireServer(choice.kind)
				switchOpen = false
				shown = ""
			end).Name = "Live"
				.. choice.kind
			cx += cw + 8 * k
		end
	end

	local function tick()
		local now = LiveState.now()
		local boosts = LiveState.boosts(now)
		-- the pills are drawn again only when what is running changes
		local names = {}
		for _, boost in boosts do
			table.insert(names, LiveBoosts.words(boost))
		end
		local signature = table.concat(names, "|")
			.. tostring(player:GetAttribute(LiveEvents.ownerAttribute))
			.. tostring(switchOpen)
		if signature ~= shown or gui.AbsoluteSize ~= drawnSize then
			shown = signature
			draw(boosts, now)
		else
			for _, row in labels do
				row.label.Text = line(row.boost, now)
			end
		end
		-- a Server Luck just bought (or more time on one): its pill pops
		local value = Workspace:GetAttribute(LiveEvents.attributes.luckEnds)
		local luckEnds = if type(value) == "number" then value else 0
		local last = lastLuckEnds
		if last ~= nil and luckEnds > last + 1 then
			local pill = canvas:FindFirstChild("BoostServer")
			if pill and pill:IsA("GuiObject") then
				Chunky.pop(pill)
				Chunky.burst(pill)
			end
		end
		lastLuckEnds = luckEnds
	end

	local lobbyHud: ScreenGui? = nil
	local nextTick = 0
	RunService.RenderStepped:Connect(function()
		if not lobbyHud or not lobbyHud.Parent then
			local found = playerGui:FindFirstChild("LobbyHud")
			lobbyHud = if found and found:IsA("ScreenGui") then found else nil
		end
		local hud = lobbyHud
		gui.Enabled = hud ~= nil and hud.Enabled
		local clock = os.clock()
		if gui.Enabled and (clock >= nextTick or gui.AbsoluteSize ~= drawnSize) then
			nextTick = clock + 0.25
			tick()
		end
	end)
	-- a boost that starts or ends shows at once, not on the next tick
	for _, name in LiveEvents.attributes do
		Workspace:GetAttributeChangedSignal(name):Connect(function()
			nextTick = 0
		end)
	end
end

return BoostBanner
