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

--[[ Big Gulp's drag (`Remotes.PlayerDragged`): a cone out from `dragMouth`
     along `dragFacing`, pulling at `dragPull` studs a second until
     `dragUntil`. Added to walking rather than replacing it, so a player can
     walk out of the cone. ]]
local dragMouth = Vector3.zero
local dragFacing = Vector3.zAxis
local dragReach = 0
local dragCos = 1
local dragPull = 0
local dragUntil = 0

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

--[[ Dragged toward `mouth` while inside its cone, for `seconds`; 0 lets
     go now. ]]
function Shove.drag(
	now: number,
	mouth: Vector3,
	facing: Vector3,
	reach: number,
	halfAngle: number,
	pull: number,
	seconds: number
)
	dragMouth = Vector3.new(mouth.X, 0, mouth.Z)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	dragFacing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	dragReach = reach
	dragCos = math.cos(halfAngle)
	dragPull = pull
	dragUntil = if seconds > 0 then now + seconds else 0
end

--[[ The drag's pull on a body at `position` now, as a velocity, or zero
     outside its cone or its time. ]]
function Shove.dragVelocity(now: number, position: Vector3): Vector3
	if now >= dragUntil then
		return Vector3.zero
	end
	local offset = Vector3.new(position.X, 0, position.Z) - dragMouth
	local distance = offset.Magnitude
	if distance < 0.3 or distance > dragReach then
		return Vector3.zero
	end
	if offset:Dot(dragFacing) / distance < dragCos then
		return Vector3.zero
	end
	return -offset.Unit * dragPull
end

function Shove.reset()
	heading = Vector3.zero
	speed = 0
	shoveEndsAt = 0
	heldUntil = 0
	dragUntil = 0
end

return Shove
