--!strict
--[[
	Plays the bows' and staves' shots ported from the Projectile Shots page
	(owner, 2026-11-19: "build projectile effects for the bows and wands
	the same way you did for the swords and daggers", then "build all 49").

	`Fx/ProjectileRenderer` still flies every shot, the same flight the
	server simulates, and hands each one whose weapon has a card here,
	drawing nothing of its own for it. Every frame each live shot's place
	and heading is sampled (`Kit.Shot`); its card's `f` draws the flight
	from those samples and its `h` each hit: where it went on through an
	enemy, where it stopped in one or in a wall, where its reach ran out.
	A shot is gone `Kit.HITLIFE` after it stops. Everything is laid flat in
	the shot's own flight plane by `Fx/Cleaves/Painter`, in a pool of its
	own.

	The lowest device tier draws no tails and sheds nothing, as today's
	shots there (`Kit.lite`); weaker devices draw fewer segments and stop
	at a smaller share of the pool. A crowded moment (a late run's volleys)
	draws the newest shots whole and, once `CROWDED` of the pool is used,
	the older ones as their heads and hits only. Past the whole pool (a
	late run can fly 400 at once), a shot is not drawn at all: its flight
	part shows instead, a small block lit in the weapon's main colour, so
	every shot still shows and the frame's cost stays flat. Presentation
	only, local.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Device = require(script.Parent.Parent.Parent.Device)
local Kit = require(script.Parent.Kit)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Painter = require(script.Parent.Parent.Cleaves.Painter)
local Styles = require(script.Parent.Styles)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local log = Log.forTag("ProjectileShots")

local Play = {}

--[[ Beams all live shots draw together on a strong device. ]]
Play.CAP = 700
--[[ The share of the pool past which older shots draw lite. ]]
local CROWDED = 0.6

local pool = Painter.pool("ProjectileShots", Play.CAP)

--[[ The renderer's flight: where it is and which way it heads now. ]]
type Flight = { position: Vector3, direction: Vector3 }

type Hit = { t: number, P: Kit.P, k: string }

type Live = {
	flight: Flight,
	--[[ The renderer's unseen part for this flight, shown when the pool
	     is full; nil once it has stopped. ]]
	part: BasePart?,
	shown: boolean,
	key: string,
	I: Kit.Shot,
	W: Kit.Look,
	drawer: Kit.Drawer,
	t: number,
	y: number,
	passes: { Hit },
	ending: Hit?,
}

local live: { Live } = {}
local byFlight: { [Flight]: Live } = setmetatable({} :: any, { __mode = "k" })
local broken: { [string]: boolean } = {}
local launched = 0
local drawing = false

local function detail(): number
	local name = Device.tier().name
	return if name == "High" then 1 elseif name == "Medium" then 0.7 else 0.45
end

--[[ Whether `key` flies its own shot yet (its batch is ported). ]]
function Play.has(key: string?): boolean
	return key ~= nil and Styles[key] ~= nil and WeaponFx.shotCards[key] ~= nil and not broken[key]
end

--[[ Whether this flight is drawn here. ]]
function Play.tracks(flight: any): boolean
	return byFlight[flight] ~= nil
end

local function point(position: Vector3, direction: Vector3): Kit.P
	return { position.X * Kit.S, position.Z * Kit.S, math.atan2(direction.Z, direction.X) }
end

local function sample(L: Live)
	local P = point(L.flight.position, L.flight.direction)
	local I = L.I
	local n = #I.ts
	if n > 0 and L.t <= I.ts[n] then
		I.xs[n], I.ys[n], I.as[n] = P[1], P[2], P[3]
		return
	end
	table.insert(I.ts, L.t)
	table.insert(I.xs, P[1])
	table.insert(I.ys, P[2])
	table.insert(I.as, P[3])
end

--[[ A new shot of `key`'s, `headStart` seconds into its flight already. ]]
function Play.launch(flight: Flight, key: string, headStart: number)
	local card = WeaponFx.shotCards[key]
	local drawer = Styles[key]
	if not (card and drawer) or broken[key] then
		return
	end
	launched += 1
	local seed = card.card * 7 + launched % 64
	local stats = (WeaponStats.weapons :: any)[key]
	local rarity = stats and stats.rarity
	local L: Live = {
		flight = flight,
		key = key,
		I = {
			kind = card.kind,
			seed = seed,
			ph = Kit.rnd(seed, 3, 3) * Kit.TAU,
			ts = {},
			xs = {},
			ys = {},
			as = {},
			tEnd = math.huge,
		},
		W = Canvas.look(key, card.colours, rarity == "Legendary" or rarity == "Mythic"),
		drawer = drawer,
		t = math.max(headStart, 0),
		y = flight.position.Y,
		part = nil,
		shown = false,
		passes = {},
		ending = nil,
	}
	sample(L)
	local part = (flight :: any).part :: BasePart?
	if part then
		part.Transparency = 1
		part.Material = Enum.Material.Neon
		part.Color = card.colours[1]
	end
	L.part = part
	if #live == 0 then
		Painter.warmIn(pool, math.floor(120 * detail()))
	end
	table.insert(live, L)
	byFlight[flight] = L
end

--[[ It reached an enemy: through it (`pass`) or stopped in it. ]]
function Play.onModel(flight: Flight, pass: boolean)
	local L = byFlight[flight]
	if not L then
		return
	end
	local P = point(flight.position, flight.direction)
	if pass then
		table.insert(L.passes, { t = L.t, P = P, k = "pass" })
	else
		L.ending = { t = L.t, P = P, k = "body" }
	end
end

--[[ It met a wall at `position`: bounced on (drawn as going through) or
     stopped there. ]]
function Play.onWall(flight: Flight, position: Vector3, bounced: boolean)
	local L = byFlight[flight]
	if not L then
		return
	end
	local P = point(position, flight.direction)
	if bounced then
		table.insert(L.passes, { t = L.t, P = P, k = "pass" })
	else
		L.ending = { t = L.t, P = P, k = "wall" }
	end
end

--[[ It has stopped: in what it met last, or at the end of its reach. ]]
function Play.stop(flight: Flight)
	local L = byFlight[flight]
	if not L then
		return
	end
	byFlight[flight] = nil
	sample(L)
	-- its part goes back to the renderer's pool unseen
	local part = L.part
	if part and L.shown then
		part.Transparency = 1
	end
	L.part = nil
	L.shown = false
	L.I.tEnd = L.t
	local I = L.I
	local n = #I.ts
	local ending = L.ending
	if ending then
		ending.t = L.t
	else
		L.ending = { t = L.t, P = { I.xs[n], I.ys[n], I.as[n] }, k = "end" }
	end
end

--[[ The clocks, before the renderer moves its flights this frame. ]]
function Play.tick(dt: number)
	for _, L in live do
		L.t += dt
	end
end

local function drawOne(c: Canvas.Ctx, L: Live)
	local I, W, drawer = L.I, L.W, L.drawer
	drawer.f(c, I, L.t, W)
	for _, hit in L.passes do
		local a = L.t - hit.t
		if a >= 0 and a < Kit.HITLIFE then
			drawer.h(c, hit.P, a, W, I, hit.k)
		end
	end
	local ending = L.ending
	if ending and I.tEnd < math.huge then
		local a = L.t - I.tEnd
		if a >= 0 and a < Kit.HITLIFE then
			drawer.h(c, ending.P, a, W, I, ending.k)
		end
	end
end

--[[ Draws every live shot, after the renderer has moved them. ]]
function Play.draw()
	if #live == 0 then
		if drawing then
			Painter.beginIn(pool, 1)
			Painter.finishIn(pool)
			drawing = false
		end
		return
	end
	drawing = true
	local share = detail()
	local lowest = not Device.tier().projectileTrails
	local crowded = Play.CAP * share * CROWDED
	local full = math.floor(Play.CAP * share) - 4
	Painter.beginIn(pool, share)
	local keep: { Live } = {}
	--[[ Newest first, so a crowded moment drops the old shots' last
	     sparks and never a fresh shot; it is drawn over the older. ]]
	for index = #live, 1, -1 do
		local L = live[index]
		if L.I.tEnd < math.huge and L.t > L.I.tEnd + Kit.HITLIFE then
			continue
		end
		if L.I.tEnd == math.huge then
			sample(L)
		end
		local part = L.part
		if Painter.countIn(pool) >= full then
			-- no beams left: the flight's own part shows it, and nothing is drawn
			if part and not L.shown then
				part.Transparency = 0
				L.shown = true
			end
			table.insert(keep, 1, L)
			continue
		elseif part and L.shown then
			part.Transparency = 1
			L.shown = false
		end
		Kit.lite = lowest or Painter.countIn(pool) > crowded
		local c = Canvas.new(Kit.S, share)
		local ok, err = pcall(function()
			drawOne(c, L)
		end)
		if not ok then
			-- one broken drawing never stops the rest; later shots fly today's look
			broken[L.key] = true
			log.warn("%s's shot failed: %s", L.key, tostring(err))
			continue
		end
		Painter.paintIn(pool, c.items, CFrame.new(0, L.y, 0), 0, 0, Kit.S, index * 0.04)
		table.insert(keep, 1, L)
	end
	Painter.finishIn(pool)
	live = keep
end

--[[ Beams in use this frame and shots live (for a probe). ]]
function Play.count(): (number, number)
	local used = Painter.countIn(pool)
	return used, #live
end

return Play
