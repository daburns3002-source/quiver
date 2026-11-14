--!strict
--[[
	Thornwood 2-1..2-10, the Drowned Village 3-1..3-15 and Bogheart Caverns
	4-1..4-15 (`tools/area_levels.py`). The owner, 2026-11-13: "there is 10
	levels for area 1, there should also be 10 for area 2, 15 for 3, 15 for
	4", and "bosses should be in the last room of the last level".
	Relationships, not values: retuning the rooms never fails this, but
	putting a boss anywhere else, or letting a level ease off, does.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

--[[ Each area's portal, its level prefix and how many levels it has. ]]
local AREAS = {
	{ portal = 2, area = "Thornwood", prefix = "2", count = 10 },
	{ portal = 3, area = "DrownedVillage", prefix = "3", count = 15 },
	{ portal = 4, area = "BogheartCaverns", prefix = "4", count = 15 },
}

local function stages(portal: number): { Balance.StageConfig }
	local out = {}
	for _, index in LobbyConfig.portals[portal].levels :: { number } do
		table.insert(out, Balance.Stages[index])
	end
	return out
end

local function hasBoss(room: Balance.RoomConfig): boolean
	for _, config in room.roster do
		if config.boss ~= nil then
			return true
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("10 levels for Thornwood, 15 each for the Drowned Village and Bogheart", function()
		for _, spec in AREAS do
			local list = stages(spec.portal)
			t.equal(#list, spec.count, spec.area)
			for position, stage in list do
				t.equal(stage.level, `{spec.prefix}-{position}`)
				t.equal(stage.area, spec.area)
				t.equal(stage.mode, "Rooms")
			end
		end
	end)

	t.test("each boss only in the last room of its area's last level, alone", function()
		for _, spec in AREAS do
			local list = stages(spec.portal)
			for position, stage in list do
				local rooms = stage.rooms or ({} :: { number })
				for n, index in rooms do
					local room = Balance.Rooms[index]
					local last = position == #list and n == #rooms
					t.equal(hasBoss(room), last, `{stage.name}, room {n}`)
					if last then
						t.equal(room.enemyCount, 1, stage.name)
						t.equal(#room.roster, 1, stage.name)
					end
				end
			end
		end
	end)

	t.test("every level ends in its boss's arena", function()
		for _, spec in AREAS do
			local list = stages(spec.portal)
			local bossArena =
				Balance.Rooms[(list[#list].rooms or ({} :: { number }))[#(list[#list].rooms or ({} :: { number }))]].arena
			for _, stage in list do
				local rooms = stage.rooms or ({} :: { number })
				t.equal(Balance.Rooms[rooms[#rooms]].arena, bossArena, stage.name)
			end
		end
	end)

	t.test("no room is used twice, and every room is its area's", function()
		local seen: { [number]: boolean } = {}
		for _, spec in AREAS do
			for _, stage in stages(spec.portal) do
				for _, index in stage.rooms or ({} :: { number }) do
					t.isTrue(not seen[index], `room {index} used twice`)
					seen[index] = true
					local arena = Balance.Rooms[index].arena or ""
					local want = if spec.area == "Thornwood"
						then "Thorn"
						elseif spec.area == "DrownedVillage" then "Drowned"
						else "Bogheart"
					t.equal(string.sub(arena, 1, #want), want, `room {index}`)
				end
			end
		end
	end)

	--[[ Owner, 2026-11-05: "the levels should scale difficulty per room". ]]
	t.test("within a level, no fight brings less health than the one before", function()
		for _, spec in AREAS do
			for _, stage in stages(spec.portal) do
				local before = 0
				for n, index in stage.rooms or ({} :: { number }) do
					local room = Balance.Rooms[index]
					if room.encounter == nil and not hasBoss(room) then
						local total = 0
						for member = 1, room.enemyCount do
							total += room.roster[(member - 1) % #room.roster + 1].health
						end
						t.isTrue(
							total >= before,
							`{stage.name} room {n} brings {total}, under {before}`
						)
						before = total
					end
				end
			end
		end
	end)

	t.test("every level is at least as hard as the one before, and the next area harder", function()
		local previous: Balance.StageConfig? = nil
		for _, spec in AREAS do
			for _, stage in stages(spec.portal) do
				if previous then
					t.isTrue((stage.enemyHealth or 1) > (previous.enemyHealth or 1), stage.name)
					t.isTrue((stage.enemyDamage or 1) >= (previous.enemyDamage or 1), stage.name)
				end
				previous = stage
			end
		end
	end)

	t.test("every level has its Angel rooms on the 9th of each block of ten", function()
		local block, at = Balance.Waves.blockSize, Balance.Waves.angelAt
		for _, spec in AREAS do
			for _, stage in stages(spec.portal) do
				local rooms = stage.rooms or ({} :: { number })
				for n, index in rooms do
					local angel = n < #rooms and n % block == at
					local room = Balance.Rooms[index]
					t.equal(room.encounter == "Angel", angel, `{stage.name} room {n}`)
					if angel then
						t.equal(room.enemyCount, 0)
					end
				end
			end
		end
	end)
end
