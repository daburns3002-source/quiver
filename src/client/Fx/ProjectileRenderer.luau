--!strict
--[[
	Projectile visuals.

	Draws flights from a volley description. Nothing here decides anything:
	the server has already resolved who got hit. These parts exist so the
	player can read the shot.

	They fly through `ProjectileFlight`, the module the server simulates
	with, so a drawn arrow bounces off the walls, passes through the enemies
	and stops in the body that the simulated one does. It used to stop at the
	first thing it touched whatever the loadout said, which hid Bouncy Wall
	and Piercing Shot entirely.

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
local ProjectileFlight = require(ReplicatedStorage.Shared.Combat.ProjectileFlight)
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

--[[ Studs of streak behind an arrow. Set as a length and turned into a
     lifetime per arrow, because at footage speed a fixed lifetime draws a
     ribbon across half the room. The reference's streak, arrow and all, is
     about a fifth of the room's width. ]]
local ARROW_TRAIL_STUDS = 4

--[[ The enemy orb's comet tail. Longer than an arrow's, because an orb is
     slow and a tail is how a slow thing shows which way it is going: at a
     Spitter's speed this draws about two orb-widths of tail, and a Lancer's
     fast shot stretches into a streak on its own. ]]
local ORB_TRAIL_LIFETIME = 0.6

--[[ A drawn flight: the shared `Flight`, plus the part that shows it. ]]
type Visual = ProjectileFlight.Flight & {
	part: BasePart,
	expiresAt: number,
	--[[ Set on the frame the flight ends, and released on the next. Without
	     that frame the part is gone before it is ever drawn where it
	     stopped, so at footage speed an arrow vanished up to three studs
	     short of the enemy it hit. ]]
	stopped: boolean,
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

local function createPart(faction: Faction): BasePart
	local tier = Device.tier()
	local isOrb = faction == "Enemy"

	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = ProjectileFlight.size(faction)
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

		Orbs get one too. Earlier footage was too low-resolution to show it,
		but at 1080 pixels across every enemy orb plainly trails a red comet
		tail three or four times its own size. An orb's tail streams from its
		middle rather than a nose, since a ball has no front.
	]]
	if tier.projectileTrails then
		local size = ProjectileFlight.size(faction)
		local nose = if isOrb then 0 else size.Z / 2

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
		--[[ An arrow's is set per shot in `spawnVolley`, from its speed. ]]
		trail.Lifetime = ORB_TRAIL_LIFETIME
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

--[[ What the drawn flight does at a contact. Every body counts — the client
     cannot know which hits the server will say landed, and drawing the arrow
     stopping is the answer that is almost always right. ]]
local contact: ProjectileFlight.Contact = {
	onModel = function(_flight: ProjectileFlight.Flight, _model: Model): boolean
		return true
	end,
	onWall = function(
		flight: ProjectileFlight.Flight,
		position: Vector3,
		normal: Vector3,
		_bounced: boolean
	)
		spawnImpact(position, normal, flight.faction)
	end,
}

local function step(deltaTime: number)
	local now = os.clock()

	for index = #live, 1, -1 do
		local visual = live[index]

		if visual.stopped then
			release(visual.part, visual.faction)

			local last = #live
			live[index] = live[last]
			live[last] = nil
			continue
		end

		local isEnemy = visual.faction == "Enemy"
		local params = if isEnemy then enemyFilter else playerFilter
		local overlap = if isEnemy then enemyOverlap else playerOverlap
		local alive = now < visual.expiresAt

		if alive and params and overlap then
			alive = ProjectileFlight.advance(visual, deltaTime, params, overlap, contact)
		end

		visual.part.CFrame = placeAt(visual.position, visual.direction)
		visual.stopped = not alive
	end
end

--[[
	Draws one volley. `elapsed` lets a replicated shot start partway along its
	flight so a remote player's arrows are not drawn lagging behind where the
	server already has them. `from` is a body the shot leaves from and must
	not stop in: the enemy a ricochet bounced off.
]]
function ProjectileRenderer.spawnVolley(
	faction: Faction,
	origin: Vector3,
	direction: Vector3,
	specs: { ShotSpec },
	elapsed: number,
	from: Model?
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
			if faction == "Player" then
				trail.Lifetime = ARROW_TRAIL_STUDS / math.max(spec.speed, 1e-3)
			end
			trail.Enabled = true
		end

		table.insert(live, {
			part = part,
			faction = faction,
			position = position,
			direction = aim,
			speed = spec.speed,
			pierce = spec.pierce,
			bounces = spec.bounces,
			hitModels = if from then { [from] = true } else {},
			expiresAt = now + (spec.lifetime - headStart),
			stopped = false,
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
