--!strict
--[[
	The Goals' rules (`Config/Goals`), pure, so the server decides with them
	(`Data/Rewards`) and the screen draws with the same answers
	(`UI/RewardsScreen`); `tests/Goals.spec` pins them.

	A goal is judged from the saved profile only: a lifetime counter the
	server keeps (`SaveSchema.stats`) or something the save already holds.
	The client sends which goal it would like to claim and nothing else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Goals = require(ReplicatedStorage.Shared.Config.Goals)
local MergeRules = require(script.Parent.MergeRules)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local SaveSchema = require(script.Parent.SaveSchema)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local GoalRules = {}

export type Prize = Goals.Prize
export type Goal = Goals.Goal

local byKey: { [string]: Goal } = {}
for _, goal in Goals.goals do
	byKey[goal.key] = goal
end
local counted: { [string]: boolean } = {}
for _, stat in Goals.counted do
	counted[stat] = true
end

function GoalRules.find(key: unknown): Goal?
	return if type(key) == "string" then byKey[key] else nil
end

--[[ Whether `stat` is a lifetime counter the server keeps. ]]
function GoalRules.counts(stat: unknown): boolean
	return type(stat) == "string" and counted[stat] == true
end

--[[ `amount` more of a counted `stat` happened. Returns whether it was
     counted: not for another stat, nothing, or a broken number. ]]
function GoalRules.count(stats: { [string]: number }, stat: string, amount: number): boolean
	if not GoalRules.counts(stat) or amount ~= amount or amount <= 0 then
		return false
	end
	stats[stat] = (stats[stat] or 0) + math.floor(amount)
	return true
end

local function size(list: { [any]: any }): number
	local n = 0
	for _ in list do
		n += 1
	end
	return n
end

local GRAND = { Legendary = true, Mythic = true }
local TOP = MergeRules.TIERS[#MergeRules.TIERS]

--[[ How far `profile` has come on `stat`. ]]
function GoalRules.value(profile: SaveSchema.Profile, stat: string): number
	if counted[stat] then
		return profile.stats[stat] or 0
	elseif stat == "areas" then
		return size(profile.bossesBeaten)
	elseif stat == "endless" then
		return profile.endlessBest
	elseif stat == "classLevel" then
		local best = 1
		for _, standing in profile.classLevels do
			best = math.max(best, standing.level)
		end
		return best
	elseif stat == "pets" then
		local n = 0
		for _, held in profile.pets do
			if held > 0 then
				n += 1
			end
		end
		return n
	elseif stat == "weapons" then
		return size(profile.weapons)
	elseif stat == "topTier" then
		local n = 0
		for _, book in { profile.tiers.weapons, profile.tiers.pets } do
			for _, held in book do
				if (held[TOP] or 0) > 0 then
					n += 1
				end
			end
		end
		return n
	elseif stat == "rare" then
		local n = 0
		for name in profile.weapons do
			local stats = WeaponStats.weapons[name]
			if stats and GRAND[stats.rarity] then
				n += 1
			end
		end
		for key, held in profile.pets do
			local pet = (Pets :: any)[key]
			if held > 0 and pet and GRAND[pet.rarity] then
				n += 1
			end
		end
		return n
	elseif stat == "dex" then
		return size(profile.rewards.dexPaid)
	elseif stat == "logins" then
		return profile.rewards.loginCount
	end
	return 0
end

--[[ How many of a goal's steps have been claimed (0 to all of them). ]]
function GoalRules.claimed(profile: SaveSchema.Profile, goal: Goal): number
	return math.clamp(profile.goalsClaimed[goal.key] or 0, 0, #goal.steps)
end

--[[ The step being worked on: which it is (1 bronze, 2 silver, 3 gold),
     what it asks and what it pays; nil once the goal is finished. ]]
function GoalRules.step(profile: SaveSchema.Profile, goal: Goal): (number?, number?, Prize?)
	local index = GoalRules.claimed(profile, goal) + 1
	local step = goal.steps[index]
	if not step then
		return nil, nil, nil
	end
	return index, step.goal, step.prize
end

function GoalRules.finished(profile: SaveSchema.Profile, goal: Goal): boolean
	return GoalRules.claimed(profile, goal) >= #goal.steps
end

--[[ Whether the goal's next step is reached and waits to be claimed. ]]
function GoalRules.ready(profile: SaveSchema.Profile, goal: Goal): boolean
	local _, wanted = GoalRules.step(profile, goal)
	return wanted ~= nil and GoalRules.value(profile, goal.stat) >= wanted
end

--[[ Claims goal `key`'s next step: marked, and its prize returned for the
     server to give. Nil when it is no goal, finished, or not reached. One
     step a claim, in order. ]]
function GoalRules.claim(profile: SaveSchema.Profile, key: unknown): Prize?
	local goal = GoalRules.find(key)
	if not goal or not GoalRules.ready(profile, goal) then
		return nil
	end
	local _, _, prize = GoalRules.step(profile, goal)
	profile.goalsClaimed[goal.key] = GoalRules.claimed(profile, goal) + 1
	return prize
end

--[[ How many goals have a step waiting, and how many are finished. ]]
function GoalRules.tally(profile: SaveSchema.Profile): (number, number)
	local waiting, done = 0, 0
	for _, goal in Goals.goals do
		if GoalRules.finished(profile, goal) then
			done += 1
		elseif GoalRules.ready(profile, goal) then
			waiting += 1
		end
	end
	return waiting, done
end

return GoalRules
