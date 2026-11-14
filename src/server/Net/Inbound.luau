--!strict
--[[
	Every remote a client fires at the server is listened to here, and
	nowhere else: `tools/check.sh` fails on an `OnServerEvent` in any other
	file. Two things hold for all of them (the anti-exploit audit,
	`docs/FIXES.md`, 2026-11-13):

	- **A rate limit.** Each player has a bucket per remote (`Util/Throttle`):
	  `BURST` asks at once, then `RATE` a second. An ask with the bucket
	  empty is dropped before the handler sees it, and the drops are logged
	  once a minute per player and remote, so a flood shows in the server's
	  log. A person pressing buttons never comes near it. The handlers' own
	  limits (the shop's 0.35 s, the dash's cooldown) stay: this is the floor
	  under every remote, those are what each one needs.
	- **`Debug*` remotes are Studio's.** `Inbound.debug` connects nothing
	  outside Studio, so on a live server nothing listens to them at all;
	  each handler's own `RunService:IsStudio()` check stays as a second lock.

	Nothing here judges what is sent. Every handler still checks its own
	arguments' types and asks the server's state whether the ask is allowed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Throttle = require(ReplicatedStorage.Shared.Util.Throttle)

local log = Log.forTag("Inbound")

local Inbound = {}

--[[ Asks at once, then asks a second, for one player on one remote. ]]
local BURST = 10
local RATE = 5
--[[ Remotes a person can fire faster than that: the settings' sliders. ]]
local LIMITS: { [string]: { burst: number, rate: number } } = {
	[Remotes.SettingSet] = { burst = 20, rate = 10 },
}
--[[ Seconds between two log lines about one player's drops on one remote. ]]
local REPORT_EVERY = 60

type Seen = { bucket: Throttle.Bucket, dropped: number, reportedAt: number }
local seen: { [Player]: { [string]: Seen } } = {}

--[[ Whether this ask of `player`'s on remote `name` is within its limit. ]]
local function allow(player: Player, name: string): boolean
	local limit = LIMITS[name]
	local burst = if limit then limit.burst else BURST
	local rate = if limit then limit.rate else RATE
	local now = os.clock()
	local mine = seen[player]
	if not mine then
		mine = {}
		seen[player] = mine
	end
	local entry = mine[name]
	if not entry then
		entry = { bucket = Throttle.new(burst, now), dropped = 0, reportedAt = -math.huge }
		mine[name] = entry
	end
	if Throttle.take(entry.bucket, now, rate, burst) then
		return true
	end
	entry.dropped += 1
	if now - entry.reportedAt >= REPORT_EVERY then
		log.warn(
			"%s is over the limit on %s: %d dropped since this was last said",
			player.Name,
			name,
			entry.dropped
		)
		entry.reportedAt = now
		entry.dropped = 0
	end
	return false
end

--[[ Listens to client→server remote `name` (a `Remotes` key), rate
     limited. The handler gets the player and whatever the client sent,
     unchecked: checking it is the handler's job. ]]
function Inbound.on(name: string, handler: (Player, ...any) -> ()): RBXScriptConnection
	assert(name:sub(1, 5) ~= "Debug", `{name} is a Studio remote: Inbound.debug`)
	return Remotes.event(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if allow(player, name) then
			handler(player, ...)
		end
	end)
end

--[[ A `Debug*` remote: listened to in Studio only, rate limited like the
     rest. Outside Studio this connects nothing. ]]
function Inbound.debug(name: string, handler: (Player, ...any) -> ())
	assert(name:sub(1, 5) == "Debug", `{name} is not a Studio remote: Inbound.on`)
	if not RunService:IsStudio() then
		return
	end
	Remotes.event(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if allow(player, name) then
			handler(player, ...)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	seen[player] = nil
end)

return Inbound
