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
local ClassLevelRules = require(ReplicatedStorage.Shared.Util.ClassLevelRules)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local HardRules = require(ReplicatedStorage.Shared.Util.HardRules)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local PurchaseRules = require(ReplicatedStorage.Shared.Util.PurchaseRules)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardPickRules = require(ReplicatedStorage.Shared.Util.RewardPickRules)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local StarRules = require(ReplicatedStorage.Shared.Util.StarRules)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local StoryBeatRules = require(ReplicatedStorage.Shared.Util.StoryBeatRules)
local TipRules = require(ReplicatedStorage.Shared.Util.TipRules)
local Tournament = require(ReplicatedStorage.Shared.Config.Tournament)
local TournamentRules = require(ReplicatedStorage.Shared.Util.TournamentRules)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Analytics = require(script.Parent.Analytics)
local DexPay = require(script.Parent.DexPay)
local Passes = require(script.Parent.Passes)
local PlayerData = require(script.Parent.PlayerData)

local log = Log.forTag("Wallet")
local profileChanged = Remotes.event(Remotes.ProfileChanged)
local purchased = Remotes.event(Remotes.Purchased)

local Wallet = {}

--[[ The area whose name-tag frame this profile wears (`Util/HardRules`),
     as the Player's `HardFrame`, which every client draws (`UI/NameTags`). ]]
local function showFrame(player: Player, profile: SaveSchema.Profile)
	player:SetAttribute(
		HardRules.FRAME,
		HardRules.frame(LobbyConfig.portals, Balance.Stages, profile.hardBeaten)
	)
end

--[[ Tells the owner, and marks the profile for saving. ]]
local function changed(player: Player, profile: SaveSchema.Profile)
	PlayerData.touch(player)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Gems", profile.gems)
	player:SetAttribute(TrailRules.ATTRIBUTE, profile.equippedTrail)
	showFrame(player, profile)
	profileChanged:FireClient(player, profile)
end

function Wallet.send(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		player:SetAttribute("Coins", profile.coins)
		player:SetAttribute("Gems", profile.gems)
		player:SetAttribute(TrailRules.ATTRIBUTE, profile.equippedTrail)
		showFrame(player, profile)
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

--[[ Pays `cost` whole, or nothing and false.

     Every purchase with coins, gems or Soulstones is paid here and
     nowhere else, so this is also where its buyer is told it went
     through (`Remotes.Purchased`, the burst of `UI/PurchaseFx`): once,
     after the price is taken, and never for a price that was refused.
     `rarity` is the rarity of a thing bought outright (a store weapon, a
     trail), which sizes the burst; a hatch or a crate passes none, since
     the burst plays before their reveal (`Config/PurchaseFx`). ]]
function Wallet.pay(player: Player, cost: Purse.Cost, rarity: string?): boolean
	local profile = PlayerData.get(player)
	if not profile or not Purse.pay(profile, cost) then
		return false
	end
	changed(player, profile)
	local receipt = PurchaseRules.fromCost(cost, rarity)
	if receipt then
		purchased:FireClient(player, receipt)
	end
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
	--[[ A weapon with no merge tier is held once (`ShopRules.merges`): a
	     second grant of it gives nothing. ]]
	if not new and not ShopRules.merges(weapon) then
		return false
	end
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
	if not ShopRules.merges(weapon) then
		-- no merge tier, so none in its damage
		return "C"
	end
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
	-- a weapon with no merge tier never merges (`ShopRules.merges`)
	if kind == "weapon" and not ShopRules.merges(key) then
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

--[[ Gives every golden weapon this player's class levels have earned and
     they do not hold (`ClassLevelRules.owed`): as a level 10 is reached,
     and as a profile loads, so a level reached before the weapon could be
     held is still paid. Only a weapon that can be worn (`ShopRules.find`).
     Returns what was given.

     With `class`, the class being played: one of them that is stronger
     than the weapon worn is put on by itself, as a crate's is
     (`ShopRules.upgrade`; the kid playtest, 2026-11-14). It is in hand
     from the lobby on, like any weapon chosen during a run. ]]
function Wallet.settleClassWeapons(player: Player, class: string?): { string }
	local profile = PlayerData.get(player)
	local given = {}
	if not profile then
		return given
	end
	for _, weapon in ClassLevelRules.owed(profile.classLevels) do
		if not profile.weapons[weapon] and ShopRules.find(weapon) then
			Wallet.grantWeapon(player, weapon)
			table.insert(given, weapon)
		end
	end
	local best = if class
		then ShopRules.upgrade(given, class, profile.equipped, function(weapon)
			return Wallet.weaponTier(player, weapon)
		end)
		else nil
	if best then
		Wallet.equip(player, best)
		log.info("%s takes up the %s", player.Name, best)
	end
	return given
end

--[[ A run has ended and pays `xp` to `class`'s own level
     (`Config/ClassLevels`): the levels it reaches, their gifts into the
     wallet, and the class's golden weapon at level 10. Server-decided
     (`Run/RoomController`), never asked for by a client. Returns what
     happened for the end screen, its `weapon` only if it was given now. ]]
function Wallet.addClassXp(player: Player, class: string, xp: number): ClassLevelRules.Gain?
	local profile = PlayerData.get(player)
	local gain = if profile then ClassLevelRules.add(profile.classLevels, class, xp) else nil
	if not profile or not gain then
		return nil
	end
	profile.coins += gain.coins
	profile.gems += gain.gems
	changed(player, profile)
	if #gain.reached > 0 then
		log.info("%s's %s reaches level %d", player.Name, class, gain.after.level)
	end
	local given = Wallet.settleClassWeapons(player, class)
	gain.weapon = if gain.weapon and table.find(given, gain.weapon) then gain.weapon else nil
	return gain
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

--[[ `level` is won on hard (`Util/HardRules`): saved, which opens the next
     hard level, and for an area's last level wears its frame. True the
     first time, which pays its gems (`Run/RoomController`). Decided by the
     server as the level is won, never asked for. ]]
function Wallet.beatHard(player: Player, level: string): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.hardBeaten[level] then
		return false
	end
	profile.hardBeaten[level] = true
	log.info("%s beat level %s on hard", player.Name, level)
	changed(player, profile)
	return true
end

--[[ A campaign level starts: the player's win streak is on the line
     (`Util/RunBonus`). Taken out of the save, so losing, leaving the run
     and leaving the game all end it, and returned for the run to hold. ]]
function Wallet.riskStreak(player: Player): number
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	local streak = profile.winStreak
	if streak > 0 then
		profile.winStreak = 0
		changed(player, profile)
	end
	return streak
end

--[[ The level is won: the streak the run began with (`riskStreak`) goes
     back one longer. Returns the new streak. Only `RoomController` calls
     these two. ]]
function Wallet.bankStreak(player: Player, before: number): number
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	profile.winStreak = RunBonus.won(before)
	changed(player, profile)
	return profile.winStreak
end

--[[ A level is won with these stars (`Util/StarRules`, decided by
     `RoomController` from the health and time it measured): added to the
     ones the level holds. Returns what it held before and holds now. ]]
function Wallet.addStars(player: Player, level: string, mask: number): (number, number)
	local profile = PlayerData.get(player)
	if not profile then
		return 0, 0
	end
	local had, now = StarRules.add(profile.levelStars, level, mask)
	if now ~= had then
		changed(player, profile)
	end
	return had, now
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
		profile.rewards.bossMet = true
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
	-- from now on the daily quests may ask for a boss (`RewardRules.questsFor`)
	profile.rewards.bossMet = true
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

--[[ The store's catalog as the tournament's picks read it: every stocked
     weapon, the themed sets' named. ]]
local function catalogItems(): { TournamentRules.Item }
	local out: { TournamentRules.Item } = {}
	for _, entry in ShopRules.catalog() do
		table.insert(out, { weapon = entry.weapon, set = entry.set })
	end
	return out
end

--[[ The weekly tournament (`Run/WeeklyTournament`): `score` is this
     player's new best for `week` (`TournamentRules.score`), noted in the
     save so the week pays even if the board's store never heard of it.
     Server-decided, never a client's. Returns whether it beat the old
     one. Only marked for saving: the client is told nothing new. ]]
function Wallet.noteTournament(player: Player, week: number, score: number): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local raised = TournamentRules.note(profile.tournamentWeeks, week, score)
	if raised then
		PlayerData.touch(player)
	end
	return raised
end

--[[ Pays a week that is over and takes it out of the save, in one step
     with nothing yielding between, so a week pays once (`prize` from
     `TournamentRules.prize`). False if it was paid already, or the
     profile is gone. A win counts toward the ENDLESS CHAMPION title. Its
     Soulstones are not under the run cap: the cap is a run's, and this is
     a week's. Its set weapon picks are kept to be chosen
     (`pickTournamentWeapon`); one with no set weapon left to take is
     `Tournament.pickGems` gems now. ]]
function Wallet.payTournament(player: Player, week: number, prize: TournamentRules.Prize): boolean
	local profile = PlayerData.get(player)
	local key = tostring(week)
	if not profile or profile.tournamentWeeks[key] == nil then
		return false
	end
	profile.tournamentWeeks[key] = nil
	-- set weapons to pick, and gems for any with nothing left to pick
	local left = #TournamentRules.pickable(catalogItems(), profile.weapons)
	local picks, pickGems = TournamentRules.settlePicks(profile.tournamentPicks + prize.picks, left)
	profile.tournamentPicks = picks
	profile.gems += pickGems
	profile.gems += math.max(math.floor(prize.gems), 0)
	profile.coins += math.max(math.floor(prize.coins), 0)
	profile.soulstones += math.max(math.floor(prize.soulstones), 0)
	if prize.champion then
		profile.tournamentWins += 1
	end
	player:SetAttribute(Tournament.winsAttribute, profile.tournamentWins)
	changed(player, profile)
	return true
end

--[[ Takes one of the player's tournament picks for `weapon`, a themed set
     weapon they do not own (`TournamentRules.pickable`, every stocked set
     whether or not it is on sale this week). Anything else is refused:
     it is a client's ask. True if it was granted. ]]
function Wallet.pickTournamentWeapon(player: Player, weapon: unknown): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.tournamentPicks < 1 or type(weapon) ~= "string" then
		return false
	end
	if not table.find(TournamentRules.pickable(catalogItems(), profile.weapons), weapon) then
		return false
	end
	profile.tournamentPicks -= 1
	log.info("%s picks the %s (tournament)", player.Name, weapon)
	Wallet.grantWeapon(player, weapon)
	return true
end

--[[ Picks owed with no set weapon left to take (bought meanwhile) are
     paid in gems, `Tournament.pickGems` each. On every join. ]]
function Wallet.settleTournamentPicks(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.tournamentPicks < 1 then
		return
	end
	local left = #TournamentRules.pickable(catalogItems(), profile.weapons)
	local picks, gems = TournamentRules.settlePicks(profile.tournamentPicks, left)
	if gems > 0 then
		profile.tournamentPicks = picks
		profile.gems += gems
		changed(player, profile)
	end
end

--[[ Owes the player a pick of themed set `set`'s weapons, one for each
     class, for reward `id` (`Util/RewardPickRules`: Endless room 100, the
     season pass's premium tier 30), saved until taken (`pickReward`). The
     rewards that call this pay once, and an id already owed is not owed
     twice. A set with nothing left the player can take pays
     `Tournament.pickGems` gems instead. False if the profile is gone. ]]
function Wallet.owePick(player: Player, id: string, set: string): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.rewardPicks[id] then
		return false
	end
	if #RewardPickRules.pickable(set, profile.weapons) == 0 then
		profile.gems += Tournament.pickGems
		log.info(
			"%s has every %s weapon: %d gems for %s",
			player.Name,
			set,
			Tournament.pickGems,
			id
		)
	else
		profile.rewardPicks[id] = set
		log.info("%s may pick a %s weapon (%s)", player.Name, set, id)
	end
	changed(player, profile)
	return true
end

--[[ Takes the owed reward pick `weapon` belongs to and gives it
     (`RewardPickRules.find`). It is a client's ask, so a weapon of no owed
     set, or one held once and held already, is refused. True if given. ]]
function Wallet.pickReward(player: Player, weapon: unknown): boolean
	local profile = PlayerData.get(player)
	if not profile or type(weapon) ~= "string" then
		return false
	end
	local id = RewardPickRules.find(profile.rewardPicks, weapon, profile.weapons)
	if not id then
		return false
	end
	profile.rewardPicks[id] = nil
	log.info("%s picks the %s (%s)", player.Name, weapon, id)
	Wallet.grantWeapon(player, weapon)
	return true
end

return Wallet
