--!strict
--[[
	Whether the run is stopped for a draft.

	One flag, read by everything the client drives itself: movement, firing
	prediction and the dash. It exists as its own module rather than as a
	field on any of them because the failure mode of two copies is that one
	gets cleared and the other does not — and a player who can still walk
	behind the card screen, or who can never shoot again after it, has hit
	exactly that.

	The server stops the world independently; this is the client half. Neither
	trusts the other, and the server's pause is the one that decides outcomes.
]]

local RunPaused = {}

local paused = false
local changed = Instance.new("BindableEvent")

function RunPaused.get(): boolean
	return paused
end

--[[ Idempotent, so callers can set it from several places without having to
     know whether it was already set — which they do: a draft opens from an
     offer and closes from either a grant or a death. ]]
function RunPaused.set(value: boolean)
	if paused == value then
		return
	end

	paused = value
	changed:Fire(value)
end

--[[ Fired on every change, so a listener can clear the state that only makes
     sense while the run is moving — a settle timer, say. ]]
function RunPaused.onChanged(callback: (boolean) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

return RunPaused
