--!strict
--[[
	The queue of messages for players who are away (`Data/NotifyQueue`),
	run whole on a table standing in for the MemoryStore sorted map, with a
	stub sender. Every value goes through JSON on its way in and out, as
	MemoryStore's would, so a plan that cannot be stored fails here.
]]

local TestRunner = require(script.Parent.TestRunner)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Notifications = require(ReplicatedStorage.Shared.Config.Notifications)
local NotifyQueue = require(ServerScriptService.Server.Data.NotifyQueue)
local NotifyRules = require(ReplicatedStorage.Shared.Util.NotifyRules)

local HOUR = 3600
local DAY = 86400
local T0 = 1794787200 + 10 * HOUR

local function copy(value: any): any
	if value == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function fakeStore(): (NotifyQueue.Store, { [string]: any })
	local rows: { [string]: any } = {}
	local store: NotifyQueue.Store = {
		set = function(key, value, sortKey)
			rows[key] = { value = copy(value), sortKey = sortKey }
		end,
		remove = function(key)
			rows[key] = nil
		end,
		due = function(now, count)
			local out = {}
			for key, row in rows do
				if row.sortKey <= now then
					table.insert(out, { key = key, value = copy(row.value), sortKey = row.sortKey })
				end
			end
			table.sort(out, function(a, b)
				return a.sortKey < b.sortKey
			end)
			while #out > count do
				table.remove(out)
			end
			return out
		end,
		update = function(key, transform)
			local row = rows[key]
			local value, sortKey = transform(row and copy(row.value), row and row.sortKey)
			if value == nil then
				return nil
			end
			rows[key] = { value = copy(value), sortKey = sortKey }
			return copy(value)
		end,
	}
	return store, rows
end

local function plan(user: number): NotifyRules.Entry
	return NotifyRules.plan({
		user = user,
		now = T0,
		zone = 0,
		dailyAt = T0,
		giftFull = false,
		upcoming = { season = { at = T0 + DAY } },
	}) :: NotifyRules.Entry
end

return function(t: TestRunner.Helper)
	t.test("a plan is sent message by message, each on time, then is gone", function()
		local store, rows = fakeStore()
		local sent = {}
		local q = NotifyQueue.new(store, function(user, kind)
			table.insert(sent, { user = user, kind = kind })
			return "sent"
		end)
		local entry = plan(7)
		q:leave(entry)
		local times = {}
		for _, item in entry.items do
			table.insert(times, item.at)
		end
		t.equal(q:poll(times[1] - 1), 0, "nothing before its time")
		local now = times[1]
		local guard = 0
		while next(rows) and guard < 50 do
			guard += 1
			local row = rows["7"]
			now = math.max(now, row.sortKey)
			q:poll(now)
			t.equal(q:poll(now), 0, "never twice for one slot")
		end
		t.isNil(next(rows), "the plan is removed once spent")
		t.equal(#sent, #entry.items)
		for i, s in sent do
			t.equal(s.user, 7)
			t.equal(s.kind, entry.items[i].kind)
		end
	end)

	t.test("two servers polling one queue send a message once", function()
		local store = fakeStore()
		local count = 0
		local other: NotifyQueue.Queue
		local first = NotifyQueue.new(store, function()
			count += 1
			-- the other server looks while this one is still sending
			other:poll(T0 + DAY)
			return "sent"
		end)
		other = NotifyQueue.new(store, function()
			count += 1
			return "sent"
		end)
		first:leave(plan(8))
		first:poll(T0 + DAY)
		other:poll(T0 + DAY)
		t.equal(count, 1)
	end)

	t.test("a player who comes back is sent nothing", function()
		local store, rows = fakeStore()
		local count = 0
		local q = NotifyQueue.new(store, function()
			count += 1
			return "sent"
		end)
		q:leave(plan(9))
		q:back(9)
		t.isNil(rows["9"])
		q:poll(T0 + Notifications.giveUp)
		t.equal(count, 0)
	end)

	t.test("a refused key pauses this server and loses nothing", function()
		local store, rows = fakeStore()
		local answer = "key"
		local count = 0
		local q = NotifyQueue.new(store, function()
			count += 1
			return answer
		end)
		local entry = plan(10)
		q:leave(entry)
		local due = entry.items[1].at
		q:poll(due)
		t.equal(count, 1)
		t.notNil(rows["10"], "the message still waits")
		q:poll(due + 60)
		t.equal(count, 1, "no call while paused")
		answer = "sent"
		local later = due + Notifications.keyPause
		t.equal(q:poll(later), 1, "sent once the pause is over")
	end)

	t.test("a retry is tried again later, not lost", function()
		local store, rows = fakeStore()
		local answers = { "retry", "sent" }
		local q = NotifyQueue.new(store, function()
			return table.remove(answers, 1) or "sent"
		end)
		local entry = plan(11)
		q:leave(entry)
		local due = entry.items[1].at
		t.equal(q:poll(due), 0)
		local again = rows["11"].sortKey
		t.isTrue(again > due, "later")
		t.equal(q:poll(again), 1)
	end)
end
