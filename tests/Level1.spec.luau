--!strict
--[[
	Level 1 (`Balance.Stages[3]`, the Mossy Glade): slimes and the Splitter
	Spitter from room 6 on (owner, 2026-10-23; the Spitter in the Ember
	Wilf's place, 2026-10-24: "take out the non blocky wilf enemy"). Its last
	room was the Slime King alone; since 2026-10-26 he appears only at the
	end of Mossy Glade 1-10 ("king bloblin will not appear until the end of
	level 10"), so no room of it has a boss.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local SLIMES = {
	[Balance.Enemies.MeleeCharger] = true,
	[Balance.Enemies.BroodSlime] = true,
	[Balance.Enemies.BabySlime] = true,
	[Balance.Enemies.SlimeKing] = true,
	[Balance.Enemies.SpreadShooter] = true,
}

--[[ The first room the Spitter may appear in: the first five are the slime
     tutorial. ]]
local SPITTER_FROM = 6

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

	t.test("every Level 1 enemy is a slime or the Spitter, and no Wilf", function()
		for _, room in level() do
			for _, config in room.roster do
				t.isTrue(SLIMES[config] == true, `{room.name} has a {config.displayName}`)
			end
		end
	end)

	t.test("the Spitter only comes from room 6", function()
		for index, room in level() do
			for _, config in room.roster do
				if config == Balance.Enemies.SpreadShooter then
					t.isTrue(index >= SPITTER_FROM, `the Spitter is in room {index}`)
				end
			end
		end
	end)

	t.test("no room has a boss in it, the Slime King least of all", function()
		for _, room in level() do
			for _, config in room.roster do
				t.isTrue(config.boss == nil, `{room.name} has a boss`)
			end
		end
	end)
end
