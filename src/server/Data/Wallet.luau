--!strict
--[[
	Every change to a player's saved wallet and weapons goes through here,
	on the server only (CLAUDE.md non-negotiable 2: the client never reports
	a coin total; it asks, and the server decides).

	Each change marks the profile for saving (`Data/PlayerData`) and tells
	its owner: `Coins` and `Gems` attributes on the Player for the HUD, and
	the whole profile over `Remotes.ProfileChanged` for the shop. The trail
	worn is the Player's `Trail` attribute, which every client draws
	(`Fx/PlayerTrails`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local StoryBeatRules = require(ReplicatedStorage.Shared.Util.StoryBeatRules)
local TipRules = require(ReplicatedStorage.Shared.Util.TipRules)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Analytics = require(script.Parent.Analytics)
local DexPay = require(script.Parent.DexPay)
local Passes = require(script.Parent.Passes)
local PlayerData = require(script.Parent.PlayerData)

local log = Log.forTag("Wallet")
local profileChanged = Remotes.event(Remotes.ProfileChanged)

local Wallet = {}

--[[ Tells the owner, and marks the profile for saving. ]]
local function changed(player: Player, profile: SaveSchema.Profile)
	PlayerData.touch(player)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Gems", profile.gems)
	player:SetAttribute(TrailRules.ATTRIBUTE, profile.equippedTrail)
	profileChanged:FireClient(player, profile)
end

function Wallet.send(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		player:SetAttribute("Coins", profile.coins)
		player:SetAttribute("Gems", profile.gems)
		player:SetAttribute(TrailRules.ATTRIBUTE, profile.equippedTrail)
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

--[[ One more C copy of a weapon or pet (`Util/MergeRules`). ]]
local function addCopy(store: { [string]: MergeRules.Counts }, key: string): MergeRules.Counts
	local held: MergeRules.Counts = store[key] or {}
	held.C = (held.C or 0) + 1
	store[key] = held
	return held
end

--[[ Adds a weapon, one C copy to merge (`Util/MergeRules`); true if it was
     the player's first. A duplicate is saved as that copy, never lost. ]]
function Wallet.grantWeapon(player: Player, weapon: string): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local new = not profile.weapons[weapon]
	profile.weapons[weapon] = true
	addCopy(profile.tiers.weapons, weapon)
	DexPay.pay(player, profile, "Weapons", weapon)
	log.info("%s gets the %s%s", player.Name, weapon, if new then "" else " (another copy)")
	changed(player, profile)
	return new
end

--[[ The best merge tier held of a weapon, "C" for one not in the save
     (`Run/RunSession` scales the run's damage by it). ]]
function Wallet.weaponTier(player: Player, weapon: string?): string
	local profile = PlayerData.get(player)
	local held = profile and weapon and profile.tiers.weapons[weapon]
	return MergeRules.best(held) or "C"
end

--[[ The best merge tier held of a pet, "C" for one not in the save (a
     Studio sandbox pet); `Combat/PetCombat` scales its blows by it. Read
     from the save each time, so a merge counts from the next blow. ]]
function Wallet.petTier(player: Player, pet: string): string
	local profile = PlayerData.get(player)
	return MergeRules.best(profile and profile.tiers.pets[pet]) or "C"
end

--[[ Merges three copies of a weapon or pet at `tier` into one of the next
     (`Util/MergeRules`); false, and nothing changed, when the player has
     not three or `tier` is S. ]]
function Wallet.merge(player: Player, kind: string, key: string, tier: string): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local store = if kind == "weapon"
		then profile.tiers.weapons
		elseif kind == "pet" then profile.tiers.pets
		else nil
	local held = store and store[key]
	if not held or not MergeRules.merge(held, tier) then
		return false
	end
	if kind == "pet" then
		profile.pets[key] = MergeRules.total(held)
	end
	log.info("%s merged three %s %s", player.Name, tier, key)
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

--[[ Gives a trail (`Config/Trails`). Returns whether it is new. ]]
function Wallet.grantTrail(player: Player, key: string): boolean
	local profile = PlayerData.get(player)
	if not profile or not TrailRules.get(key) or profile.trails[key] then
		return false
	end
	profile.trails[key] = true
	log.info("%s gets the %s trail", player.Name, key)
	changed(player, profile)
	return true
end

--[[ Gives every trail this player has earned and does not hold: a beaten
     boss's, Starfall once every class has its floor. Called as a profile
     loads (so a boss beaten before trails existed still pays), as a boss
     falls and as a class reaches a floor. Returns what was given. ]]
function Wallet.settleTrails(player: Player): { string }
	local profile = PlayerData.get(player)
	if not profile then
		return {}
	end
	local due = TrailRules.due(profile)
	for _, key in due do
		Wallet.grantTrail(player, key)
	end
	return due
end

--[[ Wears a held trail, or none (nil). ]]
function Wallet.equipTrail(player: Player, key: string?)
	local profile = PlayerData.get(player)
	if profile and (key == nil or profile.trails[key]) and profile.equippedTrail ~= key then
		profile.equippedTrail = key
		changed(player, profile)
	end
end

--[[ This player has reached `floor` of Endless as `class`: kept if it is
     that class's deepest, for Starfall (`Config/Trails.endless`).
     Server-decided like the best floor (`Run/RoomController`). ]]
function Wallet.recordClassFloor(player: Player, class: string, floor: number)
	local profile = PlayerData.get(player)
	if
		not profile
		or floor ~= math.floor(floor)
		or floor <= (profile.endlessClassBest[class] or 0)
	then
		return
	end
	profile.endlessClassBest[class] = floor
	changed(player, profile)
	Wallet.settleTrails(player)
end

--[[ Saves the look picked on the class select screen. ]]
function Wallet.setLook(player: Player, look: string)
	local profile = PlayerData.get(player)
	if profile and table.find(SaveSchema.LOOKS, look) then
		profile.look = look
		changed(player, profile)
	end
end

--[[ An enemy is met (`Run/RunSession.meetEnemy`): written down for the
     Dex, with its gems the first time (`Data/DexPay`). ]]
function Wallet.meetEnemy(player: Player, kind: string)
	local profile = PlayerData.get(player)
	if profile and not profile.enemiesSeen[kind] then
		profile.enemiesSeen[kind] = true
		DexPay.pay(player, profile, "Enemies", kind)
		changed(player, profile)
	end
end

--[[ A level is won (`StageConfig.level`, "1-3"): saved, so the next one
     opens (`Util/LevelUnlocks`). Only `RoomController` calls it, as a run
     completes; a client never reports a win. ]]
function Wallet.beatLevel(player: Player, level: string): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.levelsBeaten[level] then
		return false
	end
	profile.levelsBeaten[level] = true
	-- whoever has beaten the level the tutorial waits on has been through it
	-- (`SaveSchema.migrate` reads an older profile the same way)
	if level == Tutorial.untilBeaten then
		profile.tutorialDone = true
	end
	log.info("%s beat level %s", player.Name, level)
	changed(player, profile)
	-- true the first time, which pays the level's free egg
	return true
end

--[[ The tutorial is won (`SaveSchema` version 8): saved, so later joins
     may skip it. Only `RoomController` calls it, as the tutorial completes. ]]
function Wallet.finishTutorial(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.tutorialDone then
		return
	end
	profile.tutorialDone = true
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

	This pays each entry's Soulstones and records it. Its eggs and crates
	are opened by the caller with what this returns (`Data/EndlessPrizes`,
	from `Run/RoomController`), since rolling them needs the hatchery and
	this module sits under it.

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
	-- a duplicate is one more C copy to merge (`Util/MergeRules`)
	profile.pets[pet] = MergeRules.total(addCopy(profile.tiers.pets, pet))
	DexPay.pay(player, profile, "Pets", pet)
	log.info("%s hatches a %s%s", player.Name, pet, if had > 0 then " (again)" else "")
	changed(player, profile)
	return had == 0
end

--[[ Puts an owned pet in a slot (1 or 2, and 3 with the Extra Pet Slot
     pass), or empties it for nil; a pet in another slot moves here. Emptying
     is allowed in any slot the save holds, so a pass taken back never traps
     a pet. ]]
function Wallet.equipPet(player: Player, slot: number, pet: string?)
	local profile = PlayerData.get(player)
	-- a whole slot only: 1.5 would save a key DataStores refuse, and NaN passes < and >
	if not profile or slot ~= math.floor(slot) or slot < 1 or slot > SaveSchema.PET_SLOTS then
		return
	end
	if pet ~= nil and slot > StoreRules.petSlots(Passes.owned(player)) then
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

--[[ The story beat of `area` has been watched (`Remotes.StorySeen`): kept
     only for an area with a beat whose boss this player has beaten. ]]
function Wallet.sawStory(player: Player, area: unknown)
	local profile = PlayerData.get(player)
	if
		not profile
		or not StoryBeatRules.isArea(area)
		or not profile.bossesBeaten[area :: string]
		or profile.storySeen[area :: string]
	then
		return
	end
	profile.storySeen[area :: string] = true
	changed(player, profile)
end

--[[ A first-time tip has been on screen (`Remotes.TipSeen`): kept once,
     only for a tip (`Util/TipRules.mark`), so it never shows again. ]]
function Wallet.sawTip(player: Player, key: unknown): boolean
	local profile = PlayerData.get(player)
	if profile and TipRules.mark(profile.tipsSeen, key) then
		changed(player, profile)
		return true
	end
	return false
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
	if first then
		local beaten = 0
		for _ in profile.bossesBeaten do
			beaten += 1
		end
		Analytics.areaUnlocked(player, area, beaten)
	end
	local gems = if first then config.firstBossGems else config.bossGems
	profile.gems += gems
	profile.items[config.bossItem] = (profile.items[config.bossItem] or 0) + 1
	log.info("%s beat %s's boss: %d gems and a %s", player.Name, area, gems, config.bossItem)
	changed(player, profile)
	-- the area's Legendary trail, the first time (`Config/Trails`)
	Wallet.settleTrails(player)
	return gems, config.bossItem
end

return Wallet
