--!strict
--[[
	Every blade cleave ported from the Blade Cleaves page (`Fx/Cleaves`;
	owner, 2026-11-19, direction A) draws its own card on the ground the
	blow hits, glows when its blade is a Legendary or Mythic, and is gone
	when its card's is.

	Pure: the drawings are run straight from their modules, with the
	blow's real shape (`SwingBox.shape`), plain and grown by the cards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Classes = require(ReplicatedStorage.Shared.Config.Classes) :: any
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local SwingSweep = require(ReplicatedStorage.Shared.Combat.SwingSweep)
local TestRunner = require(script.Parent.TestRunner)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons) :: any

local CleavesFolder = (StarterPlayer :: any).StarterPlayerScripts.Client.Fx.Cleaves
local Canvas = require(CleavesFolder.Canvas) :: any
local Painter = require(CleavesFolder.Painter) :: any
local Styles = require(CleavesFolder.Styles) :: any

local KIND = { Warden = "sword", Assassin = "dagger" }

--[[ Each blade with a card: its key and its class. ]]
local function carded(): { { key: string, class: string } }
	local out = {}
	for _, entry in Sandbox.weapons do
		local cleave = WeaponFx.cleaves[entry.weapon]
		if cleave and cleave.look and not Weapons[entry.weapon].dualOf then
			table.insert(out, { key = entry.weapon, class = entry.class })
		end
	end
	return out
end

--[[ A blow's three shapes as the class swings them: plain, then grown by
     Cleave and Long Reach. ]]
local function blows(class: string): { { shape: any, sweep: string } }
	local swing = Classes[class].swing
	local out: { { shape: any, sweep: string } } = {}
	for _, grown in { { 1, 0 }, { 1.5, 2 } } do
		for blow = 1, 3 do
			table.insert(out, {
				shape = SwingBox.shape(swing, blow, 3, grown[1], grown[2], 1),
				sweep = SwingSweep.forBlow(blow, 3) :: string,
			})
		end
	end
	return out
end

--[[ What `key` draws `t` seconds into `blow`, and how long it lasts. ]]
local function draw(
	key: string,
	kind: string,
	blow: { shape: any, sweep: string },
	t: number,
	detail: number?
): (any, number)
	local look = (WeaponFx.cleaves[key] :: any).look
	local I, life = Canvas.inst(kind, blow.shape, blow.sweep, nil, look.card, look.linger)
	local c = Canvas.new(Canvas.GEO[kind].s, detail or 1)
	Styles[key](c, I, t, Canvas.look(key, look.colours, Weapons[key].trailGlow ~= nil))
	return c, life
end

local function quads(c: any): number
	local n = 0
	for _, item in c.items do
		n += #item.ax - 1
	end
	return n
end

return function(t: TestRunner.Helper)
	t.test("the motes' hash is the page's", function()
		-- values from the page's own rnd(), run in a browser
		t.near(Canvas.rnd(4, 0, 11), 0.233516294509, 1e-9)
		t.near(Canvas.rnd(37, 5, 13), 0.058806263376, 1e-9)
		t.near(Canvas.rnd(165, 17, 3), 0.651769169373, 1e-9)
		t.near(Canvas.rnd(2, 9, 14), 0.077647126745, 1e-9)
	end)

	t.test("every card has its drawing, every drawing its card", function()
		for key, cleave in WeaponFx.cleaves do
			if cleave.look then
				t.notNil(Styles[key], `{key} has a card and no drawing`)
			end
		end
		for key in Styles do
			local cleave = WeaponFx.cleaves[key]
			t.isTrue(cleave ~= nil and cleave.look ~= nil, `{key} has a drawing and no card`)
		end
	end)

	t.test("no two cards share a number or colours, and each is its class's kind", function()
		local numbers: { [number]: string } = {}
		local colours: { [string]: string } = {}
		for _, entry in carded() do
			local look = (WeaponFx.cleaves[entry.key] :: any).look
			t.isNil(
				numbers[look.card],
				`{entry.key} is card {look.card}, as {numbers[look.card] or "?"} is`
			)
			numbers[look.card] = entry.key
			local mark =
				`{look.colours[1]:ToHex()}{look.colours[2]:ToHex()}{look.colours[3]:ToHex()}`
			t.isNil(colours[mark], `{entry.key} has {colours[mark] or "?"}'s colours`)
			colours[mark] = entry.key
			t.equal(look.kind, KIND[entry.class], `{entry.key} is drawn as the wrong kind`)
		end
	end)

	t.test("every cleave lies on the ground it hits, and is gone when its card's is", function()
		for _, entry in carded() do
			local kind = KIND[entry.class]
			local g = Canvas.GEO[kind]
			for _, blow in blows(entry.class) do
				local shape = blow.shape
				-- the farthest the hit reaches, and room for motes thrown off it
				local far = (
					if shape.kind == "Circle" then shape.ahead + shape.radius else shape.reach
				) + 3.5
				local held, life = draw(entry.key, kind, blow, g.T + g.H * 0.6)
				t.isTrue(#held.items > 0, `{entry.key} draws nothing while held`)
				for _, item in held.items do
					for i = 1, #item.ax do
						for _, p in { { item.ax[i], item.ay[i] }, { item.bx[i], item.by[i] } } do
							local dx, dy = (p[1] - Canvas.PX) / g.s, (p[2] - Canvas.PY) / g.s
							local d = math.sqrt(dx * dx + dy * dy)
							t.isTrue(
								d == d and d <= far,
								`{entry.key} draws {d} studs out, past {far}`
							)
						end
						local a = item.alphas[i]
						t.isTrue(a >= 0 and a <= 1, `{entry.key} has an opacity of {a}`)
					end
				end
				local gone = draw(entry.key, kind, blow, life)
				for _, item in gone.items do
					for _, a in item.alphas do
						t.isTrue(a < 0.05, `{entry.key} still shows at the end of its life`)
					end
				end
			end
		end
	end)

	t.test("a Legendary's or Mythic's cleave glows", function()
		for _, entry in carded() do
			if Weapons[entry.key].trailGlow == nil then
				continue
			end
			local kind = KIND[entry.class]
			local g = Canvas.GEO[kind]
			local c = draw(entry.key, kind, blows(entry.class)[1], g.T + g.H * 0.6)
			local lit = false
			for _, item in c.items do
				lit = lit or item.light
			end
			t.isTrue(lit, `{entry.key}'s cleave does not glow`)
		end
	end)

	t.test("a weaker device draws less, and two blows at their fullest fit a strong one", function()
		for _, entry in carded() do
			local kind = KIND[entry.class]
			local g = Canvas.GEO[kind]
			local most = 0
			for _, blow in blows(entry.class) do
				local full = draw(entry.key, kind, blow, g.T + g.H * 0.6)
				local weak = draw(entry.key, kind, blow, g.T + g.H * 0.6, 0.45)
				t.isTrue(quads(weak) < quads(full), `{entry.key} draws as much on a weak device`)
				most = math.max(most, quads(full))
			end
			t.isTrue(most * 2 <= Painter.budgetFor(1), `{entry.key} draws {most} beams in a blow`)
		end
	end)
end
