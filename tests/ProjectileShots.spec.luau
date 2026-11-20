--!strict
--[[
	Every bow's and staff's shot ported from the Projectile Shots page
	(`Fx/Shots`; owner, 2026-11-19, "build all 49") has its card, draws
	along its own flight and round its own hits, glows when its weapon is
	a Legendary or Mythic, and fits the device's beams.

	Pure: the drawings are run straight from their modules on a flight
	flown here, straight ahead at the class's real speed and sampled as
	`Fx/Shots/Play` samples one, then stopped in each way a shot stops.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes) :: any
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local TestRunner = require(script.Parent.TestRunner)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats) :: any

local Fx = (StarterPlayer :: any).StarterPlayerScripts.Client.Fx
local Canvas = require(Fx.Cleaves.Canvas) :: any
local Kit = require(Fx.Shots.Kit) :: any
local Play = require(Fx.Shots.Play) :: any
local Styles = require(Fx.Shots.Styles) :: any

local S = Kit.S
local KIND = { Ranger = "bow", Arcanist = "staff" }
local STOPS = { "body", "pass", "wall", "end" }

--[[ Studs a shot's drawing may reach from its flight and its hits: its
     light (5 studs), its glow, a 3-stud burst and what drifts off it. Eventide's soul leaps
     to an enemy beside the one it hit. ]]
local FAR = 7.5
local FAR_OF: { [string]: number } = { EventideBow = 11 }

--[[ Each bow and staff with a card: its key and its class. ]]
local function carded(): { { key: string, class: string } }
	local out = {}
	for _, entry in Sandbox.weapons do
		if WeaponFx.shotCards[entry.weapon] and KIND[entry.class] then
			table.insert(out, { key = entry.weapon, class = entry.class })
		end
	end
	return out
end

local function speed(kind: string): number
	local scale = if kind == "staff" then Classes.Arcanist.speedScale else 1
	return Balance.Projectile.speed * scale * S
end

local function glows(key: string): boolean
	local rarity = WeaponStats.weapons[key] and WeaponStats.weapons[key].rarity
	return rarity == "Legendary" or rarity == "Mythic"
end

--[[ What `key` draws `t` seconds into a flight that stops `tEnd` seconds
     in, the way `stop` says (a "pass" goes through an enemy halfway). ]]
local function draw(
	key: string,
	t: number,
	stop: string,
	tEnd: number,
	detail: number?
): (any, number)
	local card = WeaponFx.shotCards[key]
	local v = speed(card.kind)
	local seed = card.card * 7
	local flying = t < tEnd
	local I = {
		kind = card.kind,
		seed = seed,
		ph = Kit.rnd(seed, 3, 3) * Kit.TAU,
		ts = {},
		xs = {},
		ys = {},
		as = {},
		tEnd = if flying then math.huge else tEnd,
	}
	local upto = math.min(t, tEnd)
	local s = 0
	while s < upto do
		table.insert(I.ts, s)
		table.insert(I.xs, v * s)
		table.insert(I.ys, 0)
		table.insert(I.as, 0)
		s += 1 / 60
	end
	table.insert(I.ts, upto)
	table.insert(I.xs, v * upto)
	table.insert(I.ys, 0)
	table.insert(I.as, 0)
	local W = Canvas.look(key, card.colours, glows(key))
	local c = Canvas.new(S, detail or 1)
	local drawer = Styles[key]
	drawer.f(c, I, t, W)
	if stop == "pass" then
		local a = t - tEnd / 2
		if a >= 0 and a < Kit.HITLIFE then
			drawer.h(c, { v * tEnd / 2, 0, 0 }, a, W, I, "pass")
		end
	end
	if not flying and t - tEnd < Kit.HITLIFE then
		drawer.h(c, { v * tEnd, 0, 0 }, t - tEnd, W, I, if stop == "pass" then "wall" else stop)
	end
	return c, v * tEnd
end

local function quads(c: any): number
	local n = 0
	for _, item in c.items do
		n += #item.ax - 1
	end
	return n
end

--[[ The times a flight that stops at 0.3 s is drawn at: flying, just hit,
     the hit at its fullest, the hit nearly gone. ]]
local TIMES = { 0.12, 0.25, 0.33, 0.6, 1.15 }
local T_END = 0.3

return function(t: TestRunner.Helper)
	Kit.lite = false

	t.test("every card has its drawing, every drawing its card", function()
		for key in WeaponFx.shotCards do
			t.notNil(Styles[key], `{key} has a card and no drawing`)
			t.notNil(WeaponFx.shots[key], `{key} has a card and no shot`)
		end
		for key in Styles do
			t.notNil(WeaponFx.shotCards[key], `{key} has a drawing and no card`)
		end
	end)

	t.test("no two cards share a number, and each is its class's kind", function()
		local numbers: { [number]: string } = {}
		for _, entry in carded() do
			local card = WeaponFx.shotCards[entry.key]
			t.isNil(
				numbers[card.card],
				`{entry.key} is card {card.card}, as {numbers[card.card] or "?"} is`
			)
			numbers[card.card] = entry.key
			t.equal(card.kind, KIND[entry.class], `{entry.key} is drawn as the wrong kind`)
		end
	end)

	t.test("every shot draws along its flight and round its hits", function()
		for _, entry in carded() do
			local far = (FAR_OF[entry.key] or FAR) * S
			for _, stop in STOPS do
				for _, at in TIMES do
					local c, endX = draw(entry.key, at, stop, T_END)
					if at < T_END then
						t.isTrue(#c.items > 0, `{entry.key} draws nothing in flight`)
					end
					for _, item in c.items do
						for i = 1, #item.ax do
							for _, p in { { item.ax[i], item.ay[i] }, { item.bx[i], item.by[i] } } do
								-- from the line it flew, start to where it stopped
								local x = math.clamp(p[1], 0, endX)
								local d = math.sqrt((p[1] - x) ^ 2 + p[2] ^ 2)
								t.isTrue(
									d == d and d <= far,
									`{entry.key} ({stop}, {at} s) draws {d / S} studs off its flight`
								)
							end
							local a = item.alphas[i]
							t.isTrue(a >= 0 and a <= 1, `{entry.key} has an opacity of {a}`)
						end
					end
				end
			end
		end
	end)

	t.test("a Legendary's or Mythic's shot glows", function()
		for _, entry in carded() do
			if not glows(entry.key) then
				continue
			end
			local c = draw(entry.key, 0.12, "body", T_END)
			local lit = false
			for _, item in c.items do
				lit = lit or item.light
			end
			t.isTrue(lit, `{entry.key}'s shot does not glow`)
		end
	end)

	t.test(
		"a weaker device draws less, and four shots at their fullest fit a strong one",
		function()
			for _, entry in carded() do
				local most = 0
				for _, stop in STOPS do
					for _, at in TIMES do
						local full = quads((draw(entry.key, at, stop, T_END)))
						local weak = quads((draw(entry.key, at, stop, T_END, 0.45)))
						t.isTrue(weak <= full, `{entry.key} draws more on a weak device`)
						most = math.max(most, full)
					end
				end
				t.isTrue(most * 4 <= Play.CAP, `{entry.key} draws {most} beams at once`)
				-- the lowest tier sheds nothing and draws no tail
				Kit.lite = true
				local lite = quads((draw(entry.key, 0.12, "body", T_END)))
				Kit.lite = false
				t.isTrue(
					lite <= quads((draw(entry.key, 0.12, "body", T_END))),
					`{entry.key} draws more on the lowest tier`
				)
			end
		end
	)
end
