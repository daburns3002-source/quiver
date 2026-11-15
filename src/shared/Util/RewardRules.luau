--!strict
--[[
	The rules of the login calendar, the daily quests, the starter list and
	the Dex payouts (`Config/Rewards`), pure, so the server (`Data/Rewards`)
	decides with them and the client's screen draws with the same answers.
	`tests/RewardRules.spec` pins them.

	Every claim is judged from the saved profile and the server's day: the
	client sends only which reward it would like, never progress or a day.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftRules = require(script.Parent.GiftRules)
local GoalRules = require(script.Parent.GoalRules)
local PageRules = require(script.Parent.PageRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StarRules = require(script.Parent.StarRules)

local RewardRules = {}

export type Gift = Rewards.Gift

--[[ The reward day `time` (seconds since 1970, UTC) falls in. ]]
function RewardRules.day(time: number): number
	return math.floor(time / Rewards.dayLength)
end

--[[ The quest keys of every group, sorted, so a day's deal does not hang
     on table order. ]]
local byGroup: { [string]: { string } } = {}
for key, quest in Rewards.quests do
	byGroup[quest.group] = byGroup[quest.group] or {}
	table.insert(byGroup[quest.group], key)
end
for _, keys in byGroup do
	table.sort(keys)
end

--[[ Today's three, one per group in `Rewards.groups` order; the same for
     everyone on a day, different from one day to the next more often than
     not. ]]
function RewardRules.questsFor(day: number): { string }
	local random = Random.new(day * 7919 + 17)
	local out = {}
	for _, group in Rewards.groups do
		local keys = byGroup[group]
		if keys and #keys > 0 then
			table.insert(out, keys[random:NextInteger(1, #keys)])
		end
	end
	return out
end

--[[ A new day wipes yesterday's quests. Returns whether it did. ]]
function RewardRules.roll(r: SaveSchema.RewardState, day: number): boolean
	if r.questDay == day then
		return false
	end
	r.questDay = day
	r.questProgress = {}
	r.questClaimed = {}
	return true
end

--[[ A quest that has just passed a point worth saying (`Rewards.steps`):
     half way, or done. ]]
export type Step = { key: string, have: number, goal: number, done: boolean }

--[[ `amount` of `kind` happened today: each of today's quests of that kind
     moves on, up to its goal. Returns whether anything changed, and the
     quests that passed a step with it, for the player to be told. ]]
function RewardRules.note(
	r: SaveSchema.RewardState,
	day: number,
	kind: string,
	amount: number
): (boolean, { Step })
	local steps: { Step } = {}
	if amount <= 0 or amount ~= amount then
		return false, steps
	end
	local changed = RewardRules.roll(r, day)
	for _, key in RewardRules.questsFor(day) do
		local quest = Rewards.quests[key]
		local had = r.questProgress[key] or 0
		if quest.kind == kind and had < quest.goal then
			local have = math.min(quest.goal, had + math.floor(amount))
			r.questProgress[key] = have
			changed = true
			for _, share in Rewards.steps do
				local at = math.ceil(quest.goal * share)
				local said = share >= 1 or quest.goal >= Rewards.stepGoal
				if said and had < at and have >= at then
					table.insert(steps, {
						key = key,
						have = have,
						goal = quest.goal,
						done = have >= quest.goal,
					})
					break
				end
			end
		end
	end
	return changed, steps
end

--[[ How far today's quest `key` has come (0 if it is not today's). ]]
function RewardRules.progress(r: SaveSchema.RewardState, day: number, key: string): number
	if r.questDay ~= day then
		return 0
	end
	return r.questProgress[key] or 0
end

function RewardRules.questClaimed(r: SaveSchema.RewardState, day: number, key: string): boolean
	return r.questDay == day and r.questClaimed[key] == true
end

function RewardRules.questReady(r: SaveSchema.RewardState, day: number, key: string): boolean
	local quest = Rewards.quests[key]
	return quest ~= nil
		and table.find(RewardRules.questsFor(day), key) ~= nil
		and RewardRules.progress(r, day, key) >= quest.goal
		and not RewardRules.questClaimed(r, day, key)
end

function RewardRules.claimQuest(r: SaveSchema.RewardState, day: number, key: string): Gift?
	if not RewardRules.questReady(r, day, key) then
		return nil
	end
	r.questClaimed[key] = true
	local quest = Rewards.quests[key]
	return { gems = quest.gems, coins = quest.coins }
end

--[[ How many of today's quests have been claimed. ]]
function RewardRules.questsClaimed(r: SaveSchema.RewardState, day: number): number
	local n = 0
	for _, key in RewardRules.questsFor(day) do
		if RewardRules.questClaimed(r, day, key) then
			n += 1
		end
	end
	return n
end

--[[ What the day's bonus chest holds (`Rewards.bonus`): an egg one day, a
     weapon crate the next, the same for everyone. ]]
function RewardRules.bonusKind(day: number): "Egg" | "Crate"
	return if day % 2 == 0 then "Egg" else "Crate"
end

function RewardRules.bonusClaimed(r: SaveSchema.RewardState, day: number): boolean
	return r.bonusDay == day
end

--[[ Whether the bonus chest is owed: every one of today's quests claimed,
     and the chest not opened today. ]]
function RewardRules.bonusReady(r: SaveSchema.RewardState, day: number): boolean
	local quests = RewardRules.questsFor(day)
	return #quests > 0
		and RewardRules.questsClaimed(r, day) >= #quests
		and not RewardRules.bonusClaimed(r, day)
end

--[[ Opens the bonus chest: marked, and what it holds returned for the
     server to give (`Data/QuestChest`). Nil when it is not owed. ]]
function RewardRules.claimBonus(r: SaveSchema.RewardState, day: number): ("Egg" | "Crate")?
	if not RewardRules.bonusReady(r, day) then
		return nil
	end
	r.bonusDay = day
	return RewardRules.bonusKind(day)
end

--[[ The calendar's next square (1..7): the one a claim today pays, or the
     one tomorrow's will once today's is taken. ]]
function RewardRules.loginSlot(r: SaveSchema.RewardState): number
	return r.loginCount % #Rewards.calendar + 1
end

function RewardRules.loginReady(r: SaveSchema.RewardState, day: number): boolean
	return r.loginDay < day
end

function RewardRules.claimLogin(r: SaveSchema.RewardState, day: number): Gift?
	if not RewardRules.loginReady(r, day) then
		return nil
	end
	local gift = Rewards.calendar[RewardRules.loginSlot(r)]
	r.loginDay = day
	r.loginCount += 1
	return { gems = gift.gems, coins = gift.coins }
end

local function starterEntry(key: string): Rewards.Starter?
	for _, entry in Rewards.starter do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

--[[ Whether the profile shows the starter step done. Read from what the
     game already saves, so nothing has to be reported. ]]
function RewardRules.starterDone(profile: SaveSchema.Profile, key: string): boolean
	if key == "beat11" then
		return profile.levelsBeaten["1-1"] == true
	elseif key == "hatch" then
		return next(profile.pets) ~= nil
	elseif key == "equipPet" then
		return next(profile.equippedPets) ~= nil
	elseif key == "crate" then
		return profile.rewards.cratesOpened > 0
	end
	return false
end

function RewardRules.starterReady(profile: SaveSchema.Profile, key: string): boolean
	return starterEntry(key) ~= nil
		and not profile.rewards.starterClaimed[key]
		and RewardRules.starterDone(profile, key)
end

function RewardRules.claimStarter(profile: SaveSchema.Profile, key: string): Gift?
	local entry = starterEntry(key)
	if not entry or not RewardRules.starterReady(profile, key) then
		return nil
	end
	profile.rewards.starterClaimed[key] = true
	return { gems = entry.gems, coins = entry.coins }
end

--[[ How a Dex entry is written in `dexPaid`. ]]
function RewardRules.dexKey(book: string, key: string): string
	return book .. ":" .. key
end

--[[ Marks a Dex entry paid; true the first time ever, when it pays. ]]
function RewardRules.payDex(r: SaveSchema.RewardState, book: string, key: string): boolean
	local id = RewardRules.dexKey(book, key)
	if r.dexPaid[id] then
		return false
	end
	r.dexPaid[id] = true
	return true
end

--[[ How many rewards wait to be claimed on each of the screen's tabs. ]]
function RewardRules.readyBy(
	profile: SaveSchema.Profile,
	day: number
): { daily: number, quests: number, goals: number }
	local r = profile.rewards
	local out = { daily = if RewardRules.loginReady(r, day) then 1 else 0, quests = 0, goals = 0 }
	for _, key in RewardRules.questsFor(day) do
		if RewardRules.questReady(r, day, key) then
			out.quests += 1
		end
	end
	if RewardRules.bonusReady(r, day) then
		out.quests += 1
	end
	for _, entry in Rewards.starter do
		if RewardRules.starterReady(profile, entry.key) then
			out.goals += 1
		end
	end
	out.goals += (GoalRules.tally(profile))
	-- the gift box is on the DAILY tab, the Dex pages' chests with the goals
	out.daily += GiftRules.ready(profile.gift)
	out.goals += PageRules.tally(profile)
	out.goals += StarRules.tally(profile)
	return out
end

--[[ How many rewards CLAIM ALL would take (`claimAll`): the calendar, the
     quests and the starter steps. What opens with a reveal of its own (the
     quests' chest, a gift, a goal's step, a Dex page's chest) is not among
     them. ]]
function RewardRules.owedAll(profile: SaveSchema.Profile, day: number): number
	local r = profile.rewards
	local n = if RewardRules.loginReady(r, day) then 1 else 0
	for _, key in RewardRules.questsFor(day) do
		if RewardRules.questReady(r, day, key) then
			n += 1
		end
	end
	for _, entry in Rewards.starter do
		if RewardRules.starterReady(profile, entry.key) then
			n += 1
		end
	end
	return n
end

--[[ How many rewards wait to be claimed: the lobby button's badge. ]]
function RewardRules.ready(profile: SaveSchema.Profile, day: number): number
	local by = RewardRules.readyBy(profile, day)
	return by.daily + by.quests + by.goals
end

--[[ CLAIM ALL: every reward owed that pays coins or gems (the calendar,
     the quests, the starter steps), marked and summed; how many it was,
     and how many of those were quests. The bonus chest and the goals are
     claimed by themselves, for their reveals. ]]
function RewardRules.claimAll(profile: SaveSchema.Profile, day: number): (Gift, number, number)
	local r = profile.rewards
	local total: Gift = { gems = 0, coins = 0 }
	local n = 0
	local quests = 0
	local function take(gift: Gift?)
		if gift then
			total.gems += gift.gems
			total.coins += gift.coins
			n += 1
		end
	end
	take(RewardRules.claimLogin(r, day))
	for _, key in RewardRules.questsFor(day) do
		local gift = RewardRules.claimQuest(r, day, key)
		if gift then
			quests += 1
		end
		take(gift)
	end
	for _, entry in Rewards.starter do
		take(RewardRules.claimStarter(profile, entry.key))
	end
	return total, n, quests
end

--[[ Whether every starter step has been claimed (the list then hides). ]]
function RewardRules.starterFinished(profile: SaveSchema.Profile): boolean
	for _, entry in Rewards.starter do
		if not profile.rewards.starterClaimed[entry.key] then
			return false
		end
	end
	return true
end

return RewardRules
