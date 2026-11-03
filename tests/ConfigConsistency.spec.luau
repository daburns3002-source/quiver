--!strict
--[[
	The joins between configs, which nothing else checks (2026-11-01, from
	the sweep behind `docs/BALANCE-REPORT.md`).

	Each config is sound on its own and pinned by its own spec. What goes
	wrong is the wiring between them: a weapon whose innate names a card
	that was renamed, a pet in an egg with no combat spec, an enemy a
	player can meet with nothing to tell them what it is. None of those
	crash -- they just quietly do nothing -- so they need saying out loud.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local function cards(): { [string]: Abilities.Ability }
	local byId = {}
	for _, a in Abilities.all do
		byId[a.id] = a
	end
	return byId
end

--[[ The stages a player can actually reach: every level behind a portal,
     and the tutorial. The rest are left over from earlier builds and are
     deliberately not held to these rules. ]]
local function reachable(): { [number]: boolean }
	local open: { [number]: boolean } = {}
	for _, portal in LobbyConfig.portals do
		local levels: { number } = portal.levels or {}
		for _, index in levels do
			open[index] = true
		end
	end
	open[Balance.tutorialStage] = true
	return open
end

--[[ Every enemy a reachable stage can put in front of the player, by the
     display name the NEW ENEMY! card is keyed on. Enemies that only ever
     arrive by splitting out of another are included, since the player
     meets those too. ]]
local function meetable(): { [string]: string }
	local seen: { [string]: string } = {}
	local open = reachable()
	local function note(enemy, from: string)
		if seen[enemy.displayName] == nil then
			seen[enemy.displayName] = from
		end
		--[[ `into` is the one enemy it breaks into, not a list of them. ]]
		local split = (enemy :: any).split
		if split and split.into and seen[split.into.displayName] == nil then
			seen[split.into.displayName] = from .. " (split)"
		end
	end
	for index, stage in Balance.Stages do
		if not open[index] then
			continue
		end
		local from = stage.level or stage.name
		local rooms: { number } = stage.rooms or {}
		for _, room in rooms do
			local config = Balance.Rooms[room]
			if config then
				for _, enemy in config.roster do
					note(enemy, from)
				end
			end
		end
		local fights: { Balance.WaveFight } = stage.fights or {}
		for _, fight in fights do
			for _, enemy in fight.roster do
				note(enemy, from)
			end
		end
		for _, fight in { stage.finale, stage.elite } do
			if fight then
				for _, enemy in fight.roster do
					note(enemy, from)
				end
			end
		end
	end
	return seen
end

return function(t: TestRunner.Helper)
	t.test("a weapon's innate names a real card that is not benched", function()
		local byId = cards()
		for key, stats in WeaponStats.weapons do
			local innate: { [string]: number } = stats.innate or {}
			for id, level in innate do
				local card = byId[id]
				t.notNil(card, `{key}'s innate "{id}" is not a card`)
				if card then
					t.isFalse(card.benched == true, `{key}'s innate "{id}" is benched`)
					t.isTrue(
						level >= 1 and level <= #card.levels,
						`{key}'s innate "{id}" is at level {level}, which {id} does not have`
					)
				end
			end
		end
	end)

	t.test("a card excludes only real cards, and says as much as it has", function()
		local byId = cards()
		for _, card in Abilities.all do
			local excludes: { string } = card.excludes or {}
			for _, id in excludes do
				t.notNil(byId[id], `{card.id} excludes "{id}", which is not a card`)
			end
			t.equal(#card.stats, #card.levels, `{card.id} has a stat line for every level`)
		end
	end)

	--[[ A pet in an egg with no spec hatches and then stands there; one
	     with no icon leaves a hole in the hatchery and the dex. ]]
	t.test("every hatchable pet can fight and can be drawn", function()
		local eggs: { [string]: boolean } = {}
		for _, egg in Eggs.list do
			eggs[egg.key] = true
		end
		for key, pet in Pets do
			if pet.egg then
				t.isTrue(eggs[pet.egg] == true, `{key} is in "{pet.egg}", which is not an egg`)
				t.notNil(PetCombat.pets[key], `{key} is hatchable but has no combat spec`)
				t.notNil(GearAssets.pets[key], `{key} is hatchable but has no icon`)
			end
		end
	end)

	t.test("every combat spec belongs to a pet", function()
		for key in PetCombat.pets do
			t.notNil(Pets[key], `there is a combat spec for "{key}", which is not a pet`)
		end
	end)

	--[[ Meeting an enemy with no card tells the player nothing, and leaves
	     a hole in the enemy dex, which reads off the same table. Bosses
	     are meant to have none (owner, 2026-10-25: a card for "every enemy
	     besides bosses"). ]]
	t.test("every enemy a reachable stage can show has a NEW ENEMY card", function()
		--[[ A boss is one that carries a `boss` block -- King Bloblin and
		     the Broodmother both do. Looking instead at which roster an
		     enemy sits in misses the Broodmother, who is the last *room*
		     of Thornwood rather than a wave finale. ]]
		local bosses: { [string]: boolean } = {}
		local archetypes: { [string]: Balance.EnemyConfig } = Balance.Enemies
		for _, enemy in archetypes do
			if (enemy :: any).boss then
				bosses[enemy.displayName] = true
			end
		end
		for name, from in meetable() do
			if not bosses[name] then
				t.notNil(NewEnemies.enemies[name], `{name} is met in {from} with no card`)
			end
		end
	end)

	--[[ The other way round: a card keyed to something nothing can spawn
	     never appears, and sits in the dex as a slot that can never be
	     filled. Areas whose stages are not built yet are the exception. ]]
	t.test("a NEW ENEMY card is for something that can be met", function()
		local can = meetable()
		local built: { [string]: boolean } = {}
		for index, stage in Balance.Stages do
			if reachable()[index] and stage.area then
				built[tostring(stage.area)] = true
			end
		end
		for key, enemy in NewEnemies.enemies do
			if can[key] == nil and not enemy.benched then
				--[[ Fine only while that area has no stages at all. ]]
				t.isFalse(
					built[tostring(enemy.area)] == true,
					`{key}'s card can never be shown: {enemy.area} has stages but nothing spawns it`
				)
			end
		end
	end)

	--[[ Damage is `base x (1 + rarity bonus) x areaScale`, so every weapon
	     needs both numbers to exist or it silently deals base damage. ]]
	t.test("every weapon's rarity and area are scaled", function()
		for key, stats in WeaponStats.weapons do
			t.notNil(
				WeaponStats.bonus[stats.rarity],
				`{key}'s rarity "{stats.rarity}" has no bonus`
			)
			t.notNil(WeaponStats.areaScale[stats.area], `{key}'s area {stats.area} has no scale`)
		end
	end)

	--[[ What `Config/Shop`'s `stocked` means, said out loud. An area goes on
	     sale only when a player can reach it: its weapons must have
	     pictures to show, its boss must have an item to price a Legendary
	     against, and it must have stages to earn either in.

	     The last of those is what keeps `WeaponStats.areaScale` honest. An
	     area's weapons are a quarter stronger than the one before it, so a
	     crate stocked ahead of its levels sells gear that outranks
	     everything native to the only area a player has actually played
	     (`docs/BALANCE-REPORT.md`, finding 1). ]]
	t.test("a stocked area can be reached, priced and drawn", function()
		for index, crate in Shop.crates do
			if not crate.stocked then
				continue
			end
			local staged = false
			for _, stage in Balance.Stages do
				if stage.area == crate.area then
					staged = true
					break
				end
			end
			t.isTrue(staged, `{crate.area} is stocked but has no stages to reach it`)
			local area = Economy.areas[crate.area]
			t.notNil(area, `{crate.area} is stocked but Economy has no entry for it`)
			if area then
				t.isTrue(
					ShopAssets.items[area.bossItem] ~= nil,
					`{crate.area}'s boss item {area.bossItem} has no picture`
				)
			end
			for key, stats in WeaponStats.weapons do
				if stats.area == index then
					t.isTrue(
						(ShopAssets.weapons[key] or "") ~= "",
						`{key} is for sale in {crate.area} with no picture`
					)
				end
			end
		end
	end)

	--[[ The fourteen Drowned Village weapons had no picture at all until
	     2026-11-02, because their reference sheets were written on a branch
	     that never merged -- which is the one thing that held the area back
	     that was nobody's design decision. Pinned so it cannot be lost a
	     second time. ]]
	t.test("every weapon has a shop picture", function()
		for key, _ in WeaponStats.weapons do
			t.isTrue((ShopAssets.weapons[key] or "") ~= "", `{key} has no shop picture`)
		end
	end)
end
