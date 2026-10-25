--!strict
--[[
	The playtest sandbox's lists (`Config/Sandbox`): every weapon in the game
	can be picked, each as a real class, and the dummies copy a real enemy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	--[[ A bow skin's pair is seen by drafting Dual Bows with the skin in
	     hand (`tests/HeldWeaponChoice.spec`), so only the Twig Bows' pair is
	     on the menu. ]]
	t.test("every weapon is in the sandbox's menu, once", function()
		local listed: { [string]: number } = {}
		for _, entry in Sandbox.weapons do
			listed[entry.weapon] = (listed[entry.weapon] or 0) + 1
		end
		for name, weapon in Weapons :: any do
			if weapon.dualOf and name ~= "TwigBowDual" then
				continue
			end
			t.equal(listed[name], 1, `{name} is listed once in Config/Sandbox`)
		end
	end)

	t.test("each listed weapon is real and held as a real class", function()
		for _, entry in Sandbox.weapons do
			t.notNil((Weapons :: any)[entry.weapon], `{entry.weapon} is a Config/Weapons entry`)
			t.notNil(Classes[entry.class], `{entry.weapon}'s class {entry.class} exists`)
		end
	end)

	t.test("a class's own weapon is listed under that class", function()
		for name, class in Classes do
			local found = false
			for _, entry in Sandbox.weapons do
				if entry.weapon == class.weapon then
					found = entry.class == name
				end
			end
			t.isTrue(found, `{class.weapon} is listed as a {name} weapon`)
		end
	end)

	t.test("the dummies copy a real enemy", function()
		t.notNil(
			(Balance.Enemies :: any)[Sandbox.dummy.archetype],
			"the dummy archetype is a Balance.Enemies key"
		)
		t.isTrue(#Sandbox.dummy.spots >= 1, "at least one dummy")
	end)
end
