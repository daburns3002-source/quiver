--!strict
--[[
	A player's area attacks: blasts that land a moment after their warning,
	and zones that keep hitting for a while (the Mythics Meteor and
	Earthbreaker, `Config/Abilities`).

	Server-authoritative like every other hit: the caller says where, how
	big and how hard, from the owner's session; this decides what is inside
	and resolves it through `EnemyManager.damage`, crediting kills to the
	owner the way an arrow does. Warnings and effects go to every client on
	the telegraph channel, which draws them (`Fx/TelegraphRenderer`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

local AreaStrikes = {}

type Strike = {
	owner: Player,
	at: Vector3,
	--[[ Lands where this part is when it does, rather than at `at` (the
	     Warden's own slam, wherever his leap brings him down). ]]
	follow: BasePart?,
	radius: number,
	damage: number,
	landsAt: number,
	--[[ What the client draws as it lands. ]]
	impact: string,
	--[[ Called with where it landed, after it has hit. ]]
	landed: ((Vector3) -> ())?,
}

export type StrikeParams = {
	owner: Player,
	at: Vector3,
	follow: BasePart?,
	radius: number,
	damage: number,
	delay: number,
	now: number,
	--[[ A telegraph tell shown at `at` until it lands, if any. ]]
	warning: string?,
	impact: string,
	landed: ((Vector3) -> ())?,
}

type Zone = {
	owner: Player,
	at: Vector3,
	radius: number,
	damage: number,
	every: number,
	nextAt: number,
	endsAt: number,
}

local strikes: { Strike } = {}
local zones: { Zone } = {}

local telegraph = Remotes.event(Remotes.EnemyTelegraph)

--[[ How long a hit's ring takes to spread, as the boss's do. ]]
local RING = 0.45

--[[ Hits everything within `radius` of `at`, counted to the edge of each
     body, once. ]]
local function hit(owner: Player, at: Vector3, radius: number, damage: number)
	for model, position in EnemyManager.positions() do
		local body = model.PrimaryPart
		local half = if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
		local away = Vector3.new(position.X - at.X, 0, position.Z - at.Z).Magnitude
		if away <= radius + half then
			local _, xp, fell = EnemyManager.damage(model, damage, at)
			RunSession.creditKill(owner, xp, fell)
		end
	end
end

--[[ A blast landing `delay` seconds from now, warned of by `warning` until
     it does, and shown by `impact` when it lands. ]]
function AreaStrikes.strike(params: StrikeParams)
	local flat = Vector3.new(params.at.X, 0, params.at.Z)
	local warning = params.warning
	if warning and params.delay > 0 then
		telegraph:FireAllClients(flat, Vector3.zAxis, params.delay, warning, params.radius)
	end
	table.insert(strikes, {
		owner = params.owner,
		at = flat,
		follow = params.follow,
		radius = params.radius,
		damage = params.damage,
		landsAt = params.now + params.delay,
		impact = params.impact,
		landed = params.landed,
	})
end

--[[ Ground that hurts: everything inside it is hit every `every` seconds
     for `duration`, starting `every` from now. Drawn as `look`. ]]
function AreaStrikes.zone(
	owner: Player,
	at: Vector3,
	radius: number,
	damage: number,
	every: number,
	duration: number,
	now: number,
	look: string
)
	local flat = Vector3.new(at.X, 0, at.Z)
	telegraph:FireAllClients(flat, Vector3.zAxis, duration, look, radius)
	table.insert(zones, {
		owner = owner,
		at = flat,
		radius = radius,
		damage = damage,
		every = every,
		nextAt = now + every,
		endsAt = now + duration,
	})
end

--[[ When the last step ran. A gap longer than a few frames is the world
     standing still behind a card screen (the server loop does not step
     while anyone is choosing), and none of that time may count: a meteor
     in the air must still fall after its warning, and cracked ground must
     not fire every eruption it missed at once. ]]
local lastStep: number? = nil
local PAUSE = 0.25

function AreaStrikes.step(now: number)
	local last = lastStep
	lastStep = now
	if last and now - last > PAUSE then
		local stood = now - last
		for _, strike in strikes do
			strike.landsAt += stood
		end
		for _, zone in zones do
			zone.nextAt += stood
			zone.endsAt += stood
		end
	end

	for index = #strikes, 1, -1 do
		local strike = strikes[index]
		if now >= strike.landsAt then
			table.remove(strikes, index)
			local follow = strike.follow
			local at = if follow and follow.Parent
				then Vector3.new(follow.Position.X, 0, follow.Position.Z)
				else strike.at
			telegraph:FireAllClients(at, Vector3.zAxis, RING, strike.impact, strike.radius)
			hit(strike.owner, at, strike.radius, strike.damage)
			local landed = strike.landed
			if landed then
				landed(at)
			end
		end
	end

	for index = #zones, 1, -1 do
		local zone = zones[index]
		while now >= zone.nextAt and zone.nextAt <= zone.endsAt do
			telegraph:FireAllClients(zone.at, Vector3.zAxis, RING, "Erupt", zone.radius)
			hit(zone.owner, zone.at, zone.radius, zone.damage)
			zone.nextAt += zone.every
		end
		if now >= zone.endsAt then
			table.remove(zones, index)
		end
	end
end

--[[ How many blasts are still to land and zones still erupting; for the
     spec. ]]
function AreaStrikes.pending(): (number, number)
	return #strikes, #zones
end

--[[ A new room: nothing pending carries over. ]]
function AreaStrikes.clear()
	table.clear(strikes)
	table.clear(zones)
	lastStep = nil
end

return AreaStrikes
