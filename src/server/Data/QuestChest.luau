--!strict
--[[
	What the quests' bonus chest gives (`Config/Rewards.bonus`; owner,
	2026-11-14: "there should be more rewards for players"): an egg one day
	and a weapon crate the next (`RewardRules.bonusKind`), free, the best
	open to the player, as an Endless milestone's are (`Util/PrizeRules`).

	`Data/Rewards` decides that the chest is owed and marks it opened; this
	only gives. Its own module because the hatchery and the crates both
	tell `Data/Rewards` what happened (`Rewards.note`), so that module
	cannot require them. Granted on the server before anything is shown:
	the client is told what came out (`Remotes.QuestChest`) only to draw it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local PrizeRules = require(ReplicatedStorage.Shared.Util.PrizeRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardConfig = require(ReplicatedStorage.Shared.Config.Rewards)

local EndlessPrizes = require(script.Parent.EndlessPrizes)
local Hatchery = require(script.Parent.Hatchery)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("QuestChest")
local opened = Remotes.event(Remotes.QuestChest)

local QuestChest = {}

local function egg(player: Player): boolean
	local profile = PlayerData.get(player)
	local key = if profile then PrizeRules.eggKey(profile.bossesBeaten) else nil
	local result = if key then Hatchery.grantFree(player, key) else nil
	if not key or not result then
		return false
	end
	opened:FireClient(player, "Egg", key, { { pet = result.pet, new = result.new } })
	return true
end

local function crate(player: Player): boolean
	local session = RunSession.get(player)
	local index = PrizeRules.crateIndex(if session then session.loadout.class else nil)
	local weapons = if index then EndlessPrizes.crates(player, index, 1) else {}
	if not index or #weapons == 0 then
		return false
	end
	opened:FireClient(player, "Crate", index, weapons)
	return true
end

--[[ The day's kind first, the other if the player has none of it to open,
     and gems if they have neither. ]]
local function open(player: Player, kind: string)
	local given = if kind == "Egg"
		then egg(player) or crate(player)
		else crate(player) or egg(player)
	if not given then
		Wallet.addGems(player, RewardConfig.bonus.gems)
		log.info("%s has no egg or crate to open: %d gems", player.Name, RewardConfig.bonus.gems)
	end
end

function QuestChest.start()
	Rewards.openChest = open
end

return QuestChest
