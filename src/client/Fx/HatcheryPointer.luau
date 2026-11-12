--!strict
--[[
	The way to the first egg (Fable's loop review, 2026-11-11, approved): the
	tutorial's win pays for the Mossy Egg (`Util/FirstEgg`), and in the lobby,
	while the player can afford it and owns no pet, a blocky gold arrow bobs
	over the Hatchery with HATCH YOUR FIRST EGG! under it, and a row of gold
	tiles on the floor runs from the player toward it. Only on this client, a
	look only: the hatch itself is the server's (`Data/Hatchery`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FirstEgg = require(ReplicatedStorage.Shared.Util.FirstEgg)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local HatcheryPointer = {}

local GOLD = Color3.fromRGB(255, 214, 72)
-- the floor tiles: how many, how far apart, from how far out from the player
local TILES = 6
local SPACING = 4
local FIRST = 5
-- the arrow: how high over the station's foot, and how far it bobs
local ARROW_HEIGHT = 58
local BOB = 2.5

local player = Players.LocalPlayer
local pets: { [string]: number }? = nil
local profileSeen = false

Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(profile)
	if type(profile) == "table" then
		profileSeen = true
		pets = (profile :: any).pets
	end
end)

local function hatchery(): Vector3?
	for _, entry in LobbyConfig.stations do
		if entry.piece == "EggHatchery" then
			return LobbyConfig.origin + Vector3.new(entry.at.X, 0, entry.at.Y)
		end
	end
	return nil
end

local function block(name: string, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	p.Parent = parent
	return p
end

local function wanted(): boolean
	if Workspace:GetAttribute("InLobby") ~= true or not profileSeen then
		return false
	end
	local coins = player:GetAttribute("Coins")
	return FirstEgg.pointWanted(if type(coins) == "number" then coins else 0, pets)
end

function HatcheryPointer.start()
	local station = hatchery()
	if not station then
		return
	end
	local folder: Folder? = nil
	local arrow: { Part } = {}
	local tiles: { Part } = {}

	local function build(): Folder
		local f = Instance.new("Folder")
		f.Name = "HatcheryPointer"
		-- a stepped arrow pointing down: a stem, then rows narrowing to a tip
		table.insert(arrow, block("Stem", Vector3.new(3, 5, 3), f))
		table.insert(arrow, block("Row1", Vector3.new(9, 1.6, 3), f))
		table.insert(arrow, block("Row2", Vector3.new(6, 1.6, 3), f))
		table.insert(arrow, block("Tip", Vector3.new(3, 1.6, 3), f))
		local label = Instance.new("BillboardGui")
		label.Name = "Words"
		label.Size = UDim2.fromOffset(320, 50)
		label.StudsOffsetWorldSpace = Vector3.new(0, -5, 0)
		label.AlwaysOnTop = true
		label.Adornee = arrow[4]
		label.Parent = arrow[4]
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		text.Text = "HATCH YOUR FIRST EGG!"
		text.TextScaled = true
		text.TextColor3 = GOLD
		text.TextStrokeTransparency = 0
		text.Parent = label
		for i = 1, TILES do
			local tile = block("Tile" .. i, Vector3.new(1.4, 0.3, 1.4), f)
			tile.Transparency = 0.2
			table.insert(tiles, tile)
		end
		f.Parent = Workspace
		return f
	end

	RunService.RenderStepped:Connect(function()
		local show = wanted()
		if not show then
			if folder then
				folder:Destroy()
				folder = nil
				table.clear(arrow)
				table.clear(tiles)
			end
			return
		end
		local f = folder or build()
		folder = f
		local now = os.clock()
		local top = station + Vector3.new(0, ARROW_HEIGHT + math.sin(now * 3) * BOB, 0)
		local spin = CFrame.Angles(0, now * 1.2, 0)
		arrow[1].CFrame = CFrame.new(top + Vector3.new(0, 4.5, 0)) * spin
		arrow[2].CFrame = CFrame.new(top + Vector3.new(0, 1.2, 0)) * spin
		arrow[3].CFrame = CFrame.new(top + Vector3.new(0, -0.4, 0)) * spin
		arrow[4].CFrame = CFrame.new(top + Vector3.new(0, -2, 0)) * spin

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local flat = if root
			then Vector3.new(station.X - root.Position.X, 0, station.Z - root.Position.Z)
			else nil
		for i, tile in tiles do
			local along = FIRST + (i - 1) * SPACING
			if root and flat and flat.Magnitude > along + 6 then
				-- a wave runs out along the row, toward the Hatchery
				local lift = math.max(0, math.sin(now * 5 - i * 0.9)) * 0.6
				local at = root.Position + flat.Unit * along
				tile.Transparency = 0.2
				tile.CFrame = CFrame.lookAt(
					Vector3.new(at.X, root.Position.Y - 2.8 + lift, at.Z),
					Vector3.new(station.X, root.Position.Y - 2.8 + lift, station.Z)
				)
			else
				tile.Transparency = 1
			end
		end
	end)
end

return HatcheryPointer
