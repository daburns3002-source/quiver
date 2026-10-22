--!strict
--[[
	XP crystals and hearts.

	What matters about a crystal is that no XP is made or lost in the trip
	from kill to floor to player, and that it reaches the player whose kill it
	was. What matters about a heart is that it is taken by standing on it and
	only then. Positions are far from the live arena's, and the floor is
	cleared after every test.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Pickups = require(ServerScriptService.Server.Run.Pickups)
local TestRunner = require(script.Parent.TestRunner)

local FAR = Vector3.new(500, 0, 500)

local function unchanged(point: Vector3): Vector3
	return point
end

local function sum(values: { number }): number
	local total = 0
	for _, value in values do
		total += value
	end
	return total
end

return function(t: TestRunner.Helper)
	t.test("a kill's crystals carry exactly its XP", function()
		local enemies: { [string]: Balance.EnemyConfig } = Balance.Enemies :: any
		for id, config in enemies do
			local parts = Pickups.split(config.xpReward)
			t.equal(sum(parts), config.xpReward, `{id} lost XP in the split`)
			t.isTrue(#parts >= 1 and #parts <= Balance.Pickups.maxCrystalsPerKill)
		end

		for xp = 1, 120 do
			t.equal(sum(Pickups.split(xp)), xp, `{xp} XP split wrongly`)
		end
	end)

	t.test("no crystal carries nothing", function()
		for xp = 1, 120 do
			for _, amount in Pickups.split(xp) do
				t.isTrue(amount > 0, `{xp} XP made an empty crystal`)
			end
		end
	end)

	t.test("crystals land near the body and are all collected by their owner", function()
		local player = Players:GetPlayers()[1]
		if not player then
			return
		end

		Pickups.clear()
		local random = Random.new(7)
		local before = Pickups.count("Crystal")

		Pickups.dropForKill(player, FAR, 30, random, unchanged)
		Pickups.dropForKill(player, FAR, 14, random, unchanged)

		t.equal(Pickups.count("Crystal") - before, #Pickups.split(30) + #Pickups.split(14))

		for _, position in Pickups.positions("Crystal") do
			local flat = Vector2.new(position.X - FAR.X, position.Z - FAR.Z)
			t.isTrue(flat.Magnitude <= Balance.Pickups.crystalScatter + 1e-6, "a crystal flew off")
			t.isTrue(position.Y > 0, "a crystal sank into the floor")
		end

		local owed = Pickups.collectCrystals()
		t.equal(owed[player], 44)
		t.equal(Pickups.count("Crystal"), 0)
		Pickups.clear()
	end)

	t.test("collecting twice pays once", function()
		local player = Players:GetPlayers()[1]
		if not player then
			return
		end

		Pickups.clear()
		Pickups.dropForKill(player, FAR, 20, Random.new(1), unchanged)
		Pickups.collectCrystals()
		t.isNil(Pickups.collectCrystals()[player])
		Pickups.clear()
	end)

	t.test("walking over crystals takes them and their XP, and only in reach", function()
		local player = Players:GetPlayers()[1]
		if not player then
			return
		end

		Pickups.clear()
		Pickups.dropForKill(player, FAR, 30, Random.new(3), unchanged)
		local far = Balance.Pickups.crystalRadius + Balance.Pickups.crystalScatter + 1

		t.equal(Pickups.takeCrystals(player, FAR + Vector3.new(far, 0, 0)), 0)
		t.equal(Pickups.count("Crystal"), #Pickups.split(30))

		--[[ Standing on the body reaches every crystal it scattered. ]]
		t.isTrue(Balance.Pickups.crystalRadius >= Balance.Pickups.crystalScatter)
		t.equal(Pickups.takeCrystals(player, FAR), 30)
		t.equal(Pickups.count("Crystal"), 0)
		t.isNil(Pickups.collectCrystals()[player], "taken crystals paid again at the clear")
		Pickups.clear()
	end)

	t.test("a heart is taken by standing on it, and only then", function()
		local player = Players:GetPlayers()[1]
		if not player then
			return
		end

		Pickups.clear()
		Pickups.dropHeart(FAR)
		local reach = Balance.Pickups.heartRadius

		t.equal(Pickups.takeHearts(player, FAR + Vector3.new(reach + 0.5, 0, 0)), 0)
		t.equal(Pickups.count("Heart"), 1)

		t.equal(Pickups.takeHearts(player, FAR + Vector3.new(reach - 0.5, 3, 0)), 1)
		t.equal(Pickups.count("Heart"), 0)
		t.equal(Pickups.takeHearts(player, FAR), 0, "a heart was taken twice")
		Pickups.clear()
	end)

	t.test("collecting crystals leaves the hearts", function()
		Pickups.clear()
		Pickups.dropHeart(FAR)
		Pickups.collectCrystals()
		t.equal(Pickups.count("Heart"), 1)
		Pickups.clear()
		t.equal(Pickups.count("Heart"), 0)
	end)

	t.test("hearts are rare and heal a real share", function()
		t.isTrue(Balance.Pickups.heartChance > 0 and Balance.Pickups.heartChance < 0.25)
		t.isTrue(Balance.Pickups.heartHeal > 0 and Balance.Pickups.heartHeal <= 1)
	end)

	--[[ The crystals must be drawn in before the next wave can arrive, or
	     the level-up they bring would open on top of a fresh fight. ]]
	t.test("crystals are collected inside the pause after a clear", function()
		t.isTrue(Balance.Pickups.collectDelay < Balance.Waves.pause)
		t.isTrue(Balance.Pickups.collectDelay < Balance.Run.clearPause)
	end)
end
