--!strict
--[[
	The boosts (`Config/LiveEvents`, `docs/LIVE-EVENTS.md`), pure, so the
	server pays and rolls with them, the screens say the same, and
	`tests/LiveBoosts.spec` pins them.

	**Where they come from.** The weekend's, on the clock (Friday 00:00 to
	Monday 00:00 UTC, 2x Luck and 2x Coins weekend about); the owner's live
	event, 30 minutes of either; a Server Luck bought for Robux, 15 minutes
	of 2x Luck for the whole server, more time for each one bought.

	**How they combine.** Boosts add, never multiply, and stop at
	`LiveEvents.caps`: events add at most one more coin scale (2x) to a
	run's kill and clear coins, beside the passes, the streak and the friend
	bonus (`RunBonus.scale`), and luck stops at 3x however many are on. VIP
	brings coins and gems, never luck.

	**What luck does.** It multiplies the Legendary and Mythic odds; every
	other rarity gives up what they gain, in proportion, so an egg's odds
	still add up to the whole (`odds`). The Mythic pity (`Util/Pity`) is
	untouched.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local SetRotation = require(script.Parent.SetRotation)

local LiveBoosts = {}

export type Boost = {
	kind: string,
	--[[ "Weekend", "Live" or "Server". ]]
	source: string,
	endsAt: number,
	--[[ The Server Luck's buyer, thanked on the banner. ]]
	by: string?,
}

--[[ The weekend's boost if `now` is in a weekend, else nil. ]]
function LiveBoosts.weekend(now: number): Boost?
	local week = SetRotation.week(now)
	local start = SetRotation.weekStart(week)
	if now < start + LiveEvents.weekendFrom then
		return nil
	end
	local kinds = LiveEvents.weekendKinds
	return {
		kind = kinds[week % #kinds + 1],
		source = "Weekend",
		endsAt = SetRotation.weekStart(week + 1),
	}
end

--[[ The weekend now or next: its kind and when it begins (in the past
     while it is on). ]]
function LiveBoosts.nextWeekend(now: number): (string, number)
	local week = SetRotation.week(now)
	local kinds = LiveEvents.weekendKinds
	return kinds[week % #kinds + 1], SetRotation.weekStart(week) + LiveEvents.weekendFrom
end

--[[ The boosts of `boosts` still running at `now`. ]]
function LiveBoosts.active(boosts: { Boost }, now: number): { Boost }
	local out = {}
	for _, boost in boosts do
		if boost.endsAt > now then
			table.insert(out, boost)
		end
	end
	return out
end

local function count(boosts: { Boost }, kind: string, now: number): number
	local n = 0
	for _, boost in LiveBoosts.active(boosts, now) do
		if boost.kind == kind then
			n += 1
		end
	end
	return n
end

--[[ What the boosts running add to a run's coin scale: 0 with none, at
     most `caps.coins`. ]]
function LiveBoosts.coinShare(boosts: { Boost }, now: number): number
	return math.min(LiveEvents.caps.coins, count(boosts, "Coins", now) * LiveEvents.bonus)
end

--[[ The egg luck the boosts running make: 1 with none, at most
     `caps.luck`. ]]
function LiveBoosts.luck(boosts: { Boost }, now: number): number
	return math.min(LiveEvents.caps.luck, 1 + count(boosts, "Luck", now) * LiveEvents.bonus)
end

--[[ An egg's odds by rarity (`Config/Eggs.odds`, or the rarities one egg
     holds) under `luck`: the lucky rarities' weights times `luck`, the
     others' shrunk by one factor to pay for it, the total kept. Unchanged
     at luck 1, with no lucky rarity, or with nothing else to take from;
     the lucky share never passes `luckShareCap`. ]]
function LiveBoosts.odds(odds: { [string]: number }, luck: number): { [string]: number }
	local out = table.clone(odds)
	local total, lucky = 0, 0
	for rarity, weight in odds do
		total += weight
		if table.find(LiveEvents.luckRarities, rarity) then
			lucky += weight
		end
	end
	if not (luck > 1) or lucky <= 0 or lucky >= total then
		return out
	end
	local scale = math.min(luck, LiveEvents.luckShareCap * total / lucky)
	if scale <= 1 then
		return out
	end
	local rest = (total - lucky * scale) / (total - lucky)
	for rarity, weight in odds do
		out[rarity] = if table.find(LiveEvents.luckRarities, rarity)
			then weight * scale
			else weight * rest
	end
	return out
end

--[[ When a boost of `seconds` ends if bought at `now` while one ends at
     `endsAt`: added to the time left, so buying again adds time. ]]
function LiveBoosts.extend(endsAt: number?, now: number, seconds: number): number
	return math.max(endsAt or 0, now) + math.max(0, seconds)
end

--[[ A multiplier as the screen says it: "2x", "3x", "1.5x". ]]
function LiveBoosts.times(n: number): string
	if math.abs(n - math.floor(n + 0.5)) < 1e-6 then
		return string.format("%dx", math.floor(n + 0.5))
	end
	return string.format("%.1fx", n)
end

--[[ Time left as a countdown says it: "3D 4H" over a day, "4H 12M" over an
     hour, "14:59" under one; "0:00" when it is over. ]]
function LiveBoosts.clock(seconds: number): string
	local s = if seconds ~= seconds then 0 else math.max(0, math.floor(seconds))
	if s >= 86400 then
		return string.format("%dD %dH", s // 86400, (s % 86400) // 3600)
	elseif s >= 3600 then
		return string.format("%dH %dM", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

--[[ A boost's banner words, without its countdown: "2x LUCK WEEKEND",
     "LIVE EVENT! 2x COINS", "THANKS NAME! 2x LUCK". ]]
function LiveBoosts.words(boost: Boost): string
	local what = LiveBoosts.times(1 + LiveEvents.bonus) .. " " .. string.upper(boost.kind)
	if boost.source == "Weekend" then
		return what .. " WEEKEND"
	elseif boost.source == "Server" then
		-- a display name is at most 20 letters; cut on a whole letter all the same
		local by = boost.by or ""
		local cut = if (utf8.len(by) or 0) > 20 then utf8.offset(by, 21) else nil
		local name = string.upper(if cut then string.sub(by, 1, cut - 1) else by)
		return if name ~= "" then "THANKS " .. name .. "! " .. what else what
	end
	return "LIVE EVENT! " .. what
end

return LiveBoosts
