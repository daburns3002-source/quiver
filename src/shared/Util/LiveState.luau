--!strict
--[[
	The live events as this server has published them (`Config/LiveEvents`,
	`Server/Data/LiveEvents`), read the same way on the server and on every
	screen: the clock, and the boosts running. Not pure (it reads the
	workspace's attributes); the rules it hands them to are
	(`Util/LiveBoosts`, `Util/SetRotation`).

	Only the server writes the attributes. A client that changed its own
	copy would fool its own screen and nothing else: the server rolls,
	pays and sells from its own.
]]

local Workspace = game:GetService("Workspace")

local LiveBoosts = require(script.Parent.LiveBoosts)
local LiveEvents = require(script.Parent.Parent.Config.LiveEvents)

local LiveState = {}

local ATTRIBUTES = LiveEvents.attributes

local function number(name: string): number?
	local value = Workspace:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

--[[ The server's clock, Unix seconds (the same on every screen), moved by
     the Studio test shift when there is one. ]]
function LiveState.now(): number
	return Workspace:GetServerTimeNow() + (number(ATTRIBUTES.shift) or 0)
end

--[[ Every boost that has an end, running or not: the weekend's (when it is
     one), the owner's live event and the Server Luck. ]]
function LiveState.boosts(now: number?): { LiveBoosts.Boost }
	local at = now or LiveState.now()
	local out: { LiveBoosts.Boost } = {}
	local weekend = LiveBoosts.weekend(at)
	if weekend then
		table.insert(out, weekend)
	end
	local kind = Workspace:GetAttribute(ATTRIBUTES.liveKind)
	local liveEnds = number(ATTRIBUTES.liveEnds)
	if type(kind) == "string" and liveEnds then
		table.insert(out, { kind = kind, source = "Live", endsAt = liveEnds })
	end
	local luckEnds = number(ATTRIBUTES.luckEnds)
	if luckEnds then
		local by = Workspace:GetAttribute(ATTRIBUTES.luckBy)
		table.insert(out, {
			kind = "Luck",
			source = "Server",
			endsAt = luckEnds,
			by = if type(by) == "string" then by else nil,
		})
	end
	return LiveBoosts.active(out, at)
end

--[[ The egg luck running now: 1 with none. ]]
function LiveState.luck(): number
	local now = LiveState.now()
	return LiveBoosts.luck(LiveState.boosts(now), now)
end

--[[ What the events add to a run's coin scale now: 0 with none. ]]
function LiveState.coinShare(): number
	local now = LiveState.now()
	return LiveBoosts.coinShare(LiveState.boosts(now), now)
end

return LiveState
