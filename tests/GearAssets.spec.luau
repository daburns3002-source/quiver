--!strict
--[[
	The pixel art contract (owner, 2026-10-26: "every weapon ... and every pet").
	New content brings its icons and all the reveal stages with it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)
return function(t: TestRunner.Helper)
	t.test("area one weapons have pixel icons", function()
		for _, entry in ShopRules.catalog() do
			if entry.area == 1 then
				t.isTrue(
					type(GearAssets.weapons[entry.weapon]) == "string"
						and GearAssets.weapons[entry.weapon] ~= "",
					entry.weapon
				)
			end
		end
	end)
	t.test("built pets have pixel icons", function()
		for _, model in ReplicatedStorage.Shared.Config.PetModels:GetChildren() do
			t.isTrue(
				type(GearAssets.pets[model.Name]) == "string" and GearAssets.pets[model.Name] ~= "",
				model.Name
			)
		end
	end)
	t.test("every crate has closed art", function()
		for _, crate in Shop.crates do
			local art = GearAssets.crates[crate.area]
			t.isTrue(art ~= nil and art.closed ~= "", crate.area)
		end
	end)
	t.test("every egg has all four stages", function()
		for _, egg in Eggs.list do
			local art = GearAssets.eggs[egg.key]
			t.isTrue(
				art ~= nil
					and art.whole ~= ""
					and art.crack1 ~= ""
					and art.crack2 ~= ""
					and art.burst ~= "",
				egg.key
			)
		end
	end)
end
