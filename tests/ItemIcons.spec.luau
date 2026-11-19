--!strict
--[[
	One picture per item (owner, 2026-11-19: "MAKE SURE THE ICONS IN THE
	CHESTS, EGGS, GEAR SCREEN, AND DEX ARE ALL THE SAME"). Every weapon and
	pet resolves to exactly one uploaded picture through `Util/ItemIcons`,
	the one place screens ask; `tools/check.sh` fails on a screen that reads
	`ShopAssets.weapons` or `GearAssets.pets` itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local function uploaded(id: string): boolean
	return string.match(id, "^rbxassetid://%d+$") ~= nil
end

return function(t: TestRunner.Helper)
	t.test("every weapon has one uploaded picture, its shop art", function()
		for key in WeaponStats.weapons do
			local icon = ItemIcons.weapon(key)
			t.isTrue(uploaded(icon), `{key} has no picture`)
			t.equal(icon, (ShopAssets.weapons :: { [string]: string })[key], key)
			t.equal(ItemIcons.of("weapon", key), icon, key)
		end
	end)

	t.test("every pet has one uploaded picture", function()
		for key in Pets do
			local icon = ItemIcons.pet(key)
			t.isTrue(uploaded(icon), `{key} has no picture`)
			t.equal(icon, (GearAssets.pets :: { [string]: string })[key], key)
			t.equal(ItemIcons.of("pet", key), icon, key)
		end
	end)

	t.test("no second set of weapon pictures to drift to", function()
		local gear = GearAssets :: any
		t.isNil(gear.weapons, "the outlined weapon pictures came back")
		t.isNil(gear.crateTiles, "the option C crate tiles came back")
	end)

	t.test("an item with no picture is empty, not another item's", function()
		t.equal(ItemIcons.weapon("NoSuchWeapon"), "")
		t.equal(ItemIcons.pet("NoSuchPet"), "")
	end)

	t.test("the Dex shows the same picture as every other screen", function()
		for _, book in { "Weapons", "Pets" } do
			local kind: ItemIcons.Kind = if book == "Pets" then "pet" else "weapon"
			for _, entry in DexBook.entries(book, nil) do
				t.equal(entry.icon, ItemIcons.of(kind, entry.key), entry.key)
				t.equal(entry.picture, entry.icon, entry.key)
			end
		end
	end)
end
