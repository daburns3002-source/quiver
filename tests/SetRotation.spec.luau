--!strict
--[[
	The weekly set rotation (`Util/SetRotation`, `Config/LiveEvents`; owner,
	2026-11-18: the other sets "leave" until their week comes back): two
	stocked sets a week, from Monday 00:00 UTC, every set in its turn, and
	the store sells nothing else of a set.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local SetRotation = require(ReplicatedStorage.Shared.Util.SetRotation)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)

local DAY = 86400

local function stocked(): { string }
	local out = {}
	for _, set in Shop.sets do
		if set.stocked then
			table.insert(out, set.key)
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("weeks begin on a Monday at midnight UTC", function()
		-- 1970-01-01 was a Thursday, so a Monday is 4 days past a whole week
		t.equal((LiveEvents.firstMonday - 4 * DAY) % (7 * DAY), 0, "firstMonday is a Monday 00:00")
		local start = SetRotation.weekStart(5)
		t.equal(SetRotation.week(start), 5)
		t.equal(SetRotation.week(start - 1), 4, "Sunday 23:59:59 is the week before")
		t.equal(SetRotation.week(start + 7 * DAY - 1), 5)
		t.equal(SetRotation.left(start), 7 * DAY)
		t.equal(SetRotation.left(start + 7 * DAY - 1), 1)
		t.equal(SetRotation.week(LiveEvents.firstMonday - 1), -1, "before the first week too")
	end)

	t.test("each week has its own sets, from the shelf's order", function()
		local keys = stocked()
		local per = LiveEvents.setsPerWeek
		t.isTrue(#keys > per, "more sets than a week shows, or nothing rotates")
		for week = -3, 12 do
			local on = SetRotation.featured(SetRotation.weekStart(week) + DAY, keys)
			t.equal(#on, per, "a week shows its count")
			for i = 2, #on do
				t.isTrue(on[i] ~= on[1], "never one set twice")
			end
			for _, key in on do
				t.notNil(table.find(keys, key), "only stocked sets")
			end
		end
		-- the first week opens on the first sets
		local first = SetRotation.featured(LiveEvents.firstMonday, keys)
		t.equal(first[1], keys[1])
		t.equal(first[2], keys[2])
	end)

	t.test("every set comes back, and in the same turn", function()
		local keys = stocked()
		local cycle = math.ceil(#keys / LiveEvents.setsPerWeek)
		local seen: { [string]: number } = {}
		for week = 0, cycle - 1 do
			for _, key in SetRotation.featured(SetRotation.weekStart(week), keys) do
				seen[key] = (seen[key] or 0) + 1
			end
		end
		for _, key in keys do
			t.isTrue((seen[key] or 0) >= 1, key .. " is on sale within a cycle")
		end
		if #keys % LiveEvents.setsPerWeek == 0 then
			local a = SetRotation.featured(SetRotation.weekStart(3), keys)
			local b = SetRotation.featured(SetRotation.weekStart(3 + cycle), keys)
			t.equal(table.concat(a, ","), table.concat(b, ","), "a cycle later, the same sets")
		end
	end)

	t.test("the week turns over exactly at Monday 00:00", function()
		local keys = stocked()
		local monday = SetRotation.weekStart(2)
		local before = SetRotation.featured(monday - 1, keys)
		local after = SetRotation.featured(monday, keys)
		t.isTrue(table.concat(before, ",") ~= table.concat(after, ","), "new sets on Monday")
		t.equal(
			table.concat(after, ","),
			table.concat(SetRotation.featured(monday + 6 * DAY, keys), ",")
		)
	end)

	t.test("too few sets: every one is on sale", function()
		t.equal(#SetRotation.featured(0, { "A" }), 1)
		t.equal(#SetRotation.featured(0, {}), 0)
		t.isTrue(SetRotation.onSale("A", 12345, { "A", "B" }))
	end)

	t.test("the store sells a set's weapon only in its week", function()
		local keys = stocked()
		local now = SetRotation.weekStart(1) + 3 * DAY
		local on = SetRotation.featured(now)
		for _, key in keys do
			local entry: ShopRules.Entry = {
				weapon = "X",
				class = "Ranger",
				label = "X",
				rarity = "Legendary",
				area = 1,
				set = key,
			}
			t.equal(
				ShopRules.buyable(entry, {}, false, now),
				table.find(on, key) ~= nil,
				key .. " sells only in its week"
			)
			t.isFalse(ShopRules.buyable(entry, {}, false), key .. " never without a clock")
		end
	end)
end
