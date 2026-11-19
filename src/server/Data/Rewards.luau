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

	**Playtime gifts** (`Util/PlaytimeRules`, 2026-11-18) are kept here too:
	the session's clock is taken up as the profile loads (`join`: a new
	session after `Config/Rewards.playtime.gap` away), stamped every few
	seconds so the next server can tell the player was here, and a gift
	that opens is said on the toast. `RewardClaim("playtime", index)` claims
	one; CLAIM ALL takes every one that waits. `Remotes.DebugPlaytime(n)`
	(Studio) moves the session `n` minutes on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GiftRules = require(ReplicatedStorage.Shared.Util.GiftRules)
local GoalRules = require(ReplicatedStorage.Shared.Util.GoalRules)
local Goals = require(ReplicatedStorage.Shared.Config.Goals)
local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PageRules = require(ReplicatedStorage.Shared.Util.PageRules)
local PlaytimeRules = require(ReplicatedStorage.Shared.Util.PlaytimeRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local StarRules = require(ReplicatedStorage.Shared.Util.StarRules)

local PlayerData = require(script.Parent.PlayerData)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Rewards")

local Rewards = {}

local toast = Remotes.event(Remotes.RewardToast)

--[[ Gives what the quests' bonus chest holds ("Egg" or "Crate") once the
     rules have marked it opened. Set by `Data/QuestChest`, which may
     require the hatchery and the crates; this module may not, since both
     of those call `note` here. ]]
Rewards.openChest = nil :: ((player: Player, kind: string) -> ())?
--[[ Gives a goal's eggs and crates (`Config/Goals`), by the same module
     and for the same reason. ]]
Rewards.givePrize = nil :: ((player: Player, eggs: number, crates: number) -> ())?
--[[ Told when the day's login reward has just been claimed, alone or in
     CLAIM ALL: the moment `Data/Notify` may ask about notifications. Set
     by that module, which requires this one. ]]
Rewards.dailyClaimed = nil :: ((player: Player) -> ())?
--[[ Hears everything `note` hears, and the quests claimed: the season's
     XP (`Data/Season`, which requires this module, so it sets the hook). ]]
Rewards.onNote = nil :: ((player: Player, kind: string, amount: number) -> ())?

--[[ Studio's day offsets, by player; never set on a live server. ]]
local offsets: { [Player]: number } = {}
--[[ Playtime gifts ready when last looked, to say each once it opens. ]]
local giftsSaid: { [Player]: number } = {}
--[[ Seconds between looks at the playtime clocks. ]]
local PLAYTIME_EVERY = 5

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
--[[ Says `line` to `player` on the rewards' toast, with no gems on it. ]]
function Rewards.say(player: Player, line: string)
	toast:FireClient(player, line, 0, 0)
end

function Rewards.note(player: Player, kind: string, amount: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local changed, steps = RewardRules.note(profile.rewards, Rewards.today(player), kind, amount)
	--[[ How a quest is going, said as it happens: half way, and done
	     (owner, 2026-11-14: "the quests need to be clearer"). ]]
	for _, step in steps do
		local quest = RewardConfig.quests[step.key]
		local words = string.format(quest.words, quest.goal)
		toast:FireClient(
			player,
			if step.done
				then "QUEST DONE! " .. words
				else string.format("QUEST: %s  %d/%d", words, step.have, step.goal),
			0,
			0
		)
	end
	if kind == "crates" and amount > 0 then
		profile.rewards.cratesOpened += math.floor(amount)
		changed = true
	end
	--[[ And for good: the Goals' lifetime counters (`Config/Goals.counted`),
	     kept here because everything that should count already tells this. ]]
	if GoalRules.count(profile.stats, kind, amount) then
		changed = true
	end
	--[[ A level won fills the gift box (`Util/GiftRules`), and says so the
	     moment a gift is ready. ]]
	if kind == "levels" and amount > 0 then
		local before = GiftRules.ready(profile.gift)
		if GiftRules.won(profile.gift) then
			changed = true
		end
		if GiftRules.ready(profile.gift) > before then
			toast:FireClient(player, "GIFT READY! OPEN IT IN REWARDS", 0, 0)
		end
	end
	if changed then
		PlayerData.touch(player)
	end
	local hook = Rewards.onNote
	if hook then
		hook(player, kind, amount)
	end
end

--[[ Pays a prize already marked claimed (a goal's step, a Dex page's
     chest, a playtime gift, an invite's reward): its coins and gems here,
     its eggs and crates by `Data/QuestChest`, which shows what came out. ]]
function Rewards.pay(player: Player, prize: Goals.Prize)
	Wallet.addCoins(player, prize.coins or 0)
	Wallet.addGems(player, prize.gems or 0)
	local eggs, crates = prize.eggs or 0, prize.crates or 0
	local give = Rewards.givePrize
	if give and eggs + crates > 0 then
		give(player, eggs, crates)
	end
	PlayerData.touch(player)
	Wallet.send(player)
end

local function claim(player: Player, kind: unknown, key: unknown)
	local profile = PlayerData.get(player)
	if not profile or type(kind) ~= "string" then
		return
	end
	local day = Rewards.today(player)
	local loginBefore = profile.rewards.loginDay
	local gift: RewardRules.Gift? = nil
	if kind == "bonus" then
		--[[ The chest for all three quests: marked opened here, in one
		     step, then given (`Data/QuestChest`), so a claim sent twice
		     opens one chest. ]]
		local what = RewardRules.claimBonus(profile.rewards, day)
		local open = Rewards.openChest
		if what and open then
			PlayerData.touch(player)
			log.info("%s opens the quests' chest: %s", player.Name, what)
			open(player, what)
			Wallet.send(player)
		end
		return
	elseif kind == "goal" then
		--[[ A goal's next step (`Config/Goals`): marked here in one step,
		     then paid; its eggs and crates are given by `Data/QuestChest`. ]]
		local prize = GoalRules.claim(profile, key)
		if prize then
			log.info("%s claims a step of goal %s", player.Name, tostring(key))
			Rewards.pay(player, prize)
		end
		return
	elseif kind == "page" then
		--[[ A finished Dex page's chest (`Util/PageRules`), the same way. ]]
		local prize = PageRules.claim(profile, key)
		if prize then
			log.info("%s opens the chest of Dex page %s", player.Name, tostring(key))
			Rewards.pay(player, prize)
		end
		return
	elseif kind == "stars" then
		--[[ An area's star chest (`Util/StarRules`), the same way. ]]
		local prize = StarRules.claim(profile, key)
		if prize then
			log.info("%s opens star chest %s", player.Name, tostring(key))
			Rewards.pay(player, prize)
		end
		return
	elseif kind == "playtime" then
		--[[ A playtime gift (`Util/PlaytimeRules`): the one asked for if
		     the server's clock has opened it, marked and paid. ]]
		local prize = PlaytimeRules.claim(profile.playtime, os.time(), key)
		if prize then
			log.info("%s claims playtime gift %s", player.Name, tostring(key))
			giftsSaid[player] = PlaytimeRules.ready(profile.playtime, os.time())
			Rewards.pay(player, prize)
		end
		return
	elseif kind == "gift" then
		--[[ The gift box (`Util/GiftRules`): one gift a claim, marked
		     opened here and given as the quests' chest is. ]]
		local what = GiftRules.claim(profile.gift)
		local open = Rewards.openChest
		if what and open then
			PlayerData.touch(player)
			log.info("%s opens a gift: %s", player.Name, what)
			open(player, what)
			Wallet.send(player)
		end
		return
	elseif kind == "all" then
		--[[ Everything that waits, marked in one step; its eggs and crates
		     are opened together and shown by `Data/QuestChest`. ]]
		local total, n, quests, items = RewardRules.claimAll(profile, day, os.time())
		giftsSaid[player] = 0
		gift = if n > 0 then total else nil
		GoalRules.count(profile.stats, "quests", quests)
		local hook = Rewards.onNote
		if hook and quests > 0 then
			hook(player, "quests", quests)
		end
		local give = Rewards.givePrize
		if give and items.eggs + items.crates > 0 then
			give(player, items.eggs, items.crates)
		end
	elseif kind == "login" then
		gift = RewardRules.claimLogin(profile.rewards, day)
	elseif kind == "quest" and type(key) == "string" then
		gift = RewardRules.claimQuest(profile.rewards, day, key)
		if gift then
			GoalRules.count(profile.stats, "quests", 1)
			local hook = Rewards.onNote
			if hook then
				hook(player, "quests", 1)
			end
		end
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
	local told = Rewards.dailyClaimed
	if told and profile.rewards.loginDay ~= loginBefore then
		told(player)
	end
end

--[[ The profile is in: its playtime session goes on, or a new one
     starts (`PlaytimeRules.join`). ]]
local function takeClock(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if PlaytimeRules.join(profile.playtime, os.time()) then
		log.info("%s starts a playtime session", player.Name)
	end
	giftsSaid[player] = PlaytimeRules.ready(profile.playtime, os.time())
	PlayerData.touch(player)
	Wallet.send(player)
end

--[[ Every few seconds: each clock stamped (saved with the profile, so the
     next server goes on with the session), and a gift that has opened
     said on the toast. ]]
local function watchClocks()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if not profile then
			continue
		end
		PlaytimeRules.stamp(profile.playtime, now)
		local ready = PlaytimeRules.ready(profile.playtime, now)
		if ready > (giftsSaid[player] or 0) then
			toast:FireClient(player, "PLAYTIME GIFT READY! OPEN IT IN REWARDS", 0, 0)
		end
		giftsSaid[player] = ready
	end
end

function Rewards.start()
	Inbound.on(Remotes.RewardClaim, claim)
	PlayerData.onLoaded(publish)
	PlayerData.onLoaded(takeClock)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		offsets[player] = nil
		giftsSaid[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(PLAYTIME_EVERY)
			watchClocks()
		end
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
		Inbound.debug(Remotes.DebugDay, function(player, days)
			local n = if type(days) == "number" and days == days then math.floor(days) else 1
			offsets[player] = (offsets[player] or 0) + math.clamp(n, 1, 30)
			publish(player)
			Wallet.send(player)
			log.info("%s is now on day %d", player.Name, Rewards.today(player))
		end)
		--[[ The playtime session `n` minutes on (1 if not given): its start
		     moved back, as if they had played that long. ]]
		Inbound.debug(Remotes.DebugPlaytime, function(player, minutes)
			local profile = PlayerData.get(player)
			if not profile then
				return
			end
			local n = if type(minutes) == "number" and minutes == minutes
				then math.floor(minutes)
				else 1
			profile.playtime.start -= math.clamp(n, 1, 120) * 60
			watchClocks()
			Wallet.send(player)
			log.info(
				"%s has played %d s this session",
				player.Name,
				PlaytimeRules.played(profile.playtime, os.time())
			)
		end)
	end
end

return Rewards
