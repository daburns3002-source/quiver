--!strict
--[[
	Kill coins drop and fly to the coin counter (review item 5, owner
	2026-11-11: "pay out where the player is looking").

	The server pays every coin (`RunSession.payCoins`) and says so with
	`Remotes.CoinsGained(amount, position?)`. A kill's coins pop out of the
	spot it fell on, in screen space, and fly to the coin counter; coins with
	no spot (the clear bonus, a co-op partner's kill) only count.

	**The contract with the run HUD's coin counter:**
	- show the `CoinsShown` Player attribute (set here, on the client only):
	  the wallet's `Coins` less what is still in the air, so the counter
	  ticks up as each coin lands rather than when the enemy dies;
	- tag the counter's coin icon `CoinCounter` (CollectionService) and the
	  coins fly to it; with none on screen they fly to the top of the screen.
	`CoinDrops.landed` fires with each landed amount, for a bump or a sound.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

--[[ How it moves: coins per drop, their size (px), how far they burst
     (px) and how long the burst and the flight last (s). ]]
local PIECES = 3
local SIZE = 30
local BURST = 46
local BURST_TIME = 0.28
local FLY_TIME = 0.5
--[[ More than this many in the air and new ones only count. ]]
local MAX_FLYING = 30

local CoinDrops = {}

local landedEvent = Instance.new("BindableEvent")
CoinDrops.landed = landedEvent.Event

local player = Players.LocalPlayer
local inFlight = 0
local flying = 0
local gui: ScreenGui? = nil

local function update()
	local coins = player:GetAttribute("Coins")
	local total = if type(coins) == "number" then coins else 0
	player:SetAttribute("CoinsShown", math.max(0, total - inFlight))
end

local function targetPoint(): Vector2
	for _, tagged in CollectionService:GetTagged("CoinCounter") do
		if tagged:IsA("GuiObject") and tagged.Visible and tagged.AbsoluteSize.X > 0 then
			return tagged.AbsolutePosition + tagged.AbsoluteSize / 2
		end
	end
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 800
	return Vector2.new(width / 2, 24)
end

local function ensureGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "CoinDrops"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	-- over the run HUD, under the card screen and the end screens
	screen.DisplayOrder = 40
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
	return screen
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

local function easeIn(t: number): number
	return t * t
end

local function drop(amount: number, position: Vector3)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(position)
	if not onScreen or flying >= MAX_FLYING then
		return
	end
	inFlight += amount
	update()
	local screen = ensureGui()
	local from = Vector2.new(point.X, point.Y)
	local remaining = PIECES
	for i = 1, PIECES do
		local angle = (i / PIECES) * math.pi * 2 + math.random() * 0.8
		local burst = from + Vector2.new(math.cos(angle), math.sin(angle) - 0.6) * BURST
		local coin = Instance.new("ImageLabel")
		coin.Name = "Coin"
		coin.BackgroundTransparency = 1
		coin.Image = EndScreenAssets.coin
		coin.ResampleMode = Enum.ResamplerMode.Pixelated
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Size = UDim2.fromOffset(SIZE, SIZE)
		coin.Position = UDim2.fromOffset(from.X, from.Y)
		coin.Parent = screen
		flying += 1
		local started = os.clock() + (i - 1) * 0.04
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if t < 0 then
				return
			end
			if t < BURST_TIME then
				local at = from:Lerp(burst, easeOut(t / BURST_TIME))
				coin.Position = UDim2.fromOffset(at.X, at.Y)
				return
			end
			local k = math.min(1, (t - BURST_TIME) / FLY_TIME)
			local at = burst:Lerp(targetPoint(), easeIn(k))
			coin.Position = UDim2.fromOffset(at.X, at.Y)
			local size = SIZE * (1 - 0.35 * k)
			coin.Size = UDim2.fromOffset(size, size)
			if k >= 1 then
				connection:Disconnect()
				coin:Destroy()
				flying -= 1
				remaining -= 1
				if remaining == 0 then
					inFlight -= amount
					update()
					landedEvent:Fire(amount)
				end
			end
		end)
	end
end

function CoinDrops.start()
	update()
	player:GetAttributeChangedSignal("Coins"):Connect(update)
	Remotes.event(Remotes.CoinsGained).OnClientEvent:Connect(function(amount, position)
		if type(amount) ~= "number" or amount <= 0 then
			return
		end
		if typeof(position) == "Vector3" then
			drop(amount, position)
		else
			update()
			landedEvent:Fire(amount)
		end
	end)
end

return table.freeze(CoinDrops)
