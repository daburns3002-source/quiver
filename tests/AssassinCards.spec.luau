--!strict
--[[
	The Assassin's cards (`Config/Abilities`, group "dagger"; owner,
	2026-11-15): each is off without its card and on with it, for the
	Assassin alone, and the arithmetic they rest on
	(`Shared/Combat/AssassinRules`) is pinned: what behind means, how a fan
	spreads, where a phantom blade is, who a round of shadows takes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Bleed = require(ReplicatedStorage.Shared.Combat.Bleed)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local TestRunner = require(script.Parent.TestRunner)

local CARDS = {
	"TwinFangs",
	"Backstab",
	"Quickstep",
	"SerratedEdge",
	"Bleed",
	"PoisonTrail",
	"FanOfKnives",
	"DeathMark",
	"PhantomBlades",
	"ThousandCuts",
}

local function max(id: string): { [string]: number }
	return { [id] = #Abilities.byId[id].levels }
end

return function(t: TestRunner.Helper)
	--[[ The ten it drafts; the themed daggers' own seven (`weaponOnly`) are
	     `tests/ThemedDaggers.spec`'s. ]]
	t.test("the Assassin has its ten cards, each its own and with its icon", function()
		local own = 0
		for _, ability in Abilities.all do
			if ability.group == "dagger" and not ability.weaponOnly then
				own += 1
				t.notNil(table.find(CARDS, ability.id), `{ability.id} is not one of the ten`)
				local classes: { string } = ability.classes or {}
				t.isTrue(
					#classes == 1 and classes[1] == "Assassin",
					`{ability.id} is not its alone`
				)
				t.isTrue(not ability.benched, `{ability.id} is benched`)
				t.notNil(CardAssets.icons[ability.icon], `{ability.id} has no icon`)
			end
		end
		t.equal(own, #CARDS)
	end)

	--[[ Owner's pick C, as every class has it: a class upgrade at Rare,
	     Epic, Legendary and Mythic. ]]
	t.test("its class upgrades run from Rare to Mythic", function()
		local ladder: { [string]: string } = {
			PoisonTrail = "Rare",
			FanOfKnives = "Epic",
			DeathMark = "Legendary",
			PhantomBlades = "Legendary",
			ThousandCuts = "Mythic",
		}
		for id, rarity in ladder do
			t.equal(Abilities.byId[id].rarity, rarity, id)
		end
	end)

	t.test("each card is off without it and on with it", function()
		local plain = AbilityEffects.serverStats({}, "Assassin")
		local function stat(id: string)
			return AbilityEffects.serverStats(max(id), "Assassin")
		end
		t.equal(plain.melee.slamBonus, 0)
		t.equal(plain.melee.backstab, 0)
		t.equal(plain.melee.serrated, 0)
		t.equal(plain.melee.bleed, 0)
		for _, key in
			{
				"quickstep",
				"poisonTrail",
				"fanOfKnives",
				"deathMark",
				"phantomBlades",
				"thousandCuts",
			}
		do
			t.equal((plain.upgrades :: any)[key], 0, key)
		end
		t.isTrue(stat("TwinFangs").melee.slamBonus > 0, "Twin Fangs")
		t.isTrue(stat("Backstab").melee.backstab > 0, "Backstab")
		t.isTrue(stat("SerratedEdge").melee.serrated > 0, "Serrated Edge")
		t.isTrue(stat("Bleed").melee.bleed > 0, "Bleed")
		t.isTrue(stat("Quickstep").upgrades.quickstep > 0, "Quickstep")
		t.isTrue(stat("PoisonTrail").upgrades.poisonTrail > 0, "Poison Trail")
		t.equal(stat("FanOfKnives").upgrades.fanOfKnives, 7)
		t.isTrue(stat("DeathMark").upgrades.deathMark > 0, "Death Mark")
		t.equal(stat("PhantomBlades").upgrades.phantomBlades, 3)
		t.equal(stat("ThousandCuts").upgrades.thousandCuts, 1)
	end)

	--[[ Pets and weapons carry a player's power; a card stays modest
	     (PR #342). Each of these is weighed against the Assassin's own
	     strikes at the card's top level. ]]
	t.test("no card is worth more than the strikes it rides on", function()
		local config = Balance.Player.assassin
		local class = Classes.Assassin
		local swing = class.swing :: Classes.Swing
		local cooldown = Balance.Player.attackCooldown * class.cooldownScale
		local average = 0
		for _, blow in swing.damage do
			average += blow / #swing.damage
		end
		--[[ Strikes' worth dealt each second by the daggers alone. ]]
		local perSecond = average / cooldown

		-- Bleed, a full stack on one enemy
		local bleed =
			{ rate = 0.07, stacks = config.bleed.stacks, duration = config.bleed.duration }
		t.near(bleed.rate, Abilities.byId.Bleed.levels[3], 1e-9)
		t.isTrue(Bleed.rate(bleed, bleed.stacks) < perSecond * 0.3, "Bleed out-hits the daggers")
		-- Fan of Knives, every knife landing on one enemy
		local knives = Abilities.byId.FanOfKnives.levels[2] * config.knives.damage
		t.isTrue(
			knives / (config.knives.every * cooldown) < perSecond,
			"Fan of Knives out-hits the daggers"
		)
		-- Phantom Blades, one enemy cut as often as it can be
		t.isTrue(config.phantom.damage / config.phantom.again < perSecond * 0.4, "Phantom Blades")
		-- Poison Trail, a cloud standing every moment a dash allows
		local dash = class.dash :: Classes.Dash
		local cloud = config.poison.damage / config.poison.every
		t.isTrue(
			cloud * Abilities.byId.PoisonTrail.levels[2] / dash.cooldown < perSecond * 0.3,
			"Poison Trail"
		)
		t.isTrue(
			Abilities.byId.PoisonTrail.levels[2] <= dash.cooldown,
			"one cloud outlasts the wait for the next"
		)
		-- Thousand Cuts, a whole round on a full room
		t.isTrue(
			config.thousandCuts.most * config.thousandCuts.damage / config.thousandCuts.every
				< perSecond,
			"Thousand Cuts out-hits the daggers"
		)
		t.isTrue(
			config.thousandCuts.most * config.thousandCuts.gap < config.thousandCuts.every / 4,
			"a round takes most of the wait for the next"
		)
		-- Quickstep never makes the dash free
		t.isTrue(Abilities.byId.Quickstep.levels[2] < dash.cooldown / 2, "Quickstep")
	end)

	t.test("behind is behind: a strike from the back counts, one from the front never", function()
		local arc = Balance.Player.assassin.backstabArc
		local facing = Vector3.new(0, 0, -1)
		local at = Vector3.new(10, 0, 10)
		t.isTrue(
			AssassinRules.behind(facing, at, at + Vector3.new(0, 0, 4), arc),
			"straight behind"
		)
		t.isFalse(AssassinRules.behind(facing, at, at + Vector3.new(0, 0, -4), arc), "in front")
		t.isFalse(AssassinRules.behind(facing, at, at + Vector3.new(4, 0, 0), arc), "beside")
		t.isTrue(
			AssassinRules.behind(facing, at, at + Vector3.new(3, 0, 4), arc),
			"behind, off to a side"
		)
		t.isFalse(AssassinRules.behind(facing, at, at, arc), "standing on it")
		t.isFalse(
			AssassinRules.behind(Vector3.zero, at, at + Vector3.new(0, 0, 4), arc),
			"no facing"
		)
		-- height never decides it
		t.isTrue(AssassinRules.behind(facing, at, at + Vector3.new(0, 9, 4), arc))
		t.isTrue(arc > 0 and arc < 180, "more than half the ground round an enemy is behind it")
	end)

	t.test("a fan is spread evenly about the strike", function()
		local spread = Balance.Player.assassin.knives.spread
		for _, count in Abilities.byId.FanOfKnives.levels do
			local fan = AssassinRules.fan(count, spread)
			t.equal(#fan, count)
			t.near(fan[1], -math.rad(spread) / 2, 1e-9)
			t.near(fan[#fan], math.rad(spread) / 2, 1e-9)
			-- an odd fan throws one knife straight
			t.near(fan[(count + 1) / 2], 0, 1e-9)
			t.near(fan[2] - fan[1], fan[#fan] - fan[#fan - 1], 1e-9)
		end
		t.equal(#AssassinRules.fan(0, spread), 0)
		t.near(AssassinRules.fan(1, spread)[1], 0, 1e-9)
		local turned = AssassinRules.turned(Vector3.new(0, 0, -1), math.pi / 2)
		t.near(turned.Magnitude, 1, 1e-6)
		t.near(math.abs(turned.X), 1, 1e-6)
	end)

	t.test("the phantom blades are spaced round the Assassin and keep their distance", function()
		local config = Balance.Player.assassin.phantom
		local centre = Vector3.new(4, 3, -9)
		for _, count in Abilities.byId.PhantomBlades.levels do
			local first: Vector3? = nil
			for index = 1, count do
				local at =
					AssassinRules.orbit(centre, config.radius, config.turn, 12.5, index, count)
				t.near((at - centre).Magnitude, config.radius, 1e-6)
				t.near(at.Y, centre.Y, 1e-9)
				if first then
					t.isTrue((at - first).Magnitude > 1, "two blades in one place")
				else
					first = at
				end
			end
		end
		-- the same moment is the same place: what the server cuts is what is drawn
		local a = AssassinRules.orbit(centre, config.radius, config.turn, 77, 2, 3)
		local b = AssassinRules.orbit(centre, config.radius, config.turn, 77, 2, 3)
		t.near((a - b).Magnitude, 0, 1e-9)
		-- and they stand outside the daggers' own reach, so they cut what the strikes do not
		t.isTrue(config.radius - config.reach > 2, "the blades cut the Assassin's own feet")
	end)

	t.test("a round takes the nearest first, no more than it may and none out of range", function()
		local from = Vector3.zero
		local enemies = {
			far = Vector3.new(0, 0, 30),
			near = Vector3.new(2, 0, 0),
			mid = Vector3.new(0, 5, -9),
			gone = Vector3.new(400, 0, 0),
		}
		local round = AssassinRules.round(from, enemies, 45, 8)
		t.equal(#round, 3)
		t.equal(round[1], "near")
		t.equal(round[2], "mid")
		t.equal(round[3], "far")
		t.equal(#AssassinRules.round(from, enemies, 45, 2), 2)
		t.equal(#AssassinRules.round(from, {}, 45, 8), 0)
		t.equal(AssassinRules.nearest(from, enemies, 45), "near")
		t.isNil(AssassinRules.nearest(from, enemies, 1))
	end)
end
