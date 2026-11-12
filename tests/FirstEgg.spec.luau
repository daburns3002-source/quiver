--!strict
--[[
	The first egg (`Util/FirstEgg`, `Config/Tutorial.firstEgg`; Fable's loop
	review, 2026-11-11): the tutorial's win leaves the player able to buy it,
	never pays a player who already can, and the lobby points at the Hatchery
	only while it is affordable and no pet is owned. And the dash tip speaks
	to phones too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local FirstEgg = require(ReplicatedStorage.Shared.Util.FirstEgg)
local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
local TestRunner = require(script.Parent.TestRunner)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

return function(t: TestRunner.Helper)
	t.test("the tutorial's egg exists and is the cheapest", function()
		local price = FirstEgg.price()
		t.isTrue(price ~= nil)
		for _, egg in Eggs.list do
			t.isTrue(egg.price >= (price :: number), egg.key .. " is cheaper than the first egg")
			if egg.key == Tutorial.firstEgg then
				t.isTrue(egg.unlock == nil, "the first egg must be open to a new player")
			end
		end
	end)

	t.test("the top-up lands exactly on the price, and never pays the rich", function()
		local price = FirstEgg.price() :: number
		for _, coins in { 0, 1, price - 1 } do
			t.equal(coins + FirstEgg.topUp(coins), price)
		end
		t.equal(FirstEgg.topUp(price), 0)
		t.equal(FirstEgg.topUp(price * 10), 0)
	end)

	t.test("the pointer shows only when the egg is affordable and no pet is owned", function()
		local price = FirstEgg.price() :: number
		t.isTrue(FirstEgg.pointWanted(price, {}))
		t.isTrue(FirstEgg.pointWanted(price + 1, nil))
		t.isFalse(FirstEgg.pointWanted(price - 1, {}))
		t.isFalse(FirstEgg.pointWanted(price, { MossSlime = 1 }))
	end)

	t.test("no tip names a key without a phone's way to do it", function()
		for _, tip in LoadingTips do
			if string.find(tip, "SPACE", 1, true) then
				t.isTrue(string.find(string.lower(tip), "phone", 1, true) ~= nil, tip)
			end
		end
	end)
end
