--!strict
--[[
	How a projectile moves and what stops it, shared by the server's
	simulation and the client's drawing.

	There used to be two copies of this: `ProjectileSystem` on the server and a
	simpler one in `ProjectileRenderer`. The simpler one stopped every arrow at
	the first thing it touched, so once Bouncy Wall and Piercing Shot existed
	the player watched arrows die at walls and inside enemies while the real
	ones flew on and did damage nobody could see. That is the same class of
	bug as the empty client pipeline in #25: two halves of the game showing
	different shots. One module means one flight.

	What each side does *about* a contact stays with that side. The server
	applies damage and decides whether a hit landed; the client draws a spark.
	They both answer through `Contact`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Types = require(ReplicatedStorage.Shared.Types)

type Faction = Types.Faction

--[[ Ceiling on segment-walk iterations per sub-step. Each pass decrements
     `remaining` by at least a hundredth of a stud, so it cannot spin; this
     also bounds its raycast cost in one frame. ]]
local MAX_SEGMENT_STEPS = 8

--[[ Ceiling on sub-steps per frame. A long hitch at footage speed asks for
     more than this; past it the sub-steps lengthen rather than multiply, so
     one bad frame cannot spend itself on a single projectile. ]]
local MAX_SUBSTEPS = 16

--[[ Studs a reflected projectile is nudged off the surface it bounced from,
     so the next cast does not begin inside the wall it just left. ]]
local BOUNCE_CLEARANCE = 0.15

export type Flight = {
	faction: Faction,
	position: Vector3,
	direction: Vector3,
	speed: number,
	--[[ Enemies left to pass through after the current one. 0 stops on first
	     contact. ]]
	pierce: number,
	--[[ Reflections off arena geometry left. Spent, so a projectile is its
	     own counter. ]]
	bounces: number,
	--[[ Models already reached, so one body is not hit on consecutive steps
	     while the projectile is still inside it. ]]
	hitModels: { [Model]: boolean },
}

export type Contact = {
	--[[ A model this flight has reached for the first time. Returns whether
	     the contact counts — whether it spends pierce or stops the flight. The
	     server says no for a body that was already dead, say. ]]
	onModel: (flight: Flight, model: Model) -> boolean,
	--[[ Arena geometry, and whether the flight bounced off it or died. ]]
	onWall: ((flight: Flight, position: Vector3, normal: Vector3, bounced: boolean) -> ())?,
}

local ProjectileFlight = {}

--[[
	The box both sides sweep and the client draws: exactly the projectile on
	screen. Enemy shots are orbs, swept as the orb the player sees; a long box
	on something drawn as a ball would hit along a length that is not there.
]]
function ProjectileFlight.size(faction: Faction): Vector3
	if faction == "Enemy" then
		return Vector3.one * Balance.Projectile.enemyOrbDiameter
	end

	local width = Balance.Projectile.radius * 2
	return Vector3.new(width, width, Balance.Projectile.length)
end

--[[ Centred on the flight's position and pointed down its travel. ]]
function ProjectileFlight.pose(flight: Flight): CFrame
	return CFrame.lookAt(flight.position, flight.position + flight.direction)
end

--[[
	A direction mirrored off a surface, flattened to the floor plane.

	Flattened because the arena's walls are vertical and its floor is not in
	any filter, so a reflection should never gain height — but a glancing hit
	on a corner can produce one, and a projectile that leaves the ground is one
	that silently stops hitting anything. Nil when nothing flat is left.
]]
function ProjectileFlight.reflect(direction: Vector3, normal: Vector3): Vector3?
	local reflected = direction - 2 * direction:Dot(normal) * normal
	local flat = Vector3.new(reflected.X, 0, reflected.Z)

	if flat.Magnitude < 1e-3 then
		return nil
	end

	return flat.Unit
end

--[[
	Spends a contact against pierce. Returns whether the flight survives it.
]]
local function strike(flight: Flight, model: Model, contact: Contact): boolean
	flight.hitModels[model] = true

	if not contact.onModel(flight, model) then
		return true
	end

	if flight.pierce <= 0 then
		return false
	end

	flight.pierce -= 1
	return true
end

--[[
	Resolves every body the projectile is intersecting *right now*.

	A shape cast ignores anything it already overlaps when it starts — measured
	in Studio at every depth tried — so the projectile's front half is a dead
	zone the sweep cannot see into, and a moving target that steps into it
	stays unseen while the box carries it along. This pass is the only reason
	those hits land. `tests/HitDetection.spec.luau` pins the engine behaviour.

	Models only. Arena geometry is the sweep's job: the box straddles the
	shooter at spawn, so stopping on overlapped geometry here would kill every
	shot fired with its back to a wall.
]]
local function resolveOverlaps(
	flight: Flight,
	size: Vector3,
	overlap: OverlapParams,
	contact: Contact
): boolean
	--[[ Bounds, not exact geometry, so marginally generous at the corners of
	     a hitbox. That favours the shooter, which is the right way to be
	     wrong. ]]
	for _, part in workspace:GetPartBoundsInBox(ProjectileFlight.pose(flight), size, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")

		if not model or flight.hitModels[model] then
			continue
		end

		if not strike(flight, model, contact) then
			return false
		end
	end

	return true
end

--[[
	Sweeps `distance` along the flight, resolving everything in the way in
	order — so a piercing shot strikes every target along the segment rather
	than skipping the ones between frames.
]]
local function sweep(
	flight: Flight,
	size: Vector3,
	distance: number,
	params: RaycastParams,
	contact: Contact
): boolean
	local remaining = distance
	local steps = 0

	while remaining > 1e-3 do
		steps += 1
		if steps > MAX_SEGMENT_STEPS then
			-- Out of budget, not out of life: it resumes on the next step.
			return true
		end

		local segment = flight.direction * remaining
		local result = workspace:Blockcast(ProjectileFlight.pose(flight), size, segment, params)

		if not result then
			flight.position += segment
			return true
		end

		local model = result.Instance:FindFirstAncestorOfClass("Model")

		--[[
			Where the box is at the moment it touches: its centre moved
			`Distance` along the cast, so its nose sits on the surface it hit.
			That is where a projectile that *stops* is left.

			One that carries on — a bounce, a pierce, a body it already
			struck — is moved on to the contact point instead, half a box
			deeper, so the next cast starts inside what it is leaving and the
			engine ignores it. Left merely touching, every following cast
			finds the same body a hundredth of a stud ahead and the
			projectile stalls on its surface.
		]]
		local touching = flight.position + flight.direction * result.Distance
		local passing = result.Position + flight.direction * 1e-2
		remaining -= math.max((passing - flight.position).Magnitude, 1e-2)

		--[[ Something in the filter with no Model above it is arena geometry,
		     which only ever appears in the player's filter. ]]
		if not model then
			local reflected = if flight.bounces > 0
				then ProjectileFlight.reflect(flight.direction, result.Normal)
				else nil

			if contact.onWall then
				contact.onWall(flight, result.Position, result.Normal, reflected ~= nil)
			end

			if not reflected then
				flight.position = touching
				return false
			end

			flight.bounces -= 1
			flight.direction = reflected
			flight.position = result.Position + reflected * BOUNCE_CLEARANCE

			--[[ A bounced projectile is a new threat, so it may hit things it
			     already passed through on the way out. ]]
			table.clear(flight.hitModels)
			continue
		end

		if flight.hitModels[model] then
			flight.position = passing
			continue
		end

		--[[ At the surface while the contact resolves, so the server's hit
		     point — where splash centres and a ricochet leaves from — is the
		     outside of the body rather than half an arrow into it. ]]
		flight.position = touching

		if not strike(flight, model, contact) then
			return false
		end

		flight.position = passing
	end

	return true
end

--[[
	Advances a flight by one frame. Returns whether it is still alive.

	Cut into sub-steps no longer than `Balance.Projectile.maxStepTravel`, each
	running the overlap pass and then the sweep. Both halves are needed: the
	overlap pass sees what the sweep is structurally blind to, the sweep
	covers the gap the projectile would otherwise tunnel across. Sub-stepping
	is what keeps the pair sound at footage speed, where an arrow covers more
	than its own length in a frame and could otherwise step over a body
	without ever touching it on the moment the overlap pass runs.
]]
function ProjectileFlight.advance(
	flight: Flight,
	deltaTime: number,
	params: RaycastParams,
	overlap: OverlapParams,
	contact: Contact
): boolean
	local size = ProjectileFlight.size(flight.faction)
	local total = flight.speed * deltaTime
	local substeps =
		math.clamp(math.ceil(total / Balance.Projectile.maxStepTravel), 1, MAX_SUBSTEPS)
	local each = total / substeps

	for _ = 1, substeps do
		if not resolveOverlaps(flight, size, overlap, contact) then
			return false
		end

		if not sweep(flight, size, each, params, contact) then
			return false
		end
	end

	return true
end

return table.freeze(ProjectileFlight)
