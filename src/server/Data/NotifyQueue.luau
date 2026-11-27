--!strict
--[[
	The notifications waiting to be sent to players who are away
	(`docs/NOTIFICATIONS.md`). A player is offline, so no server of theirs
	is running: the plan made as they leave (`NotifyRules.plan`) is kept in
	a MemoryStore sorted map that every game server shares, sorted by when
	its next message is due, and every server looks at what is due once a
	`Config/Notifications.poll` and sends a few (`perPoll`).

	**One send per message, whichever servers look.** A server claims an
	entry before sending it: an `UpdateAsync` that only succeeds when the
	entry is due and not already held, and holds it `lease` seconds. After
	the send the plan moves on (`NotifyRules.step`) and is written back, or
	removed once nothing is left. A player who comes back is taken out
	(`back`): nothing is sent to someone playing.

	The map is behind `Store` so `tests/NotifyQueue.spec` runs the whole
	flow on a table and a stub sender. MemoryStore keeps an entry at most
	45 days; one here lives `giveUp` and a day. Nothing is sent while no
	server of the game is running: the messages wait for the next one.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Notifications = require(ReplicatedStorage.Shared.Config.Notifications)
local NotifyRules = require(ReplicatedStorage.Shared.Util.NotifyRules)

local log = Log.forTag("Notify")

local NotifyQueue = {}

local MAP = "Notifications"
local EXPIRY = Notifications.giveUp + 86400

export type Row = { key: string, value: any, sortKey: number }
export type Store = {
	set: (key: string, value: any, sortKey: number) -> (),
	remove: (key: string) -> (),
	--[[ Up to `count` entries due by `now`, soonest first. ]]
	due: (now: number, count: number) -> { Row },
	--[[ `transform` gets the value and sort key and returns new ones, or
	     nil to leave it; returns the new value, nil if left. ]]
	update: (key: string, transform: (value: any, sortKey: number?) -> (any, number?)) -> any,
}
export type Sender = (user: number, kind: string) -> string

export type Queue = {
	store: Store,
	sender: Sender,
	pausedUntil: number,
	leave: (self: Queue, entry: NotifyRules.Entry) -> (),
	back: (self: Queue, user: number) -> (),
	poll: (self: Queue, now: number) -> number,
}

--[[ The game's shared sorted map as a `Store`. Every call yields. ]]
function NotifyQueue.memoryStore(): Store
	local map = MemoryStoreService:GetSortedMap(MAP)
	return {
		set = function(key, value, sortKey)
			map:SetAsync(key, value, EXPIRY, sortKey)
		end,
		remove = function(key)
			map:RemoveAsync(key)
		end,
		due = function(now, count)
			local rows = map:GetRangeAsync(
				Enum.SortDirection.Ascending,
				count,
				nil,
				{ sortKey = now + 1 } :: any
			)
			return rows :: any
		end,
		update = function(key, transform)
			return (map:UpdateAsync(key, transform :: any, EXPIRY))
		end,
	}
end

local function keyOf(user: number): string
	return tostring(user)
end

local Queue = {}
Queue.__index = Queue

function NotifyQueue.new(store: Store, sender: Sender): Queue
	return setmetatable({ store = store, sender = sender, pausedUntil = 0 }, Queue) :: any
end

--[[ The player left with this plan. ]]
function Queue.leave(self: Queue, entry: NotifyRules.Entry)
	local first = entry.items[1]
	if first then
		self.store.set(keyOf(entry.user), entry, first.at)
	end
end

--[[ The player is back: nothing waits for them any more. ]]
function Queue.back(self: Queue, user: number)
	self.store.remove(keyOf(user))
end

--[[ Sends what is due at `now`, at most `perPoll`. Returns how many
     went. Yields. ]]
function Queue.poll(self: Queue, now: number): number
	if now < self.pausedUntil then
		return 0
	end
	local sent = 0
	for _, row in self.store.due(now, Notifications.perPoll) do
		local lease = now + Notifications.lease
		local claimed = self.store.update(row.key, function(value: any, _sortKey: number?)
			if type(value) ~= "table" or type(value.items) ~= "table" then
				return nil
			end
			local first = value.items[1]
			if not first or first.at > now or (value.lease or 0) > now then
				return nil
			end
			value.lease = lease
			return value, lease
		end)
		if claimed then
			local entry = claimed :: NotifyRules.Entry
			local kind = entry.items[1].kind
			local outcome = self.sender(entry.user, kind)
			if outcome == "key" then
				-- the key is wrong for every message: hand it back and stop
				self.pausedUntil = now + Notifications.keyPause
				self.store.update(row.key, function(value: any)
					if type(value) ~= "table" or value.lease ~= lease then
						return nil
					end
					value.lease = 0
					return value, now + Notifications.keyPause
				end)
				log.warn("sending paused for %d s: the API key was refused", Notifications.keyPause)
				break
			end
			if outcome == "sent" then
				sent += 1
			end
			local nextEntry = NotifyRules.step(entry, outcome, now)
			if nextEntry then
				local plan = nextEntry
				self.store.update(row.key, function(value: any)
					-- gone or replaced: the player came back meanwhile
					if type(value) ~= "table" or value.lease ~= lease then
						return nil
					end
					(plan :: any).lease = nil
					return plan, plan.items[1].at
				end)
			else
				-- spent. A player who left again in the second this send
				-- took would lose their new plan here: rare, and harmless.
				self.store.remove(row.key)
			end
		end
	end
	return sent
end

return NotifyQueue
