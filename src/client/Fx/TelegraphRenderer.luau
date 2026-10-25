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
local BossFx = require(script.Parent.BossFx)
local BroodWebFx = require(script.Parent.BroodWebFx)
local Device = require(script.Parent.Parent.Device)
local FxEvents = require(script.Parent.Upgrades.FxEvents)
local MythicFx = require(script.Parent.MythicFx)
local SplitFx = require(script.Parent.SplitFx)
local TopDownCamera = require(script.Parent.Parent.Camera.TopDownCamera)

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
	BossFx.start(created)
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
--[[ A flat disc on the floor. Both ground cues are one of these; what
     separates them is which way the tween runs. ]]
local function groundDisc(origin: Vector3, name: string, colour: Color3, diameter: number): BasePart
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = colour
	disc.Size = Vector3.new(0.2, diameter, diameter)
	--[[ A cylinder's length runs down its X axis, so it has to be laid on its
	     side to sit flat against the floor. ]]
	disc.CFrame = CFrame.new(origin.X, 0.15, origin.Z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = folder
	return disc
end

local function drawGroundMarker(origin: Vector3, duration: number)
	local tier = Device.tier()

	if activeLines >= tier.maxDamageNumbers then
		return
	end

	activeLines += 1

	local config = Balance.Telegraph
	local radius = config.groundRadius

	--[[ The footprint: full size from the first frame, so *where* costs the
	     player no part of their warning. It does not animate. ]]
	local outline = groundDisc(origin, "TelegraphFootprint", config.groundColor, radius * 2)
	outline.Transparency = config.groundOutlineTransparency

	--[[ The countdown, on top of it: how much is filled is how much time is
	     left. This is the part that was always here. ]]
	local marker = groundDisc(origin, "TelegraphGround", config.groundColor, 1)
	marker.Transparency = 0.5

	local grow = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	TweenService:Create(marker, grow, {
		Size = Vector3.new(0.25, radius * 2, radius * 2),
		Transparency = 0.15,
	}):Play()

	task.delay(duration, function()
		activeLines -= 1
	end)

	Debris:AddItem(marker, duration)
	Debris:AddItem(outline, duration)
end

--[[
	Draws where an enemy is about to appear.

	Archero 2 marks every arrival on the floor before the enemy exists. A ring
	at full size from the first frame says *where*, and a fill growing inside
	it says *how long* — the same grammar as the Lurker's surface marker, in a
	colour that says "enemy" rather than "ground", so a player who has learned
	one reads the other.

	Sized from the arriving body, so the warning for a Bulwark is visibly
	bigger than the warning for a Charger.
]]
local function drawSpawnMarker(origin: Vector3, duration: number, bodyRadius: number)
	local tier = Device.tier()

	if activeLines >= tier.maxDamageNumbers then
		return
	end

	activeLines += 1

	local config = Balance.Telegraph
	local diameter = math.max(bodyRadius, 0.5) * 2 * config.spawnMarkerScale

	local ring = groundDisc(origin, "TelegraphSpawnRing", config.spawnColor, diameter)
	ring.Transparency = 0.55

	local fill = groundDisc(origin, "TelegraphSpawnFill", config.spawnColor, 0.4)
	fill.Transparency = 0.25

	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.25, diameter * 0.85, diameter * 0.85),
	}):Play()

	task.delay(duration, function()
		activeLines -= 1
	end)

	Debris:AddItem(ring, duration)
	Debris:AddItem(fill, duration)
end

--[[
	Draws where something has just gone under.

	The inverse of the marker above, on purpose: this collapses inward where
	that one grows outward. A player never has to be told which is which,
	because the two shapes are opposites and so are the events.

	Not a warning — by the time this is drawn the enemy is already gone and
	already untargetable. It exists because vanishing silently reads as a
	despawn, and a despawned enemy is not something you keep watching for.
]]
local function drawDiveMarker(origin: Vector3)
	local tier = Device.tier()

	if activeLines >= tier.maxDamageNumbers then
		return
	end

	activeLines += 1

	local config = Balance.Telegraph
	local duration = config.diveDuration

	local disc = groundDisc(origin, "TelegraphDive", config.diveColor, config.diveRadius * 2)
	disc.Transparency = 0.25

	local collapse = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(disc, collapse, {
		Size = Vector3.new(0.2, 0.5, 0.5),
		Transparency = 0.85,
	}):Play()

	task.delay(duration, function()
		activeLines -= 1
	end)

	Debris:AddItem(disc, duration)
end

--[[ A green ring rushing out and fading, or `colour`'s (the Mythics'
     strikes; a boss's are cubes, `BossFx`). ]]
local function drawShockwave(origin: Vector3, duration: number, radius: number, colour: Color3?)
	local ring =
		groundDisc(origin, "Shockwave", colour or Balance.Telegraph.shockColor, radius * 0.6)
	ring.Transparency = 0.3
	TweenService
		:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, radius * 2, radius * 2),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(ring, duration)
end

--[[
	The Arcanist's Meteor: where it will land, as a warm ring with a fill
	that is full as it hits, and the rock itself falling out of the sky onto
	it over the same time.
]]
local function drawMeteor(origin: Vector3, duration: number, radius: number)
	local config = Balance.Telegraph
	local ring = groundDisc(origin, "MeteorRing", config.meteorColor, radius * 2)
	ring.Transparency = 0.45
	local fill = groundDisc(origin, "MeteorFill", config.meteorColor, 0.2)
	fill.Transparency = 0.55
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.25, radius * 2, radius * 2),
	}):Play()

	local rock = Instance.new("Part")
	rock.Name = "Meteor"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 3
	rock.Material = Enum.Material.Neon
	rock.Color = config.meteorColor
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.CastShadow = false
	local ground = Vector3.new(origin.X, 1, origin.Z)
	-- straight above where it lands, so it falls straight down
	rock.Position = ground + Vector3.new(0, config.meteorHeight, 0)
	rock.Parent = folder
	MythicFx.meteorRock(rock)
	FxEvents.meteor:fire(rock)
	TweenService
		:Create(rock, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = ground,
		})
		:Play()

	Debris:AddItem(ring, duration)
	Debris:AddItem(fill, duration)
	Debris:AddItem(rock, duration)
end

--[[ Earthbreaker's cracked ground: dark, with glowing cracks running out
     from where he landed, for as long as it erupts, fading at the end. ]]
local function drawCracks(origin: Vector3, duration: number, radius: number)
	local config = Balance.Telegraph
	local scorch = groundDisc(origin, "Cracks", Color3.fromRGB(40, 28, 20), radius * 2)
	scorch.Material = Enum.Material.Fabric
	scorch.Transparency = 0.45
	local parts: { BasePart } = { scorch }
	local count = 7
	local turn = math.random() * math.pi * 2
	for index = 1, count do
		local angle = turn + (index - 1) / count * math.pi * 2 + (math.random() - 0.5) * 0.4
		local length = radius * (0.65 + math.random() * 0.35)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local mid = Vector3.new(origin.X, 0.2, origin.Z) + direction * (length / 2)
		local crack = Instance.new("Part")
		crack.Name = "Crack"
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.CanTouch = false
		crack.CastShadow = false
		crack.Material = Enum.Material.Neon
		crack.Color = config.crackColor
		crack.Size = Vector3.new(0.3, 0.08, length)
		crack.CFrame = CFrame.lookAt(mid, mid + direction)
		crack.Parent = folder
		table.insert(parts, crack)
	end
	for _, part in parts do
		TweenService:Create(
			part,
			TweenInfo.new(
				0.4,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.In,
				0,
				false,
				duration - 0.4
			),
			{ Transparency = 1 }
		):Play()
		Debris:AddItem(part, duration)
	end
end

--[[ `tell` and `reach` come straight off the enemy's config on the server; the
     client never decides whether a warning is owed, only how to show it.
     `width` is sent only for a lane. ]]
function TelegraphRenderer.onTelegraph(
	origin: Vector3,
	direction: Vector3,
	duration: number,
	tell: string,
	reach: number,
	width: number?
)
	if duration <= 0 then
		return
	end

	--[[ A boss's moves (King Bloblin's), drawn in cubes by `BossFx`. ]]
	local parent = folder
	if parent then
		if tell == "Slam" then
			BossFx.slamWarning(parent, origin, duration, reach)
			return
		elseif tell == "SlamImpact" then
			BossFx.slamImpact(parent, origin, duration, reach, width or reach * 0.6)
			return
		elseif tell == "Splat" then
			BossFx.splat(parent, origin, direction, duration, reach)
			return
		elseif tell == "WebLane" then
			BroodWebFx.strand(origin, direction, duration, reach)
			return
		elseif tell == "WebSplat" then
			BroodWebFx.splat(origin, direction, duration, reach)
			return
		elseif tell == "Goo" then
			BossFx.goo(parent, origin, direction, duration, reach)
			return
		elseif tell == "Grab" then
			BossFx.grab(parent, origin, direction, duration, reach)
			return
		elseif tell == "BumpShock" then
			BossFx.bump(parent, origin, direction, duration)
			return
		elseif tell == "LaneAim" or tell == "Lane" then
			if direction.Magnitude > 1e-3 then
				BossFx.lane(
					parent,
					origin,
					direction.Unit,
					duration,
					reach,
					width or 3,
					tell == "Lane"
				)
			end
			return
		end
	end

	if tell == "Shockwave" then
		drawShockwave(origin, duration, reach)
		return
	end

	if tell == "Shake" then
		TopDownCamera.shake(reach, duration)
		return
	end

	--[[ The Mythics' area attacks (`Combat/AreaStrikes`). ]]
	if tell == "Meteor" then
		drawMeteor(origin, duration, reach)
		return
	end
	if tell == "MeteorImpact" then
		drawShockwave(origin, duration, reach, Balance.Telegraph.meteorColor)
		if folder then
			MythicFx.meteorImpact(folder, origin, reach)
		end
		TopDownCamera.shake(0.5, 0.3)
		return
	end
	if tell == "GroundSlam" then
		drawShockwave(origin, duration, reach, Balance.Telegraph.quakeColor)
		TopDownCamera.shake(0.45, 0.3)
		FxEvents.slam:fire(origin, reach)
		return
	end
	if tell == "Cracks" then
		drawCracks(origin, duration, reach)
		return
	end
	if tell == "Erupt" then
		drawShockwave(origin, duration, reach * 0.8, Balance.Telegraph.crackColor)
		if folder then
			MythicFx.erupt(folder, origin, reach)
		end
		return
	end

	if tell == "Ground" then
		drawGroundMarker(origin, duration)
		return
	end

	if tell == "Dive" then
		drawDiveMarker(origin)
		return
	end

	if tell == "Split" then
		--[[ `direction` is the whole throw for this tell, landing minus where
		     the body fell; `reach` is the piece's body radius. ]]
		if parent then
			SplitFx.piece(origin - direction, origin, duration, reach, parent)
		end
		return
	end

	if tell == "Spawn" then
		--[[ `reach` carries the arriving body's radius for this tell: the
		     channel's last argument is "how big", whatever is being marked. ]]
		drawSpawnMarker(origin, duration, reach)
		return
	end

	if tell ~= "Line" or direction.Magnitude < 1e-3 then
		--[[ A `Flash` or `Eyes` tell is the enemy's own recolour, which the
		     server already replicated. Nothing to draw. ]]
		return
	end

	drawLine(origin, direction.Unit, duration, reach)
end

return TelegraphRenderer
