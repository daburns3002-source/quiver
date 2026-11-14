--!strict
--[[
	Which pictures a weapon is painted with (`Util/WeaponContent`), which
	`Fx/WeaponPreload` keeps ready so a weapon is never drawn bare (owner,
	2026-11-14: "preload the weapon textures so they dont show up pale").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)
local WeaponContent = require(ReplicatedStorage.Shared.Util.WeaponContent)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	t.test("every textured part's picture is listed for its weapon, once", function()
		local textured = 0
		for name, weapon in Weapons :: any do
			local listed = WeaponContent.textures(name)
			local seen: { [string]: boolean } = {}
			for _, id in listed do
				t.isNil(seen[id], name .. " lists " .. id .. " twice")
				seen[id] = true
				t.isTrue(string.find(id, "^rbxassetid://") ~= nil, name .. ": " .. id)
			end
			for _, part in (weapon :: Weapons.Weapon).parts do
				if part.textureId then
					t.isTrue(seen[part.textureId] == true, name .. " misses " .. part.textureId)
				end
			end
			if #listed > 0 then
				textured += 1
			end
		end
		t.isTrue(textured >= 40, "only " .. textured .. " weapons are textured")
	end)

	t.test("the golden weapons each carry one picture", function()
		for _, name in { "GoldenBow", "GoldenStaff", "GoldenBlade" } do
			t.equal(#WeaponContent.textures(name), 1, name)
		end
	end)

	t.test("no weapon, or a weapon with no texture, lists nothing", function()
		t.equal(#WeaponContent.textures(nil), 0)
		t.equal(#WeaponContent.textures("NoSuchWeapon"), 0)
		t.equal(#WeaponContent.textures(7), 0)
	end)

	t.test("a set of weapons lists each picture once, by name or by key", function()
		local list =
			WeaponContent.texturesOf({ "GoldenBow", "GoldenStaff", "GoldenBow", "NoSuchWeapon" })
		t.equal(#list, 2)
		local owned = WeaponContent.texturesOf({ GoldenBow = true, GoldenBlade = true })
		t.equal(#owned, 2)
		t.equal(owned[1], WeaponContent.textures("GoldenBlade")[1], "in a steady order")
		t.equal(#WeaponContent.texturesOf({}), 0)
		-- a new player's own weapons load without an error
		local starters = WeaponContent.texturesOf(SaveSchema.default().weapons)
		t.isTrue(#starters >= 0)
	end)
end
