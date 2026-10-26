--!strict
--[[
	The NEW ENEMY! screens (`Config/NewEnemies`, owner 2026-10-25): every
	enemy a player can meet in an area's stage has one, what splits out of
	them too, and no boss does; every area's stages have their sheet; and
	the live parts sit inside the sheet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local TestRunner = require(script.Parent.TestRunner)

local SHEETS: { [string]: NewEnemies.Sheet } = NewEnemies.sheets
local ENEMIES: { [string]: NewEnemies.Enemy } = NewEnemies.enemies

--[[ Every enemy that can arrive in a stage with an area: its rooms'
     rosters, and what those split into. ]]
local function metInAreas(): { [string]: Balance.EnemyConfig }
	local met: { [string]: Balance.EnemyConfig } = {}
	local function add(config: Balance.EnemyConfig)
		if met[config.displayName] then
			return
		end
		met[config.displayName] = config
		if config.split then
			add(config.split.into)
		end
	end
	for _, stage in Balance.Stages do
		if stage.area and stage.rooms then
			for _, index in stage.rooms do
				for _, config in Balance.Rooms[index].roster do
					add(config)
				end
			end
		end
	end
	return met
end

local function inside(box: NewEnemies.Box): boolean
	local canvas = NewEnemies.canvas
	return box.x >= 0 and box.y >= 0 and box.x + box.w <= canvas.X and box.y + box.h <= canvas.Y
end

return function(t: TestRunner.Helper)
	t.test("every enemy met in an area has a screen, and no boss", function()
		for kind, config in metInAreas() do
			if config.boss then
				t.isNil(ENEMIES[kind], `{kind} is a boss`)
			else
				t.notNil(ENEMIES[kind], `{kind} has no NEW ENEMY! screen`)
			end
		end
	end)

	t.test("no screen is for a boss", function()
		for _, config: Balance.EnemyConfig in Balance.Enemies :: any do
			if config.boss then
				t.isNil(ENEMIES[config.displayName], config.displayName)
			end
		end
	end)

	t.test("every area's stages have a sheet, and every enemy's area too", function()
		for _, stage in Balance.Stages do
			if stage.area then
				t.notNil(SHEETS[stage.area], stage.area)
			end
		end
		for kind, enemy in ENEMIES do
			t.notNil(SHEETS[enemy.area], `{kind}: {enemy.area}`)
			t.isTrue(enemy.picture ~= "", `{kind} has no picture`)
			t.isTrue(#enemy.name > 0 and #enemy.description > 0, kind)
		end
	end)

	t.test("the live parts sit inside the sheet, in order down it", function()
		for area, sheet in SHEETS do
			for _, box in { sheet.picture, sheet.name, sheet.description, sheet.button } do
				t.isTrue(inside(box), area)
			end
			t.isTrue(sheet.top ~= "" and sheet.bottom ~= "", area)
			-- the enemy stands on the window's ground, above its name
			t.isTrue(sheet.picture.y + sheet.picture.h <= sheet.name.y, area)
			t.isTrue(sheet.name.y + sheet.name.h <= sheet.description.y, area)
			t.isTrue(sheet.description.y + sheet.description.h <= sheet.button.y, area)
		end
	end)
end
