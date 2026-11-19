--!strict
--[[
	The notifications' rules (`Util/NotifyRules`, `Config/Notifications`):
	when a player is asked, and what is sent while they are away. Asserted
	as relationships to the config's numbers, so retuning one never fails
	here.
]]

local TestRunner = require(script.Parent.TestRunner)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notifications = require(ReplicatedStorage.Shared.Config.Notifications)
local NotifyRules = require(ReplicatedStorage.Shared.Util.NotifyRules)

local HOUR = 3600
local DAY = 86400
-- a Monday 00:00 UTC, far from any edge
local T0 = 1794787200

local function hourAt(at: number, zone: number): number
	return ((at + zone * 60) % DAY) / HOUR
end

local function inEvening(at: number, zone: number): boolean
	local h = hourAt(at, zone)
	return h >= Notifications.fromHour and h < Notifications.toHour
end

local function state(joins: number): NotifyRules.State
	local s = NotifyRules.default()
	s.joins = joins
	return s
end

local function leaving(over: { [string]: any }): NotifyRules.Leaving
	local base: { [string]: any } = {
		user = 42,
		now = T0 + 10 * HOUR,
		zone = 0,
		dailyAt = nil,
		giftFull = false,
		upcoming = {},
	}
	for k, v in over do
		base[k] = v
	end
	return base :: any
end

return function(t: TestRunner.Helper)
	t.test("never asked in the first session; asked after a claim in a later one", function()
		t.isFalse(NotifyRules.shouldAsk(state(Notifications.joins - 1), 100))
		t.isTrue(NotifyRules.shouldAsk(state(Notifications.joins), 100))
	end)

	t.test("NOT NOW waits its days, and only so many are allowed", function()
		local s = state(Notifications.joins)
		local day = 100
		for _ = 1, Notifications.maxAsks do
			t.isTrue(NotifyRules.shouldAsk(s, day))
			t.isTrue(NotifyRules.answer(s, "no", day, 0))
			t.isFalse(NotifyRules.shouldAsk(s, day), "not again the same day")
			t.isFalse(NotifyRules.shouldAsk(s, day + Notifications.retryDays - 1))
			day += Notifications.retryDays
		end
		t.isFalse(NotifyRules.shouldAsk(s, day + 365), "after the last NOT NOW, never")
	end)

	t.test("YES is never asked again, and is what lets anything be sent", function()
		local s = state(Notifications.joins)
		t.isFalse(NotifyRules.optedIn(s))
		NotifyRules.answer(s, "yes", 100, -300)
		t.isTrue(NotifyRules.optedIn(s))
		t.equal(s.zone, -300, "the device's offset comes with the answer")
		t.isFalse(NotifyRules.shouldAsk(s, 100 + 1000))
	end)

	t.test("when Roblox cannot ask, the game waits before trying", function()
		local s = state(Notifications.joins)
		NotifyRules.answer(s, "cannot", 100, 0)
		t.isFalse(NotifyRules.optedIn(s), "cannot is not a yes")
		t.isFalse(NotifyRules.shouldAsk(s, 100 + Notifications.cannotDays - 1))
		t.isTrue(NotifyRules.shouldAsk(s, 100 + Notifications.cannotDays))
		t.equal(s.noes, 0, "and it is not counted as a NOT NOW")
	end)

	t.test("an answer that is not one changes nothing", function()
		local s = state(Notifications.joins)
		t.isFalse(NotifyRules.answer(s, "sure", 100, 0))
		t.isFalse(NotifyRules.answer(s, 1, 100, 0))
		t.equal(s.answer, "")
		t.equal(s.asked, 0)
	end)

	t.test("an offset is clamped to one a zone can have", function()
		t.equal(NotifyRules.zone(10000), 14 * 60)
		t.equal(NotifyRules.zone(-10000), -14 * 60)
		t.equal(NotifyRules.zone(0 / 0), 0)
		t.equal(NotifyRules.zone("x"), 0)
	end)

	t.test("every message lands in the player's own evening", function()
		for _, zone in { -480, -300, 0, 60, 330, 540 } do
			for h = 0, 23 do
				local at = T0 + h * HOUR + 17
				local slot = NotifyRules.evening(at, zone)
				t.isTrue(slot >= at, "never earlier")
				t.isTrue(slot - at < DAY, "within a day")
				t.isTrue(inEvening(slot, zone), `zone {zone} hour {h}`)
				if inEvening(at, zone) then
					t.equal(slot, at, "already evening: unchanged")
				end
			end
		end
	end)

	t.test(
		"a daily reward is pinged after the quiet hours, in the evening, and again later",
		function()
			local l = leaving({ dailyAt = T0 + DAY })
			local plan = NotifyRules.plan(l) :: NotifyRules.Entry
			t.notNil(plan)
			t.equal(#plan.items, 2)
			local first, second = plan.items[1], plan.items[2]
			t.equal(first.kind, "daily")
			t.isTrue(first.at >= T0 + DAY, "not before it is ready")
			t.isTrue(inEvening(first.at, 0))
			t.isTrue(second.at - first.at >= Notifications.gap)
		end
	)

	t.test("nothing in the quiet hours after leaving", function()
		local l = leaving({ now = T0 + Notifications.fromHour * HOUR, giftFull = true })
		local plan = NotifyRules.plan(l) :: NotifyRules.Entry
		t.isTrue(plan.items[1].at >= l.now + Notifications.quiet)
	end)

	t.test("a plan keeps its gaps, its cap and its last day", function()
		local now = T0 + 10 * HOUR
		local l = leaving({
			now = now,
			dailyAt = now,
			giftFull = true,
			upcoming = {
				event = { at = now + HOUR, untilAt = now + 3 * DAY },
				season = { at = now + 2 * HOUR },
				rotation = { at = now + 5 * DAY },
			},
		})
		local plan = NotifyRules.plan(l) :: NotifyRules.Entry
		t.equal(#plan.items, Notifications.perAbsence, "never more than the cap")
		for i, item in plan.items do
			t.isTrue(inEvening(item.at, 0))
			t.isTrue(item.at <= now + Notifications.giveUp)
			if i > 1 then
				t.isTrue(item.at - plan.items[i - 1].at >= Notifications.gap, "a gap between")
			end
		end
		t.equal(plan.items[1].kind, "event", "the lowest rank takes a shared slot")
	end)

	t.test("what is already on, or over before its slot, is not sent", function()
		local now = T0 + 10 * HOUR
		t.isNil(
			NotifyRules.plan(leaving({
				now = now,
				upcoming = { event = { at = now - HOUR, untilAt = now + DAY } },
			})),
			"on already: the player has just seen it"
		)
		t.isNil(
			NotifyRules.plan(leaving({
				now = now,
				upcoming = { event = { at = now + 60, untilAt = now + 120 } },
			})),
			"over before an evening comes"
		)
		t.isNil(
			NotifyRules.plan(leaving({
				now = now,
				upcoming = { season = { at = now + Notifications.giveUp + DAY } },
			})),
			"past the last day"
		)
		t.isNil(
			NotifyRules.plan(leaving({ now = now, upcoming = { nonsense = { at = now + DAY } } }))
		)
	end)

	t.test("step moves on after a send and keeps the gap from it", function()
		local now = T0 + 10 * HOUR
		local plan = NotifyRules.plan(leaving({
			now = now,
			dailyAt = now,
			upcoming = { season = { at = now + DAY } },
		})) :: NotifyRules.Entry
		local count = #plan.items
		local sentAt = plan.items[1].at
		local after = NotifyRules.step(plan, "sent", sentAt) :: NotifyRules.Entry
		t.equal(after.sent, 1)
		t.equal(#after.items, count - 1)
		t.isTrue(after.items[1].at - sentAt >= Notifications.gap)
		t.equal(#plan.items, count, "the plan passed in is left as it was")
	end)

	t.test("a retry backs off, then gives up; a drop moves on", function()
		local now = T0 + 10 * HOUR
		local plan = NotifyRules.plan(leaving({ now = now, giftFull = true })) :: NotifyRules.Entry
		local at = plan.items[1].at
		local tries = 0
		local entry: NotifyRules.Entry? = plan
		local lastAt = at
		while entry and tries <= Notifications.retries do
			entry = NotifyRules.step(entry, "retry", lastAt)
			tries += 1
			if entry then
				t.isTrue(entry.items[1].at > lastAt, "always later")
				lastAt = entry.items[1].at
			end
		end
		t.isNil(entry, "given up after its retries")
		t.isNil(NotifyRules.step(plan, "drop", at), "a drop of the only one leaves nothing")
	end)

	t.test("the daily reward is ready at once if unclaimed, else at the next UTC day", function()
		local today = math.floor(T0 / DAY)
		t.equal(NotifyRules.dailyAt(today - 1, today, T0 + 5), T0 + 5)
		t.equal(NotifyRules.dailyAt(today, today, T0 + 5), (today + 1) * DAY)
	end)
end
