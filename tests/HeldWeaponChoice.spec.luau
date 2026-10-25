--!strict
--[[
	The weapon in hand (`Shared/Combat/HeldWeaponChoice`): drafting Dual Bows
	keeps the bow skin the player held (owner, 2026-10-25), a pair of that
	skin's own model, glow and arrow, animated as the Twig Bows are.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local HeldWeaponChoice = require(ReplicatedStorage.Shared.Combat.HeldWeaponChoice)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local function weapon(name: string): Weapons.Weapon
	return (Weapons :: any)[name] :: Weapons.Weapon
end

local function bowSkins(): { string }
	local out = {}
	for name, entry in Weapons :: any do
		if entry.kit == "TwigBow" then
			table.insert(out, name)
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	local card = (Abilities.byId.DualBows :: any).weapon :: string

	t.test("there are bow skins to pair", function()
		t.isTrue(#bowSkins() > 0, "no weapon plays the Twig Bow's kit")
	end)

	t.test("without the card the bow in hand stays", function()
		t.equal(HeldWeaponChoice.pick("AcornBow", nil), "AcornBow")
		t.equal(HeldWeaponChoice.pick("TwigBow", nil), "TwigBow")
	end)

	t.test("the plain Twig Bow becomes the Twig Bows", function()
		t.equal(HeldWeaponChoice.pick("TwigBow", card), "TwigBowDual")
	end)

	t.test("every bow skin becomes a pair of itself", function()
		for _, name in bowSkins() do
			local pair = HeldWeaponChoice.pick(name, card)
			t.isTrue(pair ~= card, `{name} drafted Dual Bows as the plain {card}`)
			local dual, single = weapon(pair), weapon(name)
			t.equal(dual.dualOf, name, `{pair} is not {name}'s pair`)
			t.equal(dual.parts, single.parts, `{pair} does not hold {name}'s model`)
			t.equal(dual.scale, single.scale, `{pair} is not {name}'s size`)
			t.equal(dual.rainbow, single.rainbow, `{pair} lost {name}'s rainbow`)
			t.equal(dual.bolt, single.bolt, `{pair} does not shoot {name}'s arrow`)
		end
	end)

	t.test("every pair is held and animated as the Twig Bows are", function()
		local twig = weapon("TwigBowDual")
		for _, name in bowSkins() do
			local pair = weapon(HeldWeaponChoice.pick(name, card))
			t.equal(pair.kit, "TwigBowDual", `{name}'s pair plays another kit`)
			t.equal(pair.clips, twig.clips, `{name}'s pair plays other clips`)
			t.notNil(pair.offhand, `{name}'s pair has no second bow`)
			t.equal(pair.grip, twig.grip, `{name}'s pair is gripped elsewhere`)
		end
	end)

	t.test("a glowing skin's pair glows in both hands", function()
		for _, name in bowSkins() do
			local glows = false
			for _, part in weapon(name).parts do
				glows = glows or part.glow == true
			end
			if glows then
				-- `Combat/HeldWeapon` builds every part in either hand
				local pair = weapon(HeldWeaponChoice.pick(name, card))
				t.notNil(pair.offhand, `{name}'s pair glows in one hand only`)
			end
		end
	end)

	t.test("a pair already in hand stays, and a weapon with no pair takes the card's", function()
		t.equal(HeldWeaponChoice.pick("TwigBowDual", card), "TwigBowDual")
		t.equal(HeldWeaponChoice.pick("AcornBowDual", card), "AcornBowDual")
		t.equal(HeldWeaponChoice.pick("BranchStaff", card), card)
	end)
end
