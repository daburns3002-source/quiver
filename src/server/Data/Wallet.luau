--!strict
--[[
	Every change to a player's saved wallet and weapons goes through here,
	on the server only (CLAUDE.md non-negotiable 2: the client never reports
	a coin total; it asks, and the server decides).

	Each change marks the profile for saving (`Data/PlayerData`) and tells
	its owner: `Coins` and `Gems` attributes on the Player for the HUD, and
	the whole profile over `Remotes.ProfileChanged` for the shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local PlayerData = require(script.Parent.PlayerData)

local log = Log.forTag("Wallet")
local profileChanged = Remotes.event(Remotes.ProfileChanged)

local Wallet = {}

--[[ Tells the owner, and marks the profile for saving. ]]
local function changed(player: Player, profile: SaveSchema.Profile)
	PlayerData.touch(player)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Gems", profile.gems)
	profileChanged:FireClient(player, profile)
end

function Wallet.send(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		player:SetAttribute("Coins", profile.coins)
		player:SetAttribute("Gems", profile.gems)
		profileChanged:FireClient(player, profile)
	end
end

function Wallet.addCoins(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if profile and amount > 0 then
		profile.coins += math.floor(amount)
		changed(player, profile)
	end
end

function Wallet.addGems(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if profile and amount > 0 then
		profile.gems += math.floor(amount)
		changed(player, profile)
	end
end

function Wallet.addItem(player: Player, id: string, amount: number)
	local profile = PlayerData.get(player)
	if profile and amount > 0 and Economy.items[id] then
		profile.items[id] = (profile.items[id] or 0) + math.floor(amount)
		changed(player, profile)
	end
end

function Wallet.owns(player: Player, weapon: string): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.weapons[weapon] == true
end

--[[ Pays `cost` whole, or nothing and false. ]]
function Wallet.pay(player: Player, cost: Purse.Cost): boolean
	local profile = PlayerData.get(player)
	if not profile or not Purse.pay(profile, cost) then
		return false
	end
	changed(player, profile)
	return true
end

--[[ Adds a weapon; false if it was owned already. ]]
function Wallet.grantWeapon(player: Player, weapon: string): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.weapons[weapon] then
		return false
	end
	profile.weapons[weapon] = true
	log.info("%s gets the %s", player.Name, weapon)
	changed(player, profile)
	return true
end

function Wallet.equip(player: Player, weapon: string?)
	local profile = PlayerData.get(player)
	if profile and (weapon == nil or profile.weapons[weapon]) then
		profile.equipped = weapon
		changed(player, profile)
	end
end

--[[ Saves the look picked on the class select screen. ]]
function Wallet.setLook(player: Player, look: string)
	local profile = PlayerData.get(player)
	if profile and table.find(SaveSchema.LOOKS, look) then
		profile.look = look
		changed(player, profile)
	end
end

--[[ A level is won (`StageConfig.level`, "1-3"): saved, so the next one
     opens (`Util/LevelUnlocks`). Only `RoomController` calls it, as a run
     completes; a client never reports a win. ]]
function Wallet.beatLevel(player: Player, level: string)
	local profile = PlayerData.get(player)
	if not profile or profile.levelsBeaten[level] then
		return
	end
	profile.levelsBeaten[level] = true
	log.info("%s beat level %s", player.Name, level)
	changed(player, profile)
end

--[[
	=== Endless (`docs/ENDLESS.md`) ===

	Three things are saved for Endless, and all three are written here and
	nowhere else: the deepest floor reached, the milestones claimed, and the
	mode's own currency.

	**The repeatable Soulstones vest at each boss floor** and are written to
	the profile there, not at the end of the run. Lose it all on death and
	nobody pushes; lose nothing and there is no tension. Vesting every ten
	floors is the middle, and writing at the checkpoint means a disconnect
	costs the run but never the rewards. There is no mid-run resume in v1.

	The **one-time milestones** are not on that clock: they are claimed as
	their floor is reached, with the best floor, because one of them (floor
	75) is not on a boss floor at all — `Run/RoomController.clearedFloor`
	says why.

	**Soulstones are their own currency** (owner, 2026-10-27), never `coins`
	or `gems`, so depth cannot inflate the story economy. They are not in
	`Util/Purse` either: `Purse.Cost` prices the story shop, and the Endless
	shop gets its own path when it is built.
]]

--[[ This player has reached `floor`: their best, if it is deeper than
     their old one. Returns whether it was. Server-decided
     (`Run/RoomController`) — a client never reports a floor, because the
     floor is what the board and the milestones pay on. ]]
function Wallet.recordEndlessFloor(player: Player, floor: number): boolean
	local profile = PlayerData.get(player)
	if not profile or floor ~= math.floor(floor) or floor < 1 then
		return false
	end
	if floor <= profile.endlessBest then
		return false
	end
	profile.endlessBest = floor
	log.info("%s reaches Endless floor %d", player.Name, floor)
	changed(player, profile)
	return true
end

--[[ Adds Soulstones, up to the per-run cap: `banked` is what the run has
     already paid this player, and the return is what was actually added, so
     the caller can keep its own running total. The cap is
     `Balance.Endless.runCap`, about the floor-60 total — without it,
     Endless is a gold firehose the moment one build outruns the curve. ]]
function Wallet.addSoulstones(player: Player, amount: number, banked: number): number
	local profile = PlayerData.get(player)
	local room = math.max(Balance.Endless.runCap - math.max(banked, 0), 0)
	local pay = math.floor(math.min(math.max(amount, 0), room))
	if not profile or pay <= 0 then
		return 0
	end
	profile.soulstones += pay
	changed(player, profile)
	return pay
end

--[[
	Claims every `Balance.Endless.milestones` entry at or below `floor` that
	this player has not claimed before, and returns them. One-time and per
	account: a milestone already in `endlessMilestones` is skipped, so a
	second run that passes floor 10 pays nothing for it.

	Each entry's reward pays its Soulstones today. **The egg, gear, cosmetic
	and title grants do not exist yet**: when they do, this is where they
	are granted from, reading the entry's `kind` and `rarity`, and nothing
	else about the mode changes. The milestone table itself is still
	unconfirmed by the owner, so it stays one table to swap
	(`Balance.Endless.milestones`).

	A milestone's Soulstones are **not** under the run cap: the cap is there
	so depth cannot be farmed for currency, and a milestone can be claimed
	once per account ever.
]]
function Wallet.claimEndlessMilestones(player: Player, floor: number): { Balance.EndlessMilestone }
	local profile = PlayerData.get(player)
	local claimed: { Balance.EndlessMilestone } = {}
	if not profile then
		return claimed
	end
	for _, milestone in Balance.Endless.milestones do
		local key = tostring(milestone.floor)
		if milestone.floor <= floor and not profile.endlessMilestones[key] then
			profile.endlessMilestones[key] = true
			profile.soulstones += milestone.soulstones
			table.insert(claimed, milestone)
			log.info(
				"%s claims the floor %d milestone: %s",
				player.Name,
				milestone.floor,
				milestone.name
			)
		end
	end
	if #claimed > 0 then
		changed(player, profile)
	end
	return claimed
end

--[[ Adds one of a pet; true if it was the player's first. ]]
function Wallet.grantPet(player: Player, pet: string): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local had = profile.pets[pet] or 0
	profile.pets[pet] = had + 1
	log.info("%s hatches a %s%s", player.Name, pet, if had > 0 then " (again)" else "")
	changed(player, profile)
	return had == 0
end

--[[ Puts an owned pet in a slot (1 or 2), or empties it for nil; a pet in
     the other slot moves here. ]]
function Wallet.equipPet(player: Player, slot: number, pet: string?)
	local profile = PlayerData.get(player)
	-- a whole slot only: 1.5 would save a key DataStores refuse, and NaN passes < and >
	if not profile or slot ~= math.floor(slot) or slot < 1 or slot > SaveSchema.PET_SLOTS then
		return
	end
	if pet ~= nil and not profile.pets[pet] then
		return
	end
	for other = 1, SaveSchema.PET_SLOTS do
		if pet ~= nil and profile.equippedPets[other] == pet then
			profile.equippedPets[other] = nil
		end
	end
	(profile.equippedPets :: { [number]: string? })[slot] = pet
	changed(player, profile)
end

--[[ Studio testing only (`Config/Sandbox.testUnlock`): counts an area's
     boss as beaten without its rewards, opening what waits on it. ]]
function Wallet.markBeaten(player: Player, area: string)
	local profile = PlayerData.get(player)
	if profile and not profile.bossesBeaten[area] then
		profile.bossesBeaten[area] = true
		changed(player, profile)
	end
end

--[[ An area's boss is beaten: its item, and gems (more the first time).
     Returns what was given, for the run's summary. ]]
function Wallet.beatBoss(player: Player, area: string): (number, string?)
	local profile = PlayerData.get(player)
	local config = Economy.areas[area]
	if not profile or not config then
		return 0, nil
	end
	local first = not profile.bossesBeaten[area]
	profile.bossesBeaten[area] = true
	local gems = if first then config.firstBossGems else config.bossGems
	profile.gems += gems
	profile.items[config.bossItem] = (profile.items[config.bossItem] or 0) + 1
	log.info("%s beat %s's boss: %d gems and a %s", player.Name, area, gems, config.bossItem)
	changed(player, profile)
	return gems, config.bossItem
end

return Wallet
