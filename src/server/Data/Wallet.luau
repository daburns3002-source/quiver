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
