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

local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

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

--[[ `amount` of `kind` happened today: each of today's quests of that kind
     moves on, up to its goal. Returns whether anything changed. ]]
function RewardRules.note(
	r: SaveSchema.RewardState,
	day: number,
	kind: string,
	amount: number
): boolean
	if amount <= 0 or amount ~= amount then
		return false
	end
	local changed = RewardRules.roll(r, day)
	for _, key in RewardRules.questsFor(day) do
		local quest = Rewards.quests[key]
		local had = r.questProgress[key] or 0
		if quest.kind == kind and had < quest.goal then
			r.questProgress[key] = math.min(quest.goal, had + math.floor(amount))
			changed = true
		end
	end
	return changed
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

--[[ How many rewards wait to be claimed: the lobby button's badge. ]]
function RewardRules.ready(profile: SaveSchema.Profile, day: number): number
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
