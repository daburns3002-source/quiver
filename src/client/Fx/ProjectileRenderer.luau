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

local AssetService = game:GetService("AssetService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Device = require(script.Parent.Parent.Device)
local HitFeedback = require(script.Parent.HitFeedback)
local ProjectileFlight = require(ReplicatedStorage.Shared.Combat.ProjectileFlight)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

type ShotSpec = Types.ShotSpec
type Faction = Types.Faction

--[[ Whose shot it is has to be legible at a glance and from the edge of the
     screen, because the player's whole decision is whether they can afford to
     stand where they are. Warm is yours, violet is incoming. ]]
--[[ Brightened towards white at the core. Archero reads its shots as light
     rather than as objects, and at phone size a merely-coloured dart against a
     lit floor is close to invisible. ]]
local PLAYER_COLOUR = Color3.fromRGB(255, 244, 196)
--[[ Archero 2's enemy orb: a saturated magenta that no floor in the game
     shares, so incoming fire is the loudest colour on screen
     (docs/ART-archero2.md §4). ]]
local ENEMY_COLOUR = Color3.fromRGB(255, 72, 206)
--[[ The Arcanist's orb (`Config/Classes.look`): the staff kit's bolt
     (the Arcanist's weapon's `bolt`, `Config/Weapons`), drawn about three times an arrow's
     width so it reads as magic at a glance, lit in its class's blue. ]]
local PLAYER_ORB_COLOUR = Color3.fromRGB(90, 200, 255)
local PLAYER_ORB_SIZE = Vector3.one * 1.1
local PLAYER_ORB_LIGHT = Color3.fromRGB(80, 170, 255)
--[[ Studs of tail behind the Arcanist's shot. Set as a length, like an
     arrow's, because it flies far faster than the enemy orbs whose tail is
     set in seconds; on their 0.6 s it drew a beam across the room. ]]
local PLAYER_ORB_TRAIL_STUDS = 6

--[[ The bolt's mesh, loaded once at start (`ProjectileRenderer.start`).
     Shots drawn before it arrives are plain balls. ]]
local boltTemplate: MeshPart? = nil

--[[ What a drawn shot is: an arrow, an enemy orb, or a player's orb. One
     pool each, since each is its own shape. ]]
type Pool = "Player" | "Enemy" | "PlayerOrb"

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
	pool: Pool,
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
local pools: { [Pool]: { BasePart } } = { Player = {}, Enemy = {}, PlayerOrb = {} }
local live: { Visual } = {}
--[[ Arrows queued behind their volley (Double Shot), launched when due. ]]
type Pending = {
	at: number,
	faction: Faction,
	look: string?,
	origin: Vector3,
	aim: Vector3,
	spec: ShotSpec,
	from: Model?,
}
local pending: { Pending } = {}
local connection: RBXScriptConnection? = nil

--[[ How many wall impacts may be on screen at once. Capped: it is a
     punctuation mark, not an effect. ]]
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

local function createPart(pool: Pool): BasePart
	local tier = Device.tier()
	local isOrb = pool ~= "Player"
	local faction: Faction = if pool == "Enemy" then "Enemy" else "Player"
	local partSize = if pool == "PlayerOrb" then PLAYER_ORB_SIZE else ProjectileFlight.size(faction)

	local part: BasePart
	if pool == "PlayerOrb" and boltTemplate then
		part = boltTemplate:Clone()
	else
		local plain = Instance.new("Part")
		plain.Shape = if isOrb
			then Enum.PartType.Ball
			elseif tier.projectileIsRound then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part = plain
	end
	part.Name = "Projectile"
	part.Size = partSize
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = PLAYER_COLOUR

	if pool == "PlayerOrb" and tier.projectileTrails then
		local light = Instance.new("PointLight")
		light.Color = PLAYER_ORB_LIGHT
		light.Brightness = 2
		light.Range = 8
		light.Shadows = false
		light.Parent = part
	end

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
	--[[ The footage's orbs shed small sparkles as they fly, which is half of
	     what makes a slow shot readable as moving. Rate from the device
	     tier; none at all on the lowest. ]]
	if isOrb and tier.orbSparkleRate > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Rate = tier.orbSparkleRate
		sparkles.Lifetime = NumberRange.new(0.25, 0.45)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(
			if pool == "PlayerOrb"
				then Color3.fromRGB(200, 240, 255)
				else Color3.fromRGB(255, 200, 240)
		)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparkles.Parent = part
	end

	if tier.projectileTrails then
		local size = partSize
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
local function acquire(pool: Pool, colour: Color3): BasePart
	local part = table.remove(pools[pool])

	if not part then
		part = createPart(pool)
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

local function release(part: BasePart, pool: Pool)
	part.Parent = nil
	table.insert(pools[pool], part)
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
	What a shot does where it meets the arena.

	Being blocked by cover is a rule of this game, not a malfunction, but an
	arrow that disappears silently into a pillar looks exactly like one that
	failed. A small fading ball here was not enough: playtest read cover as
	a bug. So a blocked arrow now **sticks in the wall** for a moment, a ring
	flashes flat on the surface it met, and a few chips fly off it. A bounce
	gets the ring and chips but no arrow, because the arrow went on.

	Deliberately not a hit effect: no number, no flash on anything, so it
	reads as *the wall stopped it* rather than as damage.
]]
local STUCK_TIME = 0.55
local STUCK_FADE = 0.25
local RING_TIME = 0.3
local CHIP_TIME = 0.28
local CHIPS = 4
local SHAFT_COLOUR = Color3.fromRGB(92, 60, 44)
local FLETCH_COLOUR = Color3.fromRGB(226, 52, 60)

local function effectPart(name: string, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = folder
	return part
end

local function spawnImpact(
	position: Vector3,
	normal: Vector3,
	direction: Vector3,
	faction: Faction,
	bounced: boolean
)
	local tier = Device.tier()

	if impacts >= tier.maxDamageNumbers then
		return
	end

	impacts += 1
	task.delay(STUCK_TIME + STUCK_FADE, function()
		impacts -= 1
	end)

	local colour = if faction == "Enemy" then ENEMY_COLOUR else PLAYER_COLOUR
	local surface = position + normal * 0.05

	-- A ring flat on the surface: a thin cylinder whose axis is the normal.
	local ring = effectPart("Impact", Vector3.new(0.05, 0.7, 0.7), colour)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.1
	ring.CFrame = CFrame.lookAt(surface, surface + normal) * CFrame.Angles(0, math.rad(90), 0)
	TweenService:Create(ring, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.05, 2.4, 2.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, RING_TIME)

	-- Chips thrown off the surface, back towards where the shot came from.
	local across = normal:Cross(Vector3.yAxis)
	if across.Magnitude < 1e-3 then
		across = Vector3.xAxis
	end
	across = across.Unit
	local up = across:Cross(normal).Unit

	for index = 1, CHIPS do
		local angle = (index / CHIPS) * 2 * math.pi + math.random() * 0.8
		local spread = across * math.cos(angle) + up * math.sin(angle)
		local chip = effectPart("Impact", Vector3.one * 0.22, colour)
		chip.Material = Enum.Material.Neon
		chip.CFrame = CFrame.new(surface)
		local landing = surface + (normal * 1.1 + spread * 0.9) * (0.8 + math.random() * 0.6)
		TweenService
			:Create(
				chip,
				TweenInfo.new(CHIP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					CFrame = CFrame.new(landing)
						* CFrame.Angles(math.random() * 3, math.random() * 3, 0),
					Size = Vector3.one * 0.05,
					Transparency = 1,
				}
			)
			:Play()
		Debris:AddItem(chip, CHIP_TIME)
	end

	--[[ The arrow itself, its tip buried a little way into the surface and
	     quivering to a stop. Player arrows only: an orb has nothing to
	     stick. ]]
	if bounced or faction == "Enemy" or direction.Magnitude < 1e-3 then
		return
	end

	local heading = direction.Unit
	local length = 1.6
	local nose = position + heading * 0.3
	local shaft = effectPart("StuckArrow", Vector3.new(0.16, 0.16, length), SHAFT_COLOUR)
	local fletch = effectPart("StuckArrow", Vector3.new(0.42, 0.06, 0.4), FLETCH_COLOUR)
	local function place(wobble: number)
		local tilt = CFrame.Angles(wobble, wobble * 0.6, 0)
		local frame = CFrame.lookAt(nose, nose + heading) * tilt
		shaft.CFrame = frame * CFrame.new(0, 0, length / 2)
		fletch.CFrame = frame * CFrame.new(0, 0, length - 0.2)
	end
	place(0)

	local started = os.clock()
	local quiver: RBXScriptConnection
	quiver = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		if age > STUCK_TIME + STUCK_FADE or not shaft.Parent then
			quiver:Disconnect()
			shaft:Destroy()
			fletch:Destroy()
			return
		end

		place(math.sin(age * 55) * math.rad(7) * math.exp(-age * 9))
		local fade = math.clamp((age - STUCK_TIME) / STUCK_FADE, 0, 1)
		shaft.Transparency = fade
		fletch.Transparency = fade
	end)
end

--[[ What the drawn flight does at a contact. Every body counts — the client
     cannot know which hits the server will say landed, and drawing the arrow
     stopping is the answer that is almost always right. ]]
local contact: ProjectileFlight.Contact = {
	onModel = function(flight: ProjectileFlight.Flight, _model: Model): boolean
		--[[ An arrow striking a body throws sparks where it lands. Enemy
		     orbs reaching the player have their own hit feedback. ]]
		if flight.faction == "Player" then
			HitFeedback.onArrowContact(flight.position, flight.direction)
		end
		return true
	end,
	onWall = function(
		flight: ProjectileFlight.Flight,
		position: Vector3,
		normal: Vector3,
		bounced: boolean
	)
		--[[ An orb bursts like an enemy orb; only an arrow sticks in the wall. ]]
		local pool = (flight :: any).pool
		local style: Faction = if pool == "PlayerOrb" then "Enemy" else flight.faction
		spawnImpact(position, normal, flight.direction, style, bounced)
	end,
	--[[ The same choice the server makes, from the models it can see. ]]
	seek = function(flight: ProjectileFlight.Flight): Vector3?
		local enemies = Workspace:FindFirstChild("Enemies")
		if not enemies then
			return nil
		end

		local positions: { [Model]: Vector3 } = {}
		for _, child in enemies:GetChildren() do
			if child:IsA("Model") then
				positions[child] = child:GetPivot().Position
			end
		end

		return ProjectileFlight.seekAhead(flight, positions)
	end,
}

--[[ One arrow onto the screen, at `headStart` seconds into its flight. ]]
local function launch(
	faction: Faction,
	origin: Vector3,
	aim: Vector3,
	spec: ShotSpec,
	headStart: number,
	from: Model?,
	look: string?
)
	local pool: Pool = if faction == "Enemy"
		then "Enemy"
		elseif look == "Orb" then "PlayerOrb"
		else "Player"
	local colour = if pool == "Enemy"
		then ENEMY_COLOUR
		elseif pool == "PlayerOrb" then PLAYER_ORB_COLOUR
		else PLAYER_COLOUR
	local part = acquire(pool, colour)
	--[[ The same sideways offset the server spawns at, from the same
	     helper, so a lane of arrows is a lane in both places. ]]
	local start = ShotPipeline.spawnPoint(origin, aim, spec)
	local position = start + aim * spec.speed * headStart
	part.CFrame = placeAt(position, aim)

	--[[ Enabled only once the part is sitting at its start, so a recycled
	     one does not draw a ribbon from where the last shot expired. ]]
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		if pool == "Player" then
			trail.Lifetime = ARROW_TRAIL_STUDS / math.max(spec.speed, 1e-3)
		elseif pool == "PlayerOrb" then
			trail.Lifetime = PLAYER_ORB_TRAIL_STUDS / math.max(spec.speed, 1e-3)
		end
		trail.Enabled = true
	end

	table.insert(live, {
		part = part,
		pool = pool,
		faction = faction,
		position = position,
		direction = aim,
		speed = spec.speed,
		pierce = spec.pierce,
		bounces = spec.bounces,
		homing = spec.homing,
		hitModels = if from then { [from] = true } else {},
		expiresAt = os.clock() + (spec.lifetime - headStart),
		stopped = false,
	})
end

local function step(deltaTime: number)
	local now = os.clock()

	for index = #pending, 1, -1 do
		local queued = pending[index]
		if now >= queued.at then
			table.remove(pending, index)
			launch(
				queued.faction,
				queued.origin,
				queued.aim,
				queued.spec,
				now - queued.at,
				queued.from,
				queued.look
			)
		end
	end

	for index = #live, 1, -1 do
		local visual = live[index]

		if visual.stopped then
			release(visual.part, visual.pool)

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

--[[ Drops every drawn enemy shot within `radius` of `centre`: the server
     has just removed them for a revive, and they must not be seen to hit. ]]
function ProjectileRenderer.clearEnemyNear(centre: Vector3, radius: number)
	for _, visual in live do
		local offset = visual.position - centre
		if visual.faction == "Enemy" and Vector2.new(offset.X, offset.Z).Magnitude <= radius then
			visual.part.CFrame = CFrame.new(0, -500, 0)
			visual.stopped = true
		end
	end
end

--[[
	Draws one volley. `elapsed` lets a replicated shot start partway along its
	flight so a remote player's arrows are not drawn lagging behind where the
	server already has them. `from` is a body the shot leaves from and must
	not stop in: the enemy a ricochet bounced off.

	An arrow with a `delay` — Double Shot's copies — waits in `pending` and is
	launched by `step` when it is due, mirroring how the server holds it.
]]
function ProjectileRenderer.spawnVolley(
	faction: Faction,
	origin: Vector3,
	direction: Vector3,
	specs: { ShotSpec },
	elapsed: number,
	from: Model?,
	look: string?
)
	local tier = Device.tier()
	local now = os.clock()

	for _, spec in specs do
		if #live + #pending >= tier.maxRenderedProjectiles then
			break
		end

		local aim = ShotPipeline.aim(direction, spec)
		local wait = spec.delay - elapsed

		if wait > 0 then
			table.insert(pending, {
				at = now + wait,
				faction = faction,
				origin = origin,
				aim = aim,
				spec = spec,
				from = from,
				look = look,
			})
		else
			launch(faction, origin, aim, spec, math.clamp(-wait, 0, spec.lifetime), from, look)
		end
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

	-- the shot of whatever the Arcanist holds
	local bolt = (Weapons :: any)[Classes.Arcanist.weapon].bolt :: {
		meshId: string,
		size: Vector3,
	}?
	if bolt and not boltTemplate then
		task.spawn(function()
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(bolt.meshId), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
			end)
			if ok then
				boltTemplate = result
				--[[ Shots pooled as plain balls before it arrived. ]]
				table.clear(pools["PlayerOrb" :: Pool])
			end
		end)
	end

	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(step)
end

return ProjectileRenderer
