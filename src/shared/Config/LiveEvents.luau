--!strict
--[[
	The live events (owner, 2026-11-18: "yes all of these create them";
	`docs/LIVE-EVENTS.md`): the weekly set rotation, the weekend boosts, the
	owner's live event switch and the Server Luck product's boost. Starting
	numbers. The rules are `Util/SetRotation` and `Util/LiveBoosts`, pure
	and pinned by `tests/SetRotation.spec` and `tests/LiveBoosts.spec`; the
	server keeps the boosts that are not on the clock (`Server/Data/LiveEvents`).

	Everything runs on UTC, from the server's clock: a week starts Monday
	00:00 and its weekend is Friday 00:00 to Monday 00:00.
]]

local DAY = 86400

return table.freeze({
	--[[ The themed sets on sale each week, from `Config/Shop.sets` in its
	     order (the stocked ones), wrapping round. The others are off the
	     shelf until their week comes back (owner, 2026-11-18: "They leave");
	     a weapon already owned is always kept. ]]
	setsPerWeek = 2,
	--[[ The Monday 00:00 UTC weeks are counted from: 2026-11-16, the week
	     the rotation began, which shows the first two sets and the first
	     weekend kind. ]]
	firstMonday = 1794787200,
	--[[ Seconds after a week's Monday 00:00 that its weekend begins
	     (Friday 00:00); it ends as the next week begins. ]]
	weekendFrom = 4 * DAY,
	--[[ The weekend's boost, alternating by week: the first week's is the
	     first. ]]
	weekendKinds = table.freeze({ "Luck", "Coins" }),
	--[[ What one boost adds: a 2x is 1 more. ]]
	bonus = 1,
	--[[ How boosts combine (`LiveBoosts.coinShare`, `LiveBoosts.luck`):
	     they add, never multiply, and stop here. `coins` is the most the
	     events add to a run's coin scale (on top of the passes, the streak
	     and the friend bonus, which add too), so two coin events at once
	     are still 2x; `luck` is the highest luck multiplier, so the weekend,
	     the owner's event and a Server Luck all at once are 3x, not 8x.
	     VIP brings no luck. ]]
	caps = table.freeze({ coins = 1, luck = 3 }),
	--[[ The rarities luck raises; the others give up what they gain, in
	     proportion, so an egg's odds still add up to the whole. ]]
	luckRarities = table.freeze({ "Legendary", "Mythic" }),
	--[[ The largest share of an egg the lucky rarities may reach, however
	     lucky: a guard, far over 3x of today's odds (13.5%). ]]
	luckShareCap = 0.5,
	--[[ The owner's live event (`Remotes.LiveEventStart`): its length, and
	     the kinds it can be. Firing one replaces the one running. ]]
	liveSeconds = 30 * 60,
	liveKinds = table.freeze({ "Luck", "Coins" }),
	--[[ Roblox user ids allowed to fire a live event, beside the place's
	     creator when a user owns it (`game.CreatorId`). ]]
	ownerIds = table.freeze({} :: { number }),
	--[[ The MessagingService topic a live event goes out on, and the
	     MemoryStore map a server starting during one reads it from. ]]
	topic = "LiveEvent",
	memoryMap = "LiveEvent",
	--[[ The workspace attributes the server publishes the boosts on, for
	     every screen (`Util/LiveState`). ]]
	attributes = table.freeze({
		liveKind = "LiveEventKind",
		liveEnds = "LiveEventEnds",
		luckEnds = "ServerLuckEnds",
		luckBy = "ServerLuckBy",
		--[[ Studio only: seconds the clock is moved, for testing a weekend
		     or a new week (`Remotes.DebugClock`). ]]
		shift = "LiveClockShift",
	}),
	--[[ The Player attribute the server sets for an owner, to show the
	     live event switch. ]]
	ownerAttribute = "LiveEventOwner",
})
