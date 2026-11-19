--!strict
--[[
	The weekly set rotation (`Config/LiveEvents`, `docs/LIVE-EVENTS.md`),
	pure, so the server refuses what the SETS tab does not show and
	`tests/SetRotation.spec` pins it. Two of the stocked themed sets
	(`Config/Shop.sets`, in its order) are on sale a week, from Monday 00:00
	UTC, chosen by the week's number and wrapping round; the others are off
	the shelf until their week comes back. Owned weapons are never touched:
	this decides only what can be bought.

	`now` is always the server's clock in Unix seconds (`Util/LiveState.now`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local SetRotation = {}

SetRotation.WEEK = 7 * 86400

--[[ The week `now` is in, counted from `LiveEvents.firstMonday` (0 is the
     rotation's first; before it, negative). ]]
function SetRotation.week(now: number): number
	return math.floor((now - LiveEvents.firstMonday) / SetRotation.WEEK)
end

--[[ When week `week` begins, Monday 00:00 UTC. ]]
function SetRotation.weekStart(week: number): number
	return LiveEvents.firstMonday + week * SetRotation.WEEK
end

--[[ Seconds from `now` to the next Monday 00:00, when the sets change. ]]
function SetRotation.left(now: number): number
	return SetRotation.weekStart(SetRotation.week(now) + 1) - now
end

--[[ The stocked sets' keys, in the shelf's order. ]]
local function stocked(): { string }
	local out = {}
	for _, set in Shop.sets do
		if set.stocked then
			table.insert(out, set.key)
		end
	end
	return out
end

--[[ The sets on sale in the week `now` is in, from `keys` (the stocked
     sets by default) in order: `LiveEvents.setsPerWeek` of them, wrapping
     round; all of them when there are no more than that. ]]
function SetRotation.featured(now: number, keys: { string }?): { string }
	local all = keys or stocked()
	local per = LiveEvents.setsPerWeek
	if #all <= per then
		return table.clone(all)
	end
	local first = SetRotation.week(now) * per
	local out = {}
	for i = 0, per - 1 do
		table.insert(out, all[(first + i) % #all + 1])
	end
	return out
end

--[[ Whether set `key` can be bought at `now`. ]]
function SetRotation.onSale(key: string, now: number, keys: { string }?): boolean
	return table.find(SetRotation.featured(now, keys), key) ~= nil
end

return SetRotation
