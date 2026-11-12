--!strict
--[[
	An Endless milestone's eggs and crates, opened for the player the moment
	the milestone is claimed (`Balance.Endless.milestones`; owner,
	2026-11-11: "YES REAL REWARDS BUT MAKE IT MORE LIKE 5 EGGS AND 5 CRATES.
	ROBLOX GAMES HAVE THAT EXTREME REWARD. I WANT IT TO FEEL NECESSARY TO
	BEAT THESE ROOMS").

	Free, and granted here on the server before anything is shown, so a
	disconnect a moment later loses nothing: the pets and weapons are in the
	profile, which `Data/Wallet` writes. The eggs are the best egg open to
	the player and the crates the best stocked crate for the class they are
	playing (`Util/PrizeRules`); with a `rarity` on the milestone, one of
	each batch is sure to be at least that rare. The client is told what
	came out (`Remotes.EndlessPrize`) only to draw it (`UI/EndlessPrize`).

	Called once per milestone per account: `Wallet.claimEndlessMilestones`
	returns a milestone only the first time its floor is reached, and that
	is the only caller's source (`Run/RoomController.clearedFloor`).

	The crates are rolled here rather than through `Data/Shop`, which
	requires `Run/RoomController` and so cannot be required by it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local PrizeRules = require(ReplicatedStorage.Shared.Util.PrizeRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local Hatchery = require(script.Parent.Hatchery)
local PlayerData = require(script.Parent.PlayerData)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("EndlessPrizes")

local EndlessPrizes = {}

local random = Random.new()

type Weapon = { weapon: string, new: boolean }

--[[ Opens `n` of area `index`'s crate for the class the player is
     playing, unpaid (a milestone's, or the Soulstone shop's once it has
     been paid for): rolled as a bought crate is, the pity counted, the
     first sure to be at least `least` when one is named. ]]
function EndlessPrizes.crates(player: Player, index: number, n: number, least: string?): { Weapon }
	local profile = PlayerData.get(player)
	local session = RunSession.get(player)
	local class = if session then session.loadout.class else nil
	local pool = ShopRules.cratePool(index, class)
	if not profile or #pool == 0 or n < 1 then
		return {}
	end
	local mythics = Pity.mythics(pool)
	local results: { Weapon } = {}
	for i = 1, n do
		local since = profile.pity.crates
		local entry: ShopRules.Entry?
		if i == 1 and least then
			local sure = PrizeRules.guaranteed(pool, least)
			entry = sure[random:NextInteger(1, #sure)]
		elseif Pity.forced(since) and #mythics > 0 then
			entry = mythics[random:NextInteger(1, #mythics)]
		else
			entry = ShopRules.roll(pool, random:NextNumber(), random:NextNumber())
		end
		if entry then
			profile.pity.crates = Pity.after(since, entry.rarity == "Mythic")
			table.insert(results, {
				weapon = entry.weapon,
				new = Wallet.grantWeapon(player, entry.weapon),
			})
		end
	end
	log.info("%s opened %d crates of area %d", player.Name, n, index)
	return results
end

--[[ The best crate that has weapons for the class the player is playing. ]]
local function bestCrate(player: Player): number?
	local session = RunSession.get(player)
	return PrizeRules.crateIndex(if session then session.loadout.class else nil)
end

--[[ Hatches and opens what `milestone` gives `player`, and tells their
     screen what came out. Nothing for a milestone that gives neither. ]]
function EndlessPrizes.grant(player: Player, milestone: Balance.EndlessMilestone)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local pets = {}
	local eggs = milestone.eggs or 0
	if eggs > 0 then
		local key = PrizeRules.eggKey(profile.bossesBeaten)
		if key then
			pets = Hatchery.grantMany(player, key, eggs, milestone.rarity)
		end
	end
	local weapons: { Weapon } = {}
	local crates = milestone.crates or 0
	local index = if crates > 0 then bestCrate(player) else nil
	if index then
		weapons = EndlessPrizes.crates(player, index, crates, milestone.rarity)
	end
	if #pets + #weapons > 0 then
		Remotes.event(Remotes.EndlessPrize)
			:FireClient(player, milestone.floor, milestone.name, pets, weapons)
	end
end

return EndlessPrizes
