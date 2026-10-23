--!strict
--[[
	A boss's hit moving the player: a shove (pushed `distance` studs along a
	direction over `Balance.Shove.duration`) or a hold (the Slime Lash's grab:
	not moving at all until it lets go).

	A state machine and nothing else, like `Dash`: the server says what
	happened (`Remotes.PlayerShoved`, `Remotes.PlayerGrabbed`) and
	`MoveController` applies it by driving the Humanoid, so walls stop a
	shove the way they stop walking. Every function takes `now`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local Shove = {}

local heading = Vector3.zero
local speed = 0
local shoveEndsAt = 0
local heldUntil = 0

function Shove.push(now: number, direction: Vector3, distance: number)
	local along = Vector3.new(direction.X, 0, direction.Z)
	if along.Magnitude < 1e-3 or distance <= 0 then
		return
	end
	local duration = Balance.Shove.duration
	heading = along.Unit
	speed = distance / duration
	shoveEndsAt = now + duration
end

--[[ Held still for `seconds`; 0 lets go now. ]]
function Shove.hold(now: number, seconds: number)
	heldUntil = if seconds > 0 then now + seconds else 0
end

function Shove.isHeld(now: number): boolean
	return now < heldUntil
end

--[[ The push in flight, if any: its heading and speed. A hold outranks it
     (`MoveController` asks `isHeld` first). ]]
function Shove.current(now: number): (Vector3?, number)
	if now >= shoveEndsAt then
		return nil, 0
	end
	return heading, speed
end

function Shove.reset()
	heading = Vector3.zero
	speed = 0
	shoveEndsAt = 0
	heldUntil = 0
end

return Shove
