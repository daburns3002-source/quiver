--!strict
--[[
	Enemy wind-up tells.

	Purely a warning: the server has already decided what will be fired and
	when. This draws the notice so the player can act inside the window, which
	is the entire counterplay against a line-ranged enemy.

	Drawn client-side from a description rather than replicated as parts, the
	same way projectiles are. A tell is also a presentation budget — a busy
	room full of lines is unreadable — so it respects the device tier's cap
	rather than drawing every one.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)

local TelegraphRenderer = {}

local folder: Folder? = nil
local activeLines = 0

function TelegraphRenderer.start(parent: Instance)
	local existing = parent:FindFirstChild("Telegraphs")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "Telegraphs"
	created.Parent = parent
	folder = created
	activeLines = 0
end

--[[
	Draws the path a locked shot will take, from the shooter out past where it
	is aimed.

	It grows along its own length rather than fading in, so the direction reads
	before the line is fully drawn — a tell that only becomes legible at the
	end of the wind-up is not a tell.
]]
local function drawLine(origin: Vector3, direction: Vector3, duration: number, reach: number)
	local tier = Device.tier()

	--[[ Reuses the damage-number budget: both are screen clutter competing for
	     the same attention, and a tier that cannot afford one cannot afford
	     the other. ]]
	if activeLines >= tier.maxDamageNumbers then
		return
	end

	activeLines += 1

	local config = Balance.Telegraph
	local length = reach + config.lineOvershoot
	local centre = origin + direction * (length / 2)

	local line = Instance.new("Part")
	line.Name = "TelegraphLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = config.lineColor
	line.Transparency = 0.55
	line.Size = Vector3.new(config.lineThickness, config.lineThickness, 0.1)
	line.CFrame = CFrame.lookAt(centre, centre + direction)
	line.Parent = folder

	--[[ Grown over the first part of the wind-up, then held. The hold is what
	     the player reads; the growth is what draws their eye to it. ]]
	local grow = TweenInfo.new(duration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(line, grow, {
		Size = Vector3.new(config.lineThickness, config.lineThickness, length),
		Transparency = 0.25,
	}):Play()

	task.delay(duration, function()
		activeLines -= 1
	end)

	Debris:AddItem(line, duration)
end

--[[
	Draws where something is about to come up through the floor.

	It grows outward over the whole warning rather than appearing at full size,
	so the marker reads as a countdown: how much of it is drawn is how much
	time is left to walk off it.
]]
local function drawGroundMarker(origin: Vector3, duration: number)
	local tier = Device.tier()

	if activeLines >= tier.maxDamageNumbers then
		return
	end

	activeLines += 1

	local config = Balance.Telegraph
	local radius = config.groundRadius

	local marker = Instance.new("Part")
	marker.Name = "TelegraphGround"
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = config.groundColor
	marker.Transparency = 0.6
	marker.Size = Vector3.new(0.2, 1, 1)
	--[[ A cylinder's length runs down its X axis, so it has to be laid on its
	     side to sit flat against the floor. ]]
	marker.CFrame = CFrame.new(origin.X, 0.15, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = folder

	local grow = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	TweenService:Create(marker, grow, {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 0.35,
	}):Play()

	task.delay(duration, function()
		activeLines -= 1
	end)

	Debris:AddItem(marker, duration)
end

--[[ `tell` and `reach` come straight off the enemy's config on the server; the
     client never decides whether a warning is owed, only how to show it. ]]
function TelegraphRenderer.onTelegraph(
	origin: Vector3,
	direction: Vector3,
	duration: number,
	tell: string,
	reach: number
)
	if duration <= 0 then
		return
	end

	if tell == "Ground" then
		drawGroundMarker(origin, duration)
		return
	end

	if tell ~= "Line" or direction.Magnitude < 1e-3 then
		--[[ A `Flash` tell is the enemy's own recolour, which the server
		     already replicated. Nothing to draw. ]]
		return
	end

	drawLine(origin, direction.Unit, duration, reach)
end

return TelegraphRenderer
