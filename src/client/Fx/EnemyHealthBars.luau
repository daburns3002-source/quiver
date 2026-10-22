--!strict
--[[
	A thin red health bar over each enemy once it has been hurt, as Archero 2
	draws them (docs/ART-archero2.md §3): dark backing, red fill, and a white
	stretch for the damage just taken that drains away a moment later, so a
	hit reads as a chunk coming off rather than the bar simply being shorter.

	Reads the `Health` and `MaxHealth` attributes the server keeps on each
	enemy. Presentation only — the server's own number is the truth.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
local connection: RBXScriptConnection? = nil

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

	if not folder then
		return
	end

	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue
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
	connection = RunService.RenderStepped:Connect(step)
end

return EnemyHealthBars
