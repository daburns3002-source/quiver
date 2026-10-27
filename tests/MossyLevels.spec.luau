--!strict
--[[
	Mossy Glade 1-1..1-10, the owner's level plan (2026-10-26): "level 1-1
	should have 10 rooms, 1-2 should have 10 rooms, 1-3 should have 15
	rooms, 1-4 should have 15 rooms. 1-5 should be 20 waves in 1 room ...
	1-10 should have 25 ending in king bloblin. each level should be harder
	than the last", King Bloblin nowhere before the end of 1-10, and "enemy
	health needs to be scaled up as well, the game is too easy currently".
	Relationships, not values: retuning the curve never fails this, but
	flattening it does.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)
local Waves = require(ServerScriptService.Server.Run.Waves)

local KING = Balance.Enemies.SlimeKing
--[[ The old twenty-room Mossy Glade run, which 1-1 must be harder than. ]]
local OLD_RUN = 5

local SHAPE: { { mode: string, size: number } } = {
	{ mode = "Rooms", size = 10 },
	{ mode = "Rooms", size = 10 },
	{ mode = "Rooms", size = 15 },
	{ mode = "Rooms", size = 15 },
	{ mode = "Waves", size = 20 },
	{ mode = "Waves", size = 20 },
	{ mode = "Waves", size = 20 },
	{ mode = "Waves", size = 20 },
	{ mode = "Waves", size = 20 },
	{ mode = "Waves", size = 25 },
}

local function levels(): { Balance.StageConfig }
	local out = {}
	for _, index in LobbyConfig.portals[1].levels :: { number } do
		table.insert(out, Balance.Stages[index])
	end
	return out
end

--[[ Every fight a level holds, in order: its rooms', or each wave's. ]]
local function fights(stage: Balance.StageConfig): { { count: number, roster: { any } } }
	local out = {}
	if stage.mode == "Waves" then
		local total = stage.waves or 0
		for wave = 1, total do
			local d = Waves.describe(wave, total, stage)
			if d.count > 0 then
				table.insert(out, { count = d.count, roster = d.roster })
			end
		end
	else
		for _, index in stage.rooms or ({} :: { number }) do
			local room = Balance.Rooms[index]
			table.insert(out, { count = room.enemyCount, roster = room.roster })
		end
	end
	return out
end

local function hasKing(roster: { any }): boolean
	for _, config in roster do
		if config == KING then
			return true
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("ten levels, 1-1 to 1-10, all in the Mossy Glade", function()
		local all = levels()
		t.equal(#all, 10)
		for position, stage in all do
			t.equal(stage.level, `1-{position}`)
			t.equal(stage.name, `Mossy Glade 1-{position}`)
			t.equal(stage.area, "MossyGlade")
			t.isTrue(not stage.tutorial, stage.name)
		end
	end)

	t.test("rooms and waves as the owner counted them", function()
		for position, stage in levels() do
			local want = SHAPE[position]
			t.equal(stage.mode, want.mode, stage.name)
			if want.mode == "Rooms" then
				t.equal(#(stage.rooms or {}), want.size, stage.name)
			else
				t.equal(stage.waves, want.size, stage.name)
				-- one room: its arena, a glade one
				local arena = Balance.Rooms[stage.arena or 0]
				t.notNil(arena, `{stage.name} has no arena`)
				t.isTrue(string.sub(arena.arena or "", 1, 5) == "Glade", `{stage.name}'s arena`)
			end
		end
	end)

	t.test("the room levels' rooms are glade rooms, none used twice", function()
		local used: { [number]: string } = {}
		for _, stage in levels() do
			for _, index in stage.rooms or ({} :: { number }) do
				local room = Balance.Rooms[index]
				t.notNil(room, `{stage.name} names room {index}`)
				t.isTrue(string.sub(room.arena or "", 1, 5) == "Glade", `{room.name} is no glade`)
				t.isNil(used[index], `room {index} is in {used[index]} and {stage.name}`)
				used[index] = stage.name
			end
		end
	end)

	t.test("every level is harder than the last, 1-1 harder than the old run", function()
		local old = Balance.Stages[OLD_RUN]
		local health, damage = old.enemyHealth or 1, old.enemyDamage or 1
		local biggest = 0
		for _, stage in levels() do
			local h, d = stage.enemyHealth or 1, stage.enemyDamage or 1
			t.isTrue(h > health, `{stage.name}'s enemy health {h} is not above {health}`)
			t.isTrue(d > damage, `{stage.name}'s enemy damage {d} is not above {damage}`)
			-- damage rises more gently than health
			t.isTrue(d - damage <= h - health, `{stage.name}'s damage climbs faster than health`)
			health, damage = h, d
			-- and the fights never shrink
			local most = 0
			for _, fight in fights(stage) do
				most = math.max(most, fight.count)
			end
			t.isTrue(most >= biggest, `{stage.name}'s biggest fight is smaller than before`)
			biggest = most
		end
	end)

	t.test("Thornwood, after the glade, is harder than all of it", function()
		local last = levels()[10]
		local thornwood = Balance.Stages[Balance.campaign[#Balance.campaign]]
		t.equal(thornwood.area, "Thornwood")
		t.isTrue((thornwood.enemyHealth or 1) > (last.enemyHealth or 1))
		t.isTrue((thornwood.enemyDamage or 1) >= (last.enemyDamage or 1))
	end)

	t.test("King Bloblin only as 1-10's last wave, alone", function()
		local all = levels()
		for position, stage in all do
			local list = fights(stage)
			for n, fight in list do
				local last = position == #all and n == #list
				t.equal(hasKing(fight.roster), last, `{stage.name}, fight {n}`)
				if last then
					t.equal(fight.count, 1)
					t.equal(#fight.roster, 1)
				else
					for _, config in fight.roster do
						t.isTrue(config.boss == nil, `{stage.name} fight {n} has a boss`)
					end
				end
			end
		end
		local ten = all[10]
		local total = ten.waves or 0
		t.equal(Waves.kindIn(ten, total, total), "Boss")
	end)

	t.test("King Bloblin is in no Mossy Glade room at all", function()
		for index, room in Balance.Rooms do
			if string.sub(room.arena or "", 1, 5) == "Glade" then
				t.isFalse(hasKing(room.roster), `room {index} ({room.name}) has King Bloblin`)
			end
		end
	end)

	t.test("wave levels fight glade enemies only, no stand-in boss wave", function()
		local glade = {
			[Balance.Enemies.MeleeCharger] = true,
			[Balance.Enemies.BroodSlime] = true,
			[Balance.Enemies.SpreadShooter] = true,
			[KING] = true,
		}
		for _, stage in levels() do
			if stage.mode == "Waves" then
				local total = stage.waves or 0
				for wave = 1, total do
					local d = Waves.describe(wave, total, stage)
					if d.kind ~= "Valkyrie" and d.kind ~= "Angel" then
						t.isTrue(d.count > 0, `{stage.name} wave {wave} is empty`)
						for _, config in d.roster do
							t.isTrue(
								glade[config] == true,
								`{stage.name} wave {wave}: {config.displayName}`
							)
						end
					end
				end
			end
		end
	end)
end
