--!strict
--[[
	The nineteen cards of 2026-11-27 (docs/CARD-IDEAS.md, owner: "Build all
	nineteen"; `Config/Abilities`, docs/CLASS-CARDS.md): each is a card of
	its own classes with a picture and a sound, its level reaches the stat
	the server reads (and nothing without it), the two shared pieces built
	for them hold their rules (the stillness channel and Serpent Arrow's
	weave), and no card is stronger than the live card it sits beside
	(PR #342: power is the pets' and the weapons'). What needs live enemies
	(a root, a tether, a rune, a leap) is seen in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local ProjectileFlight = require(ReplicatedStorage.Shared.Combat.ProjectileFlight)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Stillness = require(ReplicatedStorage.Shared.Combat.Stillness)
local TestRunner = require(script.Parent.TestRunner)
local Types = require(ReplicatedStorage.Shared.Types)

local MELEE = { "Assassin", "Warden" }

--[[ Each card: its classes, the stat it reaches (`upgrades.x` or
     `melee.x`), and its sound. ]]
type Card = { classes: { string }, side: "upgrades" | "melee", stat: string, sound: string }
local CARDS: { [string]: Card } = {
	HuntersMark = {
		classes = { "Assassin", "Ranger" },
		side = "upgrades",
		stat = "huntersMark",
		sound = "fx_hunters_mark",
	},
	PinDown = { classes = { "Ranger" }, side = "upgrades", stat = "pinDown", sound = "fx_pin_down" },
	SerpentArrow = {
		classes = { "Ranger" },
		side = "upgrades",
		stat = "serpentArrow",
		sound = "fx_serpent_bite",
	},
	TrickShot = {
		classes = { "Ranger" },
		side = "upgrades",
		stat = "trickShot",
		sound = "fx_trick_shot",
	},
	Barrage = { classes = { "Ranger" }, side = "upgrades", stat = "barrage", sound = "fx_barrage" },
	Skyfall = { classes = { "Ranger" }, side = "upgrades", stat = "skyfall", sound = "fx_skyfall" },
	Siphon = { classes = { "Arcanist" }, side = "upgrades", stat = "siphon", sound = "fx_siphon" },
	Overcharge = {
		classes = { "Arcanist" },
		side = "upgrades",
		stat = "overcharge",
		sound = "fx_overcharge",
	},
	ManaBurn = {
		classes = { "Arcanist" },
		side = "upgrades",
		stat = "manaBurn",
		sound = "fx_mana_burn",
	},
	RuneCircle = {
		classes = { "Arcanist" },
		side = "upgrades",
		stat = "runeCircle",
		sound = "fx_rune_circle",
	},
	ArcaneTether = {
		classes = { "Arcanist" },
		side = "upgrades",
		stat = "arcaneTether",
		sound = "fx_arcane_tether",
	},
	Starfall = {
		classes = { "Arcanist", "Assassin" },
		side = "upgrades",
		stat = "starfallEvery",
		sound = "fx_starfall",
	},
	Singularity = {
		classes = { "Arcanist" },
		side = "upgrades",
		stat = "singularity",
		sound = "fx_singularity",
	},
	Bellow = { classes = MELEE, side = "melee", stat = "bellow", sound = "fx_bellow" },
	StoneSkin = { classes = MELEE, side = "melee", stat = "stoneSkin", sound = "fx_stone_skin" },
	GraveChains = {
		classes = MELEE,
		side = "melee",
		stat = "graveChains",
		sound = "fx_grave_chains",
	},
	BladeCyclone = {
		classes = MELEE,
		side = "melee",
		stat = "bladeCyclone",
		sound = "fx_blade_cyclone",
	},
	ReapersHarvest = {
		classes = MELEE,
		side = "melee",
		stat = "reapersHarvest",
		sound = "fx_reapers_harvest",
	},
	Colossus = { classes = { "Warden" }, side = "melee", stat = "colossus", sound = "fx_colossus" },
}

--[[ A cast or volley as `FiringSystem` builds it. ]]
local function volley(counts: { [string]: number }, class: string): { Types.ShotSpec }
	local pipeline = ShotPipeline.new()
	for _, stage in AbilityEffects.stages(counts, class) do
		pipeline:addStage(stage)
	end
	return pipeline:build({
		damage = Balance.Player.baseDamage,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, -1),
	})
end

return function(t: TestRunner.Helper)
	t.test("each is a dealt card of its own classes, with a picture and a sound", function()
		local count = 0
		for id, card in CARDS do
			count += 1
			local ability = Abilities.byId[id]
			t.notNil(ability, `{id} is no card`)
			if not ability then
				continue
			end
			local dealt = table.clone(ability.classes or {})
			table.sort(dealt)
			t.equal(table.concat(dealt, ","), table.concat(card.classes, ","), `{id}'s classes`)
			t.isTrue(ability.benched ~= true and ability.weaponOnly ~= true, `{id} is not dealt`)
			t.equal(#ability.levels, #ability.stats, `{id} has a level with no words`)
			local picture = (CardAssets.icons :: any)[ability.icon]
			t.isTrue(type(picture) == "string" and picture ~= "", `{id} has no picture`)
			local sound = (Sounds :: any)[card.sound]
			t.isTrue(sound ~= nil and sound.id ~= "", `{id}'s sound {card.sound} is silent`)
		end
		t.equal(count, 19)
	end)

	t.test("a card's level reaches the stat the server reads, and nothing without it", function()
		local plain = AbilityEffects.serverStats({}, "Warden") :: any
		for id, card in CARDS do
			t.equal(plain[card.side][card.stat], 0, `{id} is on without its card`)
			local top = #Abilities.byId[id].levels
			local stats = AbilityEffects.serverStats({ [id] = top }, card.classes[1]) :: any
			local level = Abilities.byId[id].levels[top]
			local want = if id == "Starfall" then math.round(1 / level) else level
			t.near(stats[card.side][card.stat], want, 1e-9, `{id} at its top level`)
		end
		-- Starfall's levels rise and its falls come sooner
		local levels = Abilities.byId.Starfall.levels
		t.equal(math.round(1 / levels[1]), 9)
		t.equal(math.round(1 / levels[2]), 7)
	end)

	t.test("Colossus makes the Warden tougher by its share and no more", function()
		local plain = AbilityEffects.serverStats({}, "Warden")
		local giant = AbilityEffects.serverStats({ Colossus = 1 }, "Warden")
		t.near(giant.maxHealth, plain.maxHealth * (1 + Balance.Player.colossus.health), 1e-6)
		t.near(giant.damage, plain.damage, 1e-9, "Colossus is not a damage card")
	end)

	--[[ The stillness channel (`Shared/Combat/Stillness`). ]]
	t.test("a stillness charge fills while still, and starts again when spent", function()
		t.equal(Stillness.heldFor(nil, 10), 0)
		t.near(Stillness.heldFor(8, 10), 2, 1e-9)
		t.isFalse(Stillness.ready(nil, -math.huge, 1, 10), "ready while moving")
		t.isFalse(Stillness.ready(9.5, -math.huge, 1, 10), "ready too soon")
		t.isTrue(Stillness.ready(8, -math.huge, 1, 10), "not ready after 2 s")
		-- spent at 9.5: not again until 10.5, however long the stand
		t.isFalse(Stillness.ready(8, 9.5, 1, 10))
		t.isTrue(Stillness.ready(8, 9.5, 1, 10.5))
		t.near(Stillness.progress(8, -math.huge, 4, 10), 0.5, 1e-9)
		t.equal(Stillness.progress(nil, -math.huge, 4, 10), 0)
		t.equal(Stillness.progress(0, -math.huge, 4, 10), 1)
	end)

	--[[ Serpent Arrow's weave: a stage on every arrow, flown by the shared
	     flight on both sides. ]]
	t.test("Serpent Arrow weaves every arrow about its line", function()
		for _, spec in volley({}, "Ranger") do
			t.isNil(spec.weave, "an arrow weaves without the card")
		end
		local specs = volley({ SerpentArrow = 1, FrontArrow = 1 }, "Ranger")
		t.isTrue(#specs >= 2)
		for _, spec in specs do
			t.equal(spec.weave, Balance.Player.serpent.amplitude)
		end
		local base = Vector3.new(0, 0, -1)
		local wavelength = Balance.Player.serpent.wavelength
		-- leaving, it heads off the line; a quarter on it runs along it
		local first = ProjectileFlight.weaveHeading(base, 1, 0)
		t.isTrue(math.abs(first.X) > 0.1, "the weave starts straight")
		local crest = ProjectileFlight.weaveHeading(base, 1, wavelength / 4)
		t.near(crest.X, 0, 1e-6)
		t.near(crest.Magnitude, 1, 1e-6)
	end)

	t.test("Trick Shot brings a bounce of its own, on top of Bouncy Wall's", function()
		t.equal(volley({}, "Ranger")[1].bounces, 0)
		t.equal(volley({ TrickShot = 1 }, "Ranger")[1].bounces, Balance.Player.trickShot.bounces)
		t.equal(
			volley({ TrickShot = 1, BouncyWall = 1 }, "Ranger")[1].bounces,
			Balance.Player.trickShot.bounces + Abilities.byId.BouncyWall.levels[1]
		)
	end)

	--[[ What rides a shot (`ClassUpgrades.dress`). ]]
	t.test("Serpent Arrow, Trick Shot and Mana Burn dress each shot", function()
		local ClassUpgrades = (require :: any)(ServerScriptService.Server.Combat.ClassUpgrades)
		local function session(upgrades: { [string]: number }): any
			local held = AbilityEffects.serverStats({}, "Ranger").upgrades :: any
			for key, value in upgrades do
				held[key] = value
			end
			return { upgrades = held }
		end
		local plain: any = {}
		ClassUpgrades.dress(session({}), plain)
		t.isNil(plain.trick)
		t.isNil(plain.healthy)
		t.isNil(plain.blight)
		local dressed: any = {}
		ClassUpgrades.dress(
			session({ serpentArrow = 0.15, trickShot = 0.5, manaBurn = 0.4 }),
			dressed
		)
		t.near(dressed.blight, 0.15, 1e-9)
		t.near(dressed.trick, 0.5, 1e-9)
		t.near(dressed.healthy, 0.4, 1e-9)
	end)

	--[[ PR #342: no new card stronger than the live one it sits beside. ]]
	t.test("no card outdoes its peer", function()
		local function top(id: string): number
			local levels = Abilities.byId[id].levels
			return levels[#levels]
		end
		local player = Balance.Player
		-- a mark on one enemy is no more than Sunder's on everything struck
		t.isTrue(top("HuntersMark") <= top("Sunder") + 1e-9, "Hunter's Mark")
		-- the cyclone's cut is no more than an orbiting orb's
		t.isTrue(player.bladeCyclone.orbit.damage <= player.waveTwo.orbit.damage, "Blade Cyclone")
		-- three Starfall meteors are less than one Meteor, the Mythic
		t.isTrue(
			player.starfall.meteors * player.starfall.damage <= player.meteor.damage,
			"Starfall"
		)
		-- a Barrage arrow is less than Sniper Shot's arrow
		t.isTrue(player.barrage.damage <= player.sniper.damage, "Barrage")
		-- a Skyfall arrow is less than the Phoenix, the Ranger's other Mythic
		t.isTrue(player.skyfall.damage <= player.phoenix.damage, "Skyfall")
		-- the shout and the quake are less than a Shockwave's and a Titan's slam
		t.isTrue(top("Bellow") <= player.shockwave.share * 1.2 + 1e-9, "Bellow")
		t.isTrue(player.colossus.damage <= player.earthbreaker.slamDamage, "Colossus")
		-- Siphon heals less a cast than Bloodthirst does a kill
		t.isTrue(top("Siphon") <= top("Bloodthirst"), "Siphon")
		-- Overcharge at most doubles, and costs something
		t.isTrue(top("Overcharge") <= 2 and player.overcharge.cost > 0, "Overcharge")
		-- Mana Burn at full health is under Execute's bonus at low health
		t.isTrue(top("ManaBurn") <= top("Execute"), "Mana Burn")
		-- a tether shares less than the blow
		t.isTrue(top("ArcaneTether") < 0.5, "Arcane Tether")
		-- the guard softens a hit and never removes it; a harvest never
		-- makes a swing free
		t.isTrue(top("StoneSkin") < 1 and top("ReapersHarvest") < 1)
		t.isTrue(player.singularity.damage <= player.blackHole.implodeDamage, "Singularity")
	end)
end
