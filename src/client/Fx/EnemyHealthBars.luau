--!strict
--[[
	A thin red health bar over each enemy once it has been hurt, as Archero 2
	draws them (docs/ART-archero2.md §3): dark backing, red fill, and a white
	stretch for the damage just taken that drains away a moment later, so a
	hit reads as a chunk coming off rather than the bar simply being shorter.

	Reads the `Health` and `MaxHealth` attributes the server keeps on each
	enemy. Presentation only — the server's own number is the truth.

	A hard fight's elite (`Util/HardRules`, the `HardElite` attribute) wears
	a gold ELITE plate over its bar from the moment it arrives, so the one
	tough target in the room is plain before it is hit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HardRules = require(ReplicatedStorage.Shared.Util.HardRules)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local EnemyHealthBars = {}

local BAR_NAME = "HealthBar"
--[[ Seconds the white "just lost" stretch waits, then takes to drain. ]]
local TRAIL_DELAY = 0.25
local TRAIL_DRAIN = 0.3

type Bar = {
	gui: BillboardGui,
	fill: Frame,
	trail: Frame,
	shown: number,
	trailFrom: number,
	trailAt: number,
}

local bars: { [Model]: Bar } = {}
--[[ Each elite's plate (`HardRules.ELITE`). ]]
local plates: { [Model]: BillboardGui } = {}
local connection: RBXScriptConnection? = nil

--[[ The gold ELITE plate over an elite, above where its bar goes. ]]
local function plate(root: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "ElitePlate"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(84, 26)
	gui.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 2.4, 0)

	local back = Instance.new("TextLabel")
	back.Name = "Plate"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = UiPalette.primary.top
	back.BorderSizePixel = 0
	back.Font = Enum.Font.FredokaOne
	back.Text = "ELITE"
	back.TextColor3 = UiPalette.ink
	back.TextScaled = true
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = back
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Thickness = 2.5
	line.Color = UiPalette.edge
	line.Parent = back
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 3)
	inset.PaddingBottom = UDim.new(0, 3)
	inset.Parent = back

	gui.Parent = root
	return gui
end

local function build(root: BasePart): Bar
	local gui = Instance.new("BillboardGui")
	gui.Name = BAR_NAME
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local width = math.max(root.Size.X, root.Size.Z) * 1.1
	gui.Size = UDim2.new(width, 0, 0, 9)
	gui.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 1.2, 0)

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(27, 22, 32)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = back

	local trail = Instance.new("Frame")
	trail.Name = "Trail"
	trail.Position = UDim2.fromOffset(1, 1)
	trail.Size = UDim2.new(1, -2, 1, -2)
	trail.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	trail.BorderSizePixel = 0
	trail.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.fromOffset(1, 1)
	fill.Size = UDim2.new(1, -2, 1, -2)
	fill.BackgroundColor3 = Color3.fromRGB(235, 52, 52)
	fill.BorderSizePixel = 0
	fill.Parent = back

	--[[ On the part it rides, not the model: a BillboardGui is drawn for a
	     part or an attachment, and a model is neither. ]]
	gui.Parent = root
	return { gui = gui, fill = fill, trail = trail, shown = 1, trailFrom = 1, trailAt = 0 }
end

local function step()
	local now = os.clock()
	local folder = Workspace:FindFirstChild("Enemies")

	for model, bar in bars do
		if not model.Parent or not bar.gui.Parent then
			bars[model] = nil
		end
	end
	for model, gui in plates do
		if not model.Parent or not gui.Parent then
			plates[model] = nil
		end
	end

	if not folder then
		return
	end

	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		if child:GetAttribute(HardRules.ELITE) == true then
			local gui = plates[child]
			local root = child.PrimaryPart
			if not gui and root then
				gui = plate(root)
				plates[child] = gui
			end
			if gui then
				gui.Enabled = child:GetAttribute("Targetable") ~= false
			end
		end
		local health = child:GetAttribute("Health")
		local maxHealth = child:GetAttribute("MaxHealth")
		if type(health) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 then
			continue
		end

		local fraction = math.clamp(health / maxHealth, 0, 1)
		local bar = bars[child]
		if not bar then
			-- Only once hurt, as in the footage.
			local root = child.PrimaryPart
			if fraction >= 1 or not root then
				continue
			end
			bar = build(root)
			bars[child] = bar
		end

		if fraction < bar.shown - 1e-4 then
			-- A new hit: the trail starts from what was shown before it.
			bar.trailFrom = math.max(bar.trailFrom, bar.shown)
			bar.trailAt = now
			bar.shown = fraction
		end

		--[[ Hidden with the body: a burrowed Lurker has no bar floating
		     over the empty floor. ]]
		bar.gui.Enabled = child:GetAttribute("Targetable") ~= false
		bar.fill.Size = UDim2.new(fraction, -2, 1, -2)

		local since = now - bar.trailAt
		local trail = bar.trailFrom
		if since > TRAIL_DELAY then
			local p = math.clamp((since - TRAIL_DELAY) / TRAIL_DRAIN, 0, 1)
			trail = bar.trailFrom + (fraction - bar.trailFrom) * p
			if p >= 1 then
				bar.trailFrom = fraction
			end
		end
		bar.trail.Size = UDim2.new(math.max(trail, fraction), -2, 1, -2)
	end
end

function EnemyHealthBars.start()
	if connection then
		connection:Disconnect()
	end
	table.clear(bars)
	table.clear(plates)
	connection = RunService.RenderStepped:Connect(step)
end

return EnemyHealthBars
