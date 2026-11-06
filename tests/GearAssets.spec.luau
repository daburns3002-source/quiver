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
	--[[ An egg hatches from its four cut stages, or from its area's Tripo
	     model with the area's one picture on the hatchery stand
	     (`UI/Reveal` draws the cracks and burst over a model itself). ]]
	t.test("every egg has all four stages, or a model and a picture", function()
		for _, egg in Eggs.list do
			local art = GearAssets.eggs[egg.key]
			local staged = art ~= nil
				and art.whole ~= ""
				and art.crack1 ~= ""
				and art.crack2 ~= ""
				and art.burst ~= ""
			local modelled = GearAssets.models.eggs[egg.area] ~= nil
				and (GearAssets.areaPictures.eggs[egg.area] or "") ~= ""
			t.isTrue(staged or modelled, egg.key)
		end
	end)

	-- every area's egg and chest is a model (owner, 2026-11-06: "wire them in")
	t.test("every egg's area and every crate's area has its model", function()
		for _, egg in Eggs.list do
			local model = GearAssets.models.eggs[egg.area]
			t.isTrue(model ~= nil and model.mesh ~= "" and model.texture ~= "", egg.key)
		end
		for _, crate in Shop.crates do
			local model = GearAssets.models.chests[crate.area]
			t.isTrue(model ~= nil and model.mesh ~= "" and model.texture ~= "", crate.area)
		end
	end)
end
