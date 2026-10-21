--!strict
--[[
	Projectile visuals.

	Draws straight-line flights from a volley description. Nothing here decides
	anything: the server has already resolved who got hit. These parts exist so
	the player can read the shot, and they despawn on contact purely so arrows
	do not visibly pass through a wall.

	Parts are pooled. At Phase 3 volley sizes, allocating a Part per projectile
	would be the single biggest source of frame hitches.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Types = require(ReplicatedStorage.Shared.Types)

type ShotSpec = Types.ShotSpec
type Faction = Types.Faction

--[[ Whose shot it is has to be legible at a glance and from the edge of the
     screen, because the player's whole decision is whether they can afford to
     stand where they are. Warm is yours, violet is incoming. ]]
--[[ Brightened towards white at the core. Archero reads its shots as light
     rather than as objects, and at phone size a merely-coloured dart against a
     lit floor is close to invisible. ]]
local PLAYER_COLOUR = Color3.fromRGB(255, 244, 196)
local ENEMY_COLOUR = Color3.fromRGB(226, 182, 255)

--[[ Seconds of trail behind a shot. Short: it is there to make the line of
     travel legible at a glance, not to leave the room full of ribbons. ]]
local TRAIL_LIFETIME = 0.14

type Visual = {
	part: BasePart,
	--[[ Decides what stops this one, exactly as it does on the server. ]]
	faction: Faction,
	position: Vector3,
	direction: Vector3,
	speed: number,
	expiresAt: number,
}

local ProjectileRenderer = {}

local folder: Folder? = nil
--[[ One pool per faction, because the two are different shapes. A shared pool
     handed an orb to an arrow and an arrow to an orb, and resizing a part
     on every reuse is exactly the allocation-shaped cost the pool exists to
     avoid. ]]
local pools: { [Faction]: { BasePart } } = { Player = {}, Enemy = {} }
local live: { Visual } = {}
local connection: RBXScriptConnection? = nil

--[[ Seconds an impact spark lives, and how many may exist at once. Short and
     capped: it is a punctuation mark, not an effect. ]]
local IMPACT_DURATION = 0.18
local impacts = 0

--[[
	One filter per faction, mirroring ProjectileSystem.

	A single filter containing the arena blockers stopped *every* drawn
	projectile at a wall, including enemy shots — which the server flies
	straight over them. The player watched incoming fire vanish into a pillar
	and then take damage from it anyway. The asymmetry has to be drawn as well
	as simulated, or the player is being shown a different game from the one
	being played.
]]
local playerFilter: RaycastParams? = nil
local enemyFilter: RaycastParams? = nil

--[[ The same two include-lists again for the overlap pass, mirroring
     ProjectileSystem. Without it the drawn arrow sails on through the enemy
     the server already stopped it on, so a hit registers, a damage number
     appears, and the arrow that caused it keeps flying. ]]
local playerOverlap: OverlapParams? = nil
local enemyOverlap: OverlapParams? = nil

--[[
	Each faction's projectile dimensions, read from the same config the server
	sweeps, so the shape drawn and the shape simulated cannot drift apart.

	The player fires long arrows; enemies fire round orbs. That is what the
	reference footage shows, and it is also the single most useful thing a
	player can be told about a projectile at a glance — whose it is — told by
	silhouette rather than by asking them to read a hue mid-dodge.
]]
local function projectileSize(faction: Faction): Vector3
	if faction == "Enemy" then
		return Vector3.one * Balance.Projectile.enemyOrbDiameter
	end

	local width = Balance.Projectile.radius * 2
	return Vector3.new(width, width, Balance.Projectile.length)
end

local function createPart(faction: Faction): BasePart
	local tier = Device.tier()
	local isOrb = faction == "Enemy"

	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = projectileSize(faction)
	part.Shape = if isOrb
		then Enum.PartType.Ball
		elseif tier.projectileIsRound then Enum.PartType.Cylinder
		else Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = PLAYER_COLOUR

	--[[
		Built once with the part and recoloured on reuse, because the pool
		exists precisely to avoid allocating per shot. The two attachments sit
		across the nose rather than along the body, so the ribbon is the width
		of the arrow and streams out behind it as it travels.

		Arrows only. An enemy orb in the footage does not streak, and a trail
		on something that slow reads as a smear rather than as speed.
	]]
	if tier.projectileTrails and not isOrb then
		local size = projectileSize(faction)
		local nose = size.Z / 2

		local left = Instance.new("Attachment")
		left.Name = "TrailLeft"
		left.Position = Vector3.new(-size.X / 2, 0, nose)
		left.Parent = part

		local right = Instance.new("Attachment")
		right.Name = "TrailRight"
		right.Position = Vector3.new(size.X / 2, 0, nose)
		right.Parent = part

		local trail = Instance.new("Trail")
		trail.Name = "Trail"
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.Lifetime = TRAIL_LIFETIME
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Parent = part
	end

	return part
end

--[[ Colour is still set on acquire rather than on create, so retuning a
     faction colour does not need the pool emptied first. ]]
local function acquire(faction: Faction, colour: Color3): BasePart
	local part = table.remove(pools[faction])

	if not part then
		part = createPart(faction)
	end

	local resolved = part :: BasePart
	resolved.Color = colour

	local trail = resolved:FindFirstChildOfClass("Trail")
	if trail then
		trail.Color = ColorSequence.new(colour)
		--[[ Cleared on reuse, or a recycled part draws a ribbon from wherever
		     the last shot died to wherever this one starts. ]]
		trail.Enabled = false
	end

	resolved.Parent = folder
	return resolved
end

local function release(part: BasePart, faction: Faction)
	part.Parent = nil
	table.insert(pools[faction], part)
end

local function makeFilter(instances: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	params.IgnoreWater = true
	return params
end

local function makeOverlap(instances: { Instance }): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	return params
end

function ProjectileRenderer.refreshFilters()
	local playerTargets: { Instance } = {}

	local arena = Workspace:FindFirstChild("Arena")
	local blockers = if arena then arena:FindFirstChild("Blockers") else nil
	if blockers then
		table.insert(playerTargets, blockers)
	end

	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(playerTargets, enemies)
	end

	--[[ Characters only, and deliberately no blockers: an enemy shot is
	     stopped by the person it was aimed at and by nothing else, so it stays
	     visible across the room until it leaves or expires. ]]
	local enemyTargets: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(enemyTargets, character)
		end
	end

	playerFilter = makeFilter(playerTargets)
	enemyFilter = makeFilter(enemyTargets)
	playerOverlap = makeOverlap(playerTargets)
	enemyOverlap = makeOverlap(enemyTargets)
end

--[[
	Draws the arrow so its *tip* sits where the server's sphere front is,
	rather than its centre sitting on the simulated point.

	The part is over three studs long, so centring it on the simulated
	position put its nose more than a stud ahead of anything the server would
	register — the arrow looked like it had already reached an enemy while the
	shot was still short of it. Aligning the leading edge makes "the tip
	touched it" and "the server counted it" the same moment.
]]
--[[
	Centred on the simulated position, which is now also the centre of the box
	the server sweeps.

	This used to offset the part backwards so its nose sat where a much
	smaller sphere's front was. With the server sweeping the whole arrow there
	is nothing left to compensate for: the drawn part and the hitbox are the
	same box in the same place.
]]
local function placeAt(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

--[[
	A small spark where a shot stops against the arena.

	Being blocked by cover is a rule of this game, not a malfunction, but an
	arrow that disappears silently into a pillar looks exactly like one that
	failed. This is the cheapest possible way to say "that was the wall" —
	and it is deliberately not a hit effect, so it reads as *nothing
	happened to anything* rather than as damage.
]]
local function spawnImpact(position: Vector3, normal: Vector3, faction: Faction)
	local tier = Device.tier()

	if impacts >= tier.maxDamageNumbers then
		return
	end

	impacts += 1

	local spark = Instance.new("Part")
	spark.Name = "Impact"
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.one * (Balance.Projectile.radius * 2)
	spark.Position = position + normal * 0.1
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.CastShadow = false
	spark.Material = Enum.Material.Neon
	spark.Color = if faction == "Enemy" then ENEMY_COLOUR else PLAYER_COLOUR
	spark.Transparency = 0.2
	spark.Parent = folder

	TweenService:Create(spark, TweenInfo.new(IMPACT_DURATION, Enum.EasingStyle.Quad), {
		Size = Vector3.one * (Balance.Projectile.radius * 5),
		Transparency = 1,
	}):Play()

	task.delay(IMPACT_DURATION, function()
		impacts -= 1
	end)

	Debris:AddItem(spark, IMPACT_DURATION)
end

local function step(deltaTime: number)
	local now = os.clock()

	for index = #live, 1, -1 do
		local visual = live[index]
		local isEnemy = visual.faction == "Enemy"
		local params = if isEnemy then enemyFilter else playerFilter
		local overlap = if isEnemy then enemyOverlap else playerOverlap
		local travel = visual.speed * deltaTime
		local segment = visual.direction * travel
		local size = projectileSize(visual.faction)
		local pose = CFrame.lookAt(visual.position, visual.position + visual.direction)
		local finished = now >= visual.expiresAt

		--[[
			Bodies the arrow is already inside, which the sweep below is
			structurally blind to. ProjectileSystem runs this same pass for the
			same reason, and the two have to agree: without it the server stops
			the shot and the client does not, so a damage number appears while
			the arrow that caused it sails on through.

			Models only, matching the server — arena geometry is the sweep's
			job on both sides.
		]]
		if not finished and overlap then
			for _, part in Workspace:GetPartBoundsInBox(pose, size, overlap) do
				if part:FindFirstAncestorOfClass("Model") then
					finished = true
					break
				end
			end
		end

		if not finished and params then
			--[[ The same box the server sweeps, so a shot that stops on screen
			     is a shot that stopped on the server. ]]
			local result = Workspace:Blockcast(pose, size, segment, params)

			if result then
				visual.position = result.Position
				finished = true

				--[[ Only arena geometry gets a spark. An enemy hit already has
				     a flash and a damage number; a wall had nothing at all,
				     so a blocked arrow simply vanished and read as the game
				     failing rather than as cover working. ]]
				if not result.Instance:FindFirstAncestorOfClass("Model") then
					spawnImpact(result.Position, result.Normal, visual.faction)
				end
			end
		end

		if not finished then
			visual.position += segment
		end

		visual.part.CFrame = placeAt(visual.position, visual.direction)

		if finished then
			release(visual.part, visual.faction)

			local last = #live
			live[index] = live[last]
			live[last] = nil
		end
	end
end

--[[
	Draws one volley. `elapsed` lets a replicated shot start partway along its
	flight so a remote player's arrows are not drawn lagging behind where the
	server already has them.
]]
function ProjectileRenderer.spawnVolley(
	faction: Faction,
	origin: Vector3,
	direction: Vector3,
	specs: { ShotSpec },
	elapsed: number
)
	local tier = Device.tier()
	local now = os.clock()
	local colour = if faction == "Enemy" then ENEMY_COLOUR else PLAYER_COLOUR

	for _, spec in specs do
		if #live >= tier.maxRenderedProjectiles then
			break
		end

		local aim = ShotPipeline.aim(direction, spec)
		local headStart = math.clamp(elapsed, 0, spec.lifetime)

		local part = acquire(faction, colour)
		--[[ The same sideways offset the server spawns at, from the same
		     helper, so a lane of arrows is a lane in both places. ]]
		local start = ShotPipeline.spawnPoint(origin, aim, spec)
		local position = start + aim * spec.speed * headStart
		part.CFrame = placeAt(position, aim)

		--[[ Enabled only once the part is sitting at its start, so a recycled
		     one does not draw a ribbon from where the last shot expired. ]]
		local trail = part:FindFirstChildOfClass("Trail")
		if trail then
			trail.Enabled = true
		end

		table.insert(live, {
			part = part,
			faction = faction,
			position = position,
			direction = aim,
			speed = spec.speed,
			expiresAt = now + (spec.lifetime - headStart),
		})
	end
end

function ProjectileRenderer.start(parent: Instance)
	local existing = parent:FindFirstChild("ProjectileVisuals")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "ProjectileVisuals"
	created.Parent = parent
	folder = created

	ProjectileRenderer.refreshFilters()

	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(step)
end

return ProjectileRenderer
