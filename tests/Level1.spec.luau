--!strict
--[[
	Level 1 (`Balance.Stages[3]`, the Mossy Glade): slimes, the Ember Wolf
	from room 6 on, and the Slime King alone in its last room (owner,
	2026-10-23).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local SLIMES = {
	[Balance.Enemies.MeleeCharger] = true,
	[Balance.Enemies.BroodSlime] = true,
	[Balance.Enemies.SlimeKing] = true,
	[Balance.Enemies.Wolf] = true,
}

--[[ The first room the wolf may appear in: the first five are the slime
     tutorial. ]]
local WOLF_FROM = 6

local function level(): { Balance.RoomConfig }
	local indices: { number } = Balance.Stages[3].rooms or {}
	local out = {}
	for _, index in indices do
		table.insert(out, Balance.Rooms[index])
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("Level 1 is ten rooms", function()
		t.equal(Balance.Stages[3].name, "Level 1")
		t.equal(#level(), 10)
	end)

	t.test("every Level 1 enemy is a slime or the wolf", function()
		for _, room in level() do
			for _, config in room.roster do
				t.isTrue(SLIMES[config] == true, `{room.name} has a {config.displayName}`)
			end
		end
	end)

	t.test("the wolf only comes from room 6", function()
		for index, room in level() do
			for _, config in room.roster do
				if config == Balance.Enemies.Wolf then
					t.isTrue(index >= WOLF_FROM, `the wolf is in room {index}`)
				end
			end
		end
	end)

	t.test("the last room is the Slime King alone", function()
		local rooms = level()
		local last = rooms[#rooms]
		t.equal(last.enemyCount, 1)
		t.equal(#last.roster, 1)
		t.isTrue(last.roster[1] == Balance.Enemies.SlimeKing, "the last room is not the Slime King")
	end)

	t.test("no other room has a boss in it", function()
		local rooms = level()
		for index = 1, #rooms - 1 do
			for _, config in rooms[index].roster do
				t.isTrue(config.boss == nil, `{rooms[index].name} has a boss`)
			end
		end
	end)
end
