--!strict
--[[
	The season pass on the server (`Config/Season`, rules in
	`Util/SeasonRules`; `docs/SEASON.md`).

	**Nothing a client says is progress** (non-negotiable 2). Season XP is
	counted here from the server's own events: `Data/Rewards.note` passes on
	every one (rooms and floors from `Run/RoomController`, levels won), and
	the quests' claims pass on how many were claimed. The month is the
	server's clock. `Remotes.SeasonClaim` carries only which tier of which
	track; the rules decide whether it is owed, mark it claimed and pay, in
	one step with no yield, so a claim sent twice pays once.

	**A season that has ended is settled** as the profile loads, every
	`Season.checkEvery` seconds for those playing, and before anything is
	counted, claimed or bought: everything reached and not claimed is paid
	(`SeasonRules.rollover`), with a toast, and the state starts over. What
	is owed is paid only in the lobby (eggs and crates show their reveals),
	so a player under the title or in a run is settled once they stand
	there.

	**Premium** is the "SeasonPass" developer product, granted once per
	receipt by `Data/Purchases` (which asks `canBuy` before it prompts, and
	calls `grantPremium` as it grants).

	The Player's `SeasonShift` attribute is this player's Studio clock shift
	in seconds (0 on a live server), so the tab counts down from the same
	time the server judges by; `SeasonTitle` is the season title worn, drawn over
	the name tag by every client (`UI/NameTags`).

	Studio only: `Remotes.DebugSeason:FireServer(days, xp)` moves this
	player's season clock on by `days` (1 if not given, 0 for none) and adds
	about `xp` season XP (in whole quests' worth).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SeasonConfig = require(ReplicatedStorage.Shared.Config.Season)
local SeasonRules = require(ReplicatedStorage.Shared.Util.SeasonRules)

local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Season")

local Season = {}

--[[ The Player attributes this keeps. ]]
Season.SHIFT = "SeasonShift"
Season.TITLE = "SeasonTitle"

--[[ Studio's clock shifts, by player, in seconds; never set live. ]]
local shifts: { [Player]: number } = {}

--[[ The server's time for this player's season. ]]
function Season.now(player: Player): number
	return os.time() + (shifts[player] or 0)
end

local function publish(player: Player)
	player:SetAttribute(Season.SHIFT, shifts[player] or 0)
	local profile = PlayerData.get(player)
	player:SetAttribute(Season.TITLE, if profile then profile.title else nil)
end

--[[ Pays what tiers came to: coins and gems here, eggs and crates by
     `Data/QuestChest` (with their reveals), the trail through the wallet,
     the title into the profile. ]]
local function pay(player: Player, total: SeasonRules.Total)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	Wallet.addCoins(player, total.coins)
	Wallet.addGems(player, total.gems)
	local trail = total.trail
	if trail then
		Wallet.grantTrail(player, trail)
	end
	--[[ Tier 30's earned weapons (`SeasonDef.weapons`): held once each. ]]
	local weapons: { string } = total.weapons or {}
	for _, weapon in weapons do
		Wallet.grantWeapon(player, weapon)
	end
	local title = total.title
	if title and SeasonConfig.titles[title] then
		profile.titles[title] = true
		--[[ Worn at once if none is: one claimed for the player at the
		     season's end has no WEAR to press, since the tab has moved on. ]]
		if not profile.title then
			profile.title = title
			publish(player)
		end
	end
	local give = Rewards.givePrize
	if give and total.eggs + total.crates > 0 then
		give(player, total.eggs, total.crates)
	end
	PlayerData.touch(player)
	Wallet.send(player)
end

--[[ Whether the player stands in the lobby (the Player's `Arrived`, and
     no run going): only there may eggs and crates be opened in front of
     them. ]]
local function inLobby(player: Player): boolean
	return player:GetAttribute("Arrived") == true and Workspace:GetAttribute("InLobby") == true
end

--[[ Moves the player's state to the season running now, paying what the
     one that ended still owed. What is owed is paid only in the lobby, so
     no reveal comes up under the title or in a run: until then the state
     waits (and a run in the new month counts no XP until it moves). ]]
local function settle(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if not inLobby(player) and #SeasonRules.owed(profile.season) > 0 then
		return
	end
	local before = profile.season.key
	local total, def = SeasonRules.rollover(profile.season, Season.now(player))
	if profile.season.key == before then
		return
	end
	PlayerData.touch(player)
	log.info("%s's season moves from '%s' to '%s'", player.Name, before, profile.season.key)
	if total then
		pay(player, total)
		Rewards.say(
			player,
			if def
				then string.format("SEASON %d ENDED! YOUR REWARDS WERE CLAIMED FOR YOU", def.number)
				else "A SEASON ENDED! YOUR REWARDS WERE CLAIMED FOR YOU"
		)
	else
		Wallet.send(player)
	end
end

--[[ `amount` of `kind` really happened (`Data/Rewards.note`): its season
     XP, and a toast for each new tier. ]]
function Season.note(player: Player, kind: string, amount: number)
	if not SeasonConfig.xp[kind] then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	settle(player)
	local added, before, after = SeasonRules.gain(profile.season, Season.now(player), kind, amount)
	if added <= 0 then
		return
	end
	PlayerData.touch(player)
	if after > before then
		Rewards.say(player, string.format("SEASON TIER %d! CLAIM IT IN REWARDS", after))
	end
end

local function claim(player: Player, track: unknown, tier: unknown)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	settle(player)
	local state = profile.season
	local def = SeasonConfig.seasons[state.key]
	local total = SeasonRules.zero()
	if track == "all" then
		local n
		total, n = SeasonRules.claimAll(state)
		if n == 0 then
			return
		end
		log.info("%s claims %d season tiers", player.Name, n)
	else
		local prize = SeasonRules.claim(state, track, tier)
		if not prize then
			return
		end
		-- `claim` paid it, so `track` is one of the two
		SeasonRules.add(total, prize, def, track :: SeasonRules.Track)
		log.info("%s claims season tier %s %s", player.Name, tostring(track), tostring(tier))
	end
	-- marked above, before anything is paid
	PlayerData.touch(player)
	pay(player, total)
end

local function wear(player: Player, key: unknown)
	local profile = PlayerData.get(player)
	if not profile or (key ~= nil and type(key) ~= "string") then
		return
	end
	if key ~= nil and not profile.titles[key :: string] then
		return
	end
	profile.title = key :: string?
	PlayerData.touch(player)
	publish(player)
	Wallet.send(player)
end

--[[ Whether this player may be prompted for the Season Pass now. ]]
function Season.canBuy(player: Player): boolean
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	settle(player)
	return SeasonRules.canBuy(profile.season, Season.now(player))
end

--[[ A Season Pass receipt is being granted (`Data/Purchases`): premium
     for the season running (kept for the next one if none is). Into the
     profile only; the purchase saves it. ]]
function Season.grantPremium(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	settle(player)
	profile.season.premium = true
	PlayerData.touch(player)
	Rewards.say(player, "PREMIUM OPEN! CLAIM YOUR SEASON REWARDS")
	log.info("%s has premium for season '%s'", player.Name, profile.season.key)
end

function Season.start()
	Rewards.onNote = Season.note
	Inbound.on(Remotes.SeasonClaim, claim)
	Inbound.on(Remotes.SeasonTitle, wear)
	PlayerData.onLoaded(function(player)
		settle(player)
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		shifts[player] = nil
	end)
	-- a month ends while people play
	task.spawn(function()
		while true do
			task.wait(SeasonConfig.checkEvery)
			for _, player in Players:GetPlayers() do
				settle(player)
			end
		end
	end)
	if RunService:IsStudio() then
		Inbound.debug(Remotes.DebugSeason, function(player, days, xp)
			local n = if type(days) == "number" and days == days then math.floor(days) else 1
			shifts[player] = (shifts[player] or 0) + math.clamp(n, 0, 400) * 86400
			settle(player)
			-- and season XP, as if that many quests' worth had been earned
			local profile = PlayerData.get(player)
			if profile and type(xp) == "number" and xp == xp and xp > 0 then
				local quests = math.ceil(xp / SeasonConfig.xp.quests)
				local _, before, after =
					SeasonRules.gain(profile.season, Season.now(player), "quests", quests)
				PlayerData.touch(player)
				log.info("%s gains season XP: tier %d to %d", player.Name, before, after)
			end
			publish(player)
			Wallet.send(player)
			log.info(
				"%s's season clock is now %s",
				player.Name,
				(SeasonRules.month(Season.now(player)))
			)
		end)
	end
end

return Season
