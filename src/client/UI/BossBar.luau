--!strict
--[[
	A boss's health across the top of the screen, under the run banner, as
	Archero 2 shows it: the boss's name over a long red bar.

	Drawn from the attributes the server already sets on every enemy
	(`Health`, `MaxHealth`) and the `Boss` attribute it adds to a boss,
	which carries its title. Shown while one is in the room, hidden
	otherwise. Read for drawing only; the server's number is the truth.

	**Segments** (owner, 2026-10-28, for King Bloblin's thirds): a boss
	whose fight has health thresholds is published with `HealthSegments`
	— one more than it has thresholds — and its bar is divided into that
	many equal parts, so the player can see the next one coming. The
	dividers are drawn at fixed fractions of the track and are never asked
	what the boss's health is: they are furniture, and the fill above them
	is the only thing that moves.

	**Two bosses** (Endless's deeper glade boss floors fight two King
	Bloblins): **one track each**, stacked, and one title line reading
	"SLIME KING ×2". A single pooled bar would have had to show the pair's
	combined health, and then its thirds would mark nothing — the pair
	crossing two thirds of their combined health is not when either king
	summons. One track per king keeps every segment honest: each boundary
	is that king's own threshold. Up to `MAX_BARS` of them; a fight with
	more bosses than that is not a fight this bar can describe, and nothing
	in the game has one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)

local BossBar = {}

local BAR_COLOUR = Color3.fromRGB(220, 58, 52)
local TRACK_COLOUR = Color3.fromRGB(24, 26, 32)
local DIVIDER_COLOUR = Color3.fromRGB(12, 13, 16)

--[[ Tracks built up front and shown as the room needs them. Two is what
     the game has; four is headroom that costs four idle frames. ]]
local MAX_BARS = 4
--[[ The most dividers a track draws, so `MAX_SEGMENTS` parts. Thirds need
     two. ]]
local MAX_SEGMENTS = 8

type Track = {
	track: Frame,
	fill: Frame,
	dividers: { Frame },
}

local connection: RBXScriptConnection? = nil

--[[ Every boss in the room, in the Workspace's own child order (stable
     while nothing spawns or dies, which is what keeps the tracks from
     swapping places mid-fight). ]]
local function findBosses(): { Model }
	local out: { Model } = {}
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return out
	end
	for _, child in enemies:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Boss") and #out < MAX_BARS then
			table.insert(out, child)
		end
	end
	return out
end

--[[ What the title line reads: the boss's banner name, or its raw title,
     and "×n" when the room holds more than one of the same boss. Two
     *different* bosses have no shared name to print, and nothing in the
     game puts two in a room, so they get the plural and their own bars. ]]
local function titleText(bosses: { Model }): string
	local name = bosses[1]:GetAttribute("Boss")
	for _, boss in bosses do
		if boss:GetAttribute("Boss") ~= name then
			return "BOSSES"
		end
	end
	local banner = if type(name) == "string" then BossBanners.bosses[name] else nil
	local shown = if banner then banner.name elseif type(name) == "string" then name else "BOSS"
	shown = string.upper(shown)
	if #bosses > 1 then
		return `{shown} ×{#bosses}`
	end
	return shown
end

--[[ One track: its dark groove, its red fill and its dividers. Row 1 sits
     where the single bar always did; each later row hangs below the frame,
     which is why the frame does not clip. ]]
local function buildTrack(frame: Frame, row: number): Track
	local track = Instance.new("Frame")
	track.Name = `Track{row}`
	track.Position = UDim2.fromScale(0, 0.52 + (row - 1) * 0.55)
	track.Size = UDim2.fromScale(1, 0.48)
	track.BackgroundColor3 = TRACK_COLOUR
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_COLOUR
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local dividers: { Frame } = {}
	for index = 1, MAX_SEGMENTS - 1 do
		local divider = Instance.new("Frame")
		divider.Name = `Divider{index}`
		divider.AnchorPoint = Vector2.new(0.5, 0)
		divider.Size = UDim2.new(0, 2, 1, 0)
		divider.BackgroundColor3 = DIVIDER_COLOUR
		divider.BackgroundTransparency = 0.15
		divider.BorderSizePixel = 0
		divider.ZIndex = 2
		divider.Visible = false
		divider.Parent = track
		dividers[index] = divider
	end

	return { track = track, fill = fill, dividers = dividers }
end

--[[ Draws one boss onto one track: the fill from its health, the dividers
     from its segment count. ]]
local function drawTrack(row: Track, boss: Model)
	local health = boss:GetAttribute("Health")
	local maxHealth = boss:GetAttribute("MaxHealth")
	if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
		row.fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	end

	local published = boss:GetAttribute("HealthSegments")
	local segments = if type(published) == "number" then math.floor(published) else 1
	segments = math.clamp(segments, 1, MAX_SEGMENTS)
	for index, divider in row.dividers do
		divider.Visible = index < segments
		if divider.Visible then
			divider.Position = UDim2.fromScale(index / segments, 0)
		end
	end
end

function BossBar.start()
	BossBar.stop()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BossBar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	--[[ Below the run banner's XP bar and its level label, which grew 26
	     points for the blocky font (CLAUDE.md rule 11). ]]
	frame.Position = UDim2.new(0.5, 0, 0.135, 26)
	frame.Size = UDim2.fromScale(0.5, 0.06)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 54)
	limit.MinSize = Vector2.new(220, 30)
	limit.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Arcade
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Parent = frame

	local rows: { Track } = {}
	for row = 1, MAX_BARS do
		rows[row] = buildTrack(frame, row)
	end

	gui.Parent = playerGui

	connection = RunService.RenderStepped:Connect(function()
		local bosses = findBosses()
		gui.Enabled = #bosses > 0
		if #bosses == 0 then
			return
		end
		-- the name its entry banner gives it (the King's title is still "Slime King")
		title.Text = titleText(bosses)
		for index, row in rows do
			local boss: Model? = bosses[index]
			row.track.Visible = boss ~= nil
			if boss then
				drawTrack(row, boss)
			end
		end
	end)
end

function BossBar.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return BossBar
