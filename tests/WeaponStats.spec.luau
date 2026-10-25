--!strict
--[[
	What a weapon is worth (`Config/WeaponStats`, the owner's ladder of
	2026-10-25): every weapon has its rarity and area, rarer hits harder
	(Common +0%, Uncommon +5%, Rare +15%, Epic +25%, Legendary +40%, Mythic
	+70%), every Legendary and Mythic has an extra effect made of real
	cards, and the damage the server deals follows the weapon in hand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	t.test("every weapon has its rarity and area", function()
		for name, weapon in Weapons :: any do
			if weapon.dualOf then
				continue
			end
			t.notNil(WeaponStats.weapons[name], `{name} has no WeaponStats entry`)
		end
	end)

	t.test("the owner's ladder: rarer hits harder", function()
		local bonus = WeaponStats.bonus :: any
		t.equal(bonus.Common, 0)
		t.near(bonus.Uncommon, 0.05, 1e-9)
		t.near(bonus.Rare, 0.15, 1e-9)
		t.near(bonus.Epic, 0.25, 1e-9)
		t.near(bonus.Legendary, 0.4, 1e-9)
		t.near(bonus.Mythic, 0.7, 1e-9)
	end)

	t.test("every Legendary and Mythic has an extra effect of real cards", function()
		for name, stats in WeaponStats.weapons do
			local top = stats.rarity == "Legendary" or stats.rarity == "Mythic"
			t.isTrue(
				top == (stats.innate ~= nil),
				`{name}: only Legendaries and Mythics carry an effect`
			)
			local innate: { [string]: number } = stats.innate or {}
			for id in innate do
				t.notNil(Abilities.byId[id], `{name}'s effect names {id}, which is no card`)
			end
			if top then
				t.notNil(stats.effect, `{name} has no effect text`)
			end
		end
	end)

	t.test("the weapon in hand sets the damage", function()
		local base = AbilityEffects.serverStats({}, "Ranger").damage
		t.near(AbilityEffects.serverStats({}, "Ranger", "TwigBow").damage, base, 1e-6)
		t.near(AbilityEffects.serverStats({}, "Ranger", "AcornBow").damage, base * 1.05, 1e-6)
		t.near(AbilityEffects.serverStats({}, "Ranger", "GladeSpiritBow").damage, base * 1.7, 1e-6)
		-- a pair of bows is its single bow's
		t.near(
			AbilityEffects.serverStats({}, "Ranger", "GladeSpiritBowDual").damage,
			base * 1.7,
			1e-6
		)
	end)

	t.test("a Legendary's effect reaches the shot, on the server and the client alike", function()
		local server = #AbilityEffects.stages({}, "Ranger", "EmberFangBow")
		local plain = #AbilityEffects.stages({}, "Ranger")
		t.isTrue(server > plain, "the Ember Fang Bow's burn is not in the pipeline")
		local client = AbilityEffects.clientStats({}, "Ranger", "EmberFangBow")
		t.equal(#AbilityEffects.stages(client.abilities, client.class, client.weapon), server)
	end)
end
