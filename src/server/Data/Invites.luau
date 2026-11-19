--!strict
--[[
	Invite rewards (`Config/Rewards.invite`, `Util/InviteRules`; owner,
	2026-11-18). The INVITE buttons send Roblox's invite with launch data
	naming the sender (`UI/InvitePrompt`). A friend who joins by it:

	1. **On their very first join ever** (no save stored, `PlayerData.isNew`)
	   the inviter is read from the join data (Roblox's
	   `ReferredByPlayerId`, else the launch data) and written into their
	   own save as owed. A brand new player is sent on to the tutorial's
	   server at once, so this is all the first server does, with no wait.
	2. **When they first stand in a lobby** (`Arrived`; for a new player,
	   after the tutorial), the welcome is settled: marked in their save
	   first, then, if Roblox says the two are friends, they are paid
	   `welcome` and their user id goes on the inviter's waiting list.
	3. **The inviter is paid from that list** (`check`), on whichever lobby
	   server they stand in: at once when the friend is on theirs, else
	   every `CHECK_EVERY` seconds while online, else as they next arrive.
	   Each friend once ever (`counted` in the inviter's save), at most
	   `cap` a reward day; the rest wait for a later day.

	The waiting list is its own DataStore key per inviter, apart from the
	save: one server cannot write another player's session-locked save. It
	only ever gains user ids (the newest `keep` kept); the inviter's save
	says who has been paid. Without DataStores (Studio with API access off)
	the list lives in this server's memory.

	Studio: `Remotes.DebugInvite(userId)` plays this player's first join as
	invited by `userId` (their own id pays both sides to them), with the
	friendship check skipped.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local InviteRules = require(ReplicatedStorage.Shared.Util.InviteRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardConfig = require(ReplicatedStorage.Shared.Config.Rewards)

local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local log = Log.forTag("Invites")

local Invites = {}

local STORE_NAME = if RunService:IsStudio() then "Invites_Studio" else "Invites"
--[[ Seconds between looks at an online inviter's waiting list, and at a
     welcome whose friendship check failed. ]]
local CHECK_EVERY = 120
--[[ Tries at writing a friend onto a waiting list. ]]
local WRITE_TRIES = 3
--[[ `RunSession.ARRIVED`, by name (requiring it here would loop). ]]
local ARRIVED = "Arrived"

local store: DataStore? = nil
--[[ The waiting lists when there is no DataStore, by inviter. ]]
local memory: { [number]: { number } } = {}
--[[ Players whose welcome or list is being settled (each yields). ]]
local busy: { [Player]: boolean } = {}
local checking: { [Player]: boolean } = {}
--[[ Studio's DebugInvite skips the friendship check for these. ]]
local trusted: { [Player]: boolean } = {}

local function listKey(userId: number): string
	return "u_" .. string.format("%d", userId)
end

--[[ An inviter's waiting list, or nil when it could not be read. ]]
local function readList(userId: number): { number }?
	local current = store
	if not current then
		return memory[userId] or {}
	end
	local ok, value = pcall(function()
		return current:GetAsync(listKey(userId))
	end)
	if not ok then
		log.warn("could not read %d's invites: %s", userId, tostring(value))
		return nil
	end
	return InviteRules.list(value)
end

local function pay(player: Player, prize: RewardConfig.Prize, line: string)
	Rewards.say(player, line)
	Rewards.pay(player, prize)
end

--[[ The inviter's side: friends on their list not paid for yet, paid while
     the day's cap allows. Only on a lobby server, as they stand there, so
     an egg's reveal never plays in a run. ]]
local function check(player: Player)
	local profile = PlayerData.get(player)
	if not profile or checking[player] or player:GetAttribute(ARRIVED) ~= true then
		return
	end
	checking[player] = true
	local list = readList(player.UserId)
	checking[player] = nil
	if not list or not player.Parent or #list == 0 then
		return
	end
	local paid = InviteRules.settle(profile.invites, list, Rewards.today(player))
	PlayerData.touch(player)
	for _ in paid do
		pay(player, RewardConfig.invite.inviter, "YOUR FRIEND JOINED! A GIFT FOR INVITING THEM")
	end
	if #paid > 0 then
		log.info("%s is paid for inviting %d friend(s)", player.Name, #paid)
		-- written down at once: a crash must not pay them again
		PlayerData.saveNow(player)
	end
end

--[[ Puts `friend` on `inviter`'s waiting list, and settles it at once if
     the inviter stands on this server. ]]
local function credit(inviter: number, friend: number)
	local current = store
	if current then
		for attempt = 1, WRITE_TRIES do
			local ok, problem = pcall(function()
				current:UpdateAsync(listKey(inviter), function(old: any): any
					return InviteRules.add(old, friend)
				end)
			end)
			if ok then
				break
			end
			log.warn(
				"invite list write %d of %d failed: %s",
				attempt,
				WRITE_TRIES,
				tostring(problem)
			)
			if attempt == WRITE_TRIES then
				return
			end
			task.wait(2 * attempt)
		end
	else
		memory[inviter] = InviteRules.add(memory[inviter], friend)
	end
	local here = Players:GetPlayerByUserId(inviter)
	if here then
		check(here)
	end
end

--[[ The invited friend's side, once they stand in a lobby. ]]
local function welcome(player: Player)
	local profile = PlayerData.get(player)
	if
		not profile
		or not profile.invites.owed
		or busy[player]
		or player:GetAttribute(ARRIVED) ~= true
	then
		return
	end
	local by = profile.invites.by
	busy[player] = true
	local ok, friends = true, trusted[player] == true
	if not friends then
		ok, friends = pcall(function()
			return player:IsFriendsWithAsync(by)
		end)
	end
	busy[player] = nil
	-- a failed check is tried again on the next look
	if not ok or not player.Parent or not InviteRules.welcome(profile.invites) then
		return
	end
	PlayerData.touch(player)
	if not friends then
		log.info("%s was invited by %d, who is not a friend: nothing paid", player.Name, by)
		return
	end
	log.info("%s was invited by %d: welcome paid", player.Name, by)
	pay(player, RewardConfig.invite.welcome, "A FRIEND INVITED YOU! A WELCOME GIFT")
	task.spawn(credit, by, player.UserId)
end

--[[ The profile is in: on the very first join, who invited them. ]]
local function loaded(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if PlayerData.isNew(player) then
		local ok, data = pcall(function()
			return player:GetJoinData()
		end)
		local join: { [string]: any } = if ok and type(data) == "table" then data :: any else {}
		local by = InviteRules.inviter(join.ReferredByPlayerId, join.LaunchData, player.UserId)
		if by and InviteRules.invited(profile.invites, by) then
			log.info("%s joins for the first time, invited by %d", player.Name, by)
			PlayerData.touch(player)
		end
	end
	welcome(player)
	task.spawn(check, player)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(ARRIVED):Connect(function()
		welcome(player)
		task.spawn(check, player)
	end)
end

function Invites.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and PlayerData.storeReady() then
		store = result
	else
		log.warn("invite lists kept in memory only")
	end
	PlayerData.onLoaded(loaded)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		checking[player] = nil
		trusted[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in Players:GetPlayers() do
				welcome(player)
				task.spawn(check, player)
			end
		end
	end)
	Inbound.debug(Remotes.DebugInvite, function(player, inviter)
		local profile = PlayerData.get(player)
		if not profile or type(inviter) ~= "number" then
			return
		end
		profile.invites.by, profile.invites.owed = 0, false
		trusted[player] = true
		if InviteRules.invited(profile.invites, math.floor(inviter)) then
			log.info("%s plays a first join invited by %d (Studio)", player.Name, inviter)
			welcome(player)
		end
	end)
end

return Invites
