--!strict
--[[
	The login calendar, the daily quests and the starter list
	(`Config/Rewards`, rules in `Util/RewardRules`), on the server.

	**Nothing a client says is progress** (non-negotiable 2). Quest progress
	is counted here from the server's own events (`Rewards.note`, called by
	the run, the hatchery and the shop as those things really happen), the
	starter list is read from the saved profile, and the day is the server's
	clock. `Remotes.RewardClaim` carries only which reward the player would
	like; the rules decide whether it is owed, mark it claimed and pay, in
	one step with no yield, so a claim sent twice pays once.

	The day is published as the player's `RewardDay` attribute so the screen
	draws the same day the server judges by.

	Studio only: `Remotes.DebugDay:FireServer(n)` moves this player's clock
	on by `n` days (1 if not given), to see a day roll without waiting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)

local PlayerData = require(script.Parent.PlayerData)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Rewards")

local Rewards = {}

--[[ Studio's day offsets, by player; never set on a live server. ]]
local offsets: { [Player]: number } = {}

function Rewards.today(player: Player): number
	return RewardRules.day(os.time()) + (offsets[player] or 0)
end

local function publish(player: Player)
	player:SetAttribute("RewardDay", Rewards.today(player))
end

--[[ `amount` of `kind` really happened for this player ("kills", "coins",
     "levels", "bosses", "hatches", "crates"). Saved with the profile; the
     owner hears of it with the next profile sent, which each of these
     events already causes (coins, a pet, a weapon), and the screen asks
     for a fresh one as it opens. ]]
function Rewards.note(player: Player, kind: string, amount: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local changed = RewardRules.note(profile.rewards, Rewards.today(player), kind, amount)
	if kind == "crates" and amount > 0 then
		profile.rewards.cratesOpened += math.floor(amount)
		changed = true
	end
	if changed then
		PlayerData.touch(player)
	end
end

local function claim(player: Player, kind: unknown, key: unknown)
	local profile = PlayerData.get(player)
	if not profile or type(kind) ~= "string" then
		return
	end
	local day = Rewards.today(player)
	local gift: RewardRules.Gift? = nil
	if kind == "login" then
		gift = RewardRules.claimLogin(profile.rewards, day)
	elseif kind == "quest" and type(key) == "string" then
		gift = RewardRules.claimQuest(profile.rewards, day, key)
	elseif kind == "starter" and type(key) == "string" then
		gift = RewardRules.claimStarter(profile, key)
	end
	if not gift then
		return
	end
	log.info(
		"%s claims %s %s: %d gems, %d coins",
		player.Name,
		kind,
		if type(key) == "string" then key else "",
		gift.gems,
		gift.coins
	)
	-- the claim is marked above; `Wallet` pays, saves and tells the owner
	Wallet.addCoins(player, gift.coins)
	Wallet.addGems(player, gift.gems)
	PlayerData.touch(player)
	Wallet.send(player)
end

function Rewards.start()
	Remotes.event(Remotes.RewardClaim).OnServerEvent:Connect(claim)
	PlayerData.onLoaded(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		offsets[player] = nil
	end)
	-- midnight UTC passes while people play
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
	if RunService:IsStudio() then
		Remotes.event(Remotes.DebugDay).OnServerEvent:Connect(function(player, days)
			local n = if type(days) == "number" and days == days then math.floor(days) else 1
			offsets[player] = (offsets[player] or 0) + math.clamp(n, 1, 30)
			publish(player)
			Wallet.send(player)
			log.info("%s is now on day %d", player.Name, Rewards.today(player))
		end)
	end
end

return Rewards
