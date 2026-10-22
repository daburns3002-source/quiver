--!strict
--[[
	Shared types.

	Kept in one module so the shot pipeline, the server systems and the client
	renderer all agree on the same shapes without circular requires.
]]

--[[
	Who fired a projectile, which decides both what it can damage and what
	stops it.

	This is not cosmetic. Obstacles block the player's arrows but enemy shots
	fly over them — cover is a damage penalty, never a safety net, and that one
	asymmetry is what turns every room into a positioning puzzle. See
	docs/RESEARCH-archero.md §1. So faction selects the raycast filter, not
	just the damage target.
]]
export type Faction = "Player" | "Enemy"

--[[
	One projectile, fully resolved. The shot pipeline turns a single ShotRequest
	into a list of these; nothing downstream needs to know which abilities
	produced them.
]]
export type ShotSpec = {
	-- Radians, clockwise around Y, relative to the shooter's aim direction.
	angleOffset: number,
	--[[
		Studs sideways from the shooter, perpendicular to this arrow's own
		aim. This is what makes extra arrows fly in a *lane* rather than a
		fan: they share a heading and start beside each other, so a volley
		aimed at one enemy puts every arrow into that enemy.

		A fan spreads with distance and misses everything but the centre
		arrow at range. An offset does not.
	]]
	lateralOffset: number,
	-- Multiplied into the shooter's damage. Extra-arrow abilities pay for
	-- themselves here rather than by editing base damage.
	damageScale: number,
	speed: number,
	lifetime: number,
	-- How many enemies the projectile passes through before dying. 0 = stops on
	-- the first one it hits.
	pierce: number,
	--[[
		Chance, 0 to 1, that a hit strikes for `critMultiplier` instead.

		Rolled by the server at the moment of contact rather than when the
		volley is built, so a piercing arrow can crit on its second target and
		not its first. That is the only reason the OnHit bucket needs to exist
		at all: everything else a stage does is decided before the arrow is in
		the air.
	]]
	critChance: number,
	critMultiplier: number,
	--[[
		Studs of splash around a hit, and what fraction of the arrow's damage
		it deals. Zero radius means no splash at all.

		Splash is resolved by the server at the moment of contact, like crit,
		because what is standing near the target is not knowable when the
		volley is built.
	]]
	splashRadius: number,
	splashScale: number,
	--[[ How many times the arrow reflects off arena geometry before it dies.
	     0 means it stops at the first wall, which is the base behaviour. ]]
	bounces: number,
	--[[ How many times a hit sends the arrow on to the nearest other enemy.
	     Archero 2's Ricochet: between monsters, not off walls. Resolved by
	     the server at contact, like splash, since what is nearby is not
	     knowable when the volley is built. ]]
	ricochet: number,
	--[[ Radians a second the arrow may turn towards the nearest enemy ahead
	     of it. 0 flies straight. Tracking Eye. ]]
	homing: number,
	--[[ How many free arrows a kill by this projectile fires at whatever is
	     nearest. The chain shot inherits nothing — it is a plain arrow, or a
	     stack of these would multiply without limit. ]]
	chainOnKill: number,
}

--[[
	Everything the pipeline needs to resolve a shot. Passed in rather than read
	from a global so the same pipeline can serve a player, a pet or a turret.
]]
export type ShotRequest = {
	damage: number,
	speed: number,
	lifetime: number,
	origin: Vector3,
	direction: Vector3,
}

--[[
	A pipeline stage. `order` places it in one of the Stage buckets in
	ShotPipeline; stages within a bucket run in insertion order.

	A stage receives the specs produced so far and returns the new list. Stages
	must not mutate the input.
]]
export type ShotStage = {
	name: string,
	order: number,
	apply: (specs: { ShotSpec }, request: ShotRequest) -> { ShotSpec },
}

--[[
	Replicated to clients so they can render a volley. Deliberately describes the
	shot rather than streaming positions: Phase 1 projectiles travel in straight
	lines, so origin + direction + speed + time is exact and costs one packet per
	volley instead of one per frame.
]]
export type ShotEvent = {
	faction: Faction,
	--[[ UserId of the shooting player, or 0 when the shooter is not one. The
	     client uses it to skip its own volleys, which prediction already drew. ]]
	shooterId: number,
	origin: Vector3,
	direction: Vector3,
	specs: { ShotSpec },
	firedAt: number,
	--[[
		Whether the shooter's own client already drew this volley itself.

		True for a volley a player's input produced, which their client
		predicted and must not draw twice. False for one the *server* invented
		— a chain shot off a kill, say — which no client saw coming and which
		would otherwise never be drawn at all.
	]]
	predicted: boolean,
	--[[ The body a server-invented shot leaves from — the enemy a ricochet
	     bounced off — which the drawn arrow must pass out of rather than
	     stop in, exactly as the simulated one does. Nil for everything a
	     shooter fired. ]]
	from: Model?,
}

return {}
