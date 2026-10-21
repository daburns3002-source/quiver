--!strict
--[[
	The dash: a short, fast, committed burst in one direction.

	A state machine and nothing else. It owns no Roblox objects, reads no
	input and touches no character — `MoveController` drives it and applies
	the result, `DashButton` and the spacebar ask it for one. Every function
	takes `now`, so the whole thing is testable without a running game, which
	is the point: cooldowns and windows are exactly the kind of state that
	looks right and behaves wrong.

	**Committed on purpose.** The direction is captured when the dash starts
	and cannot be steered afterwards. A dash you can turn mid-flight is just a
	speed boost, and it removes the only thing that makes it a decision —
	choosing *where* before you know what the room will do next.

	Nothing here is authoritative, in the same sense movement is not: the
	server reads the replicated Humanoid and decides whether a volley goes
	out. A client that lies about dashing is lying about its position, which
	it could already do.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PlayerStats = require(script.Parent.Parent.PlayerStats)

local Dash = {}

--[[ When the current dash ends, and when the next one may begin. Both are
     absolute `os.clock()` values, and both being in the past is the resting
     state. ]]
local endsAt = 0
local readyAt = 0

--[[ Held for the whole dash. Flat and unit length. ]]
local heading = Vector3.zero

--[[ Studs per second while dashing, derived rather than configured so the two
     numbers that matter — how far, and how long — stay the ones a designer
     actually reasons about. ]]
local function dashSpeed(): number
	local dash = Balance.Player.dash
	return dash.distance / dash.duration
end

--[[ Flattens and normalises, or returns nil when there is nothing to go on. ]]
local function flatten(direction: Vector3): Vector3?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else nil
end

--[[
	Starts a dash if one is available.

	`desired` is the direction the player is currently asking to move in, and
	`facing` is where the character is pointed. Falling back to facing is what
	makes the button work for a standing player: a dash that did nothing
	unless you were already moving would be useless at the exact moment it is
	most wanted, which is when a fan is about to land on someone who stopped
	to shoot.

	Returns whether a dash began, so a caller can play a sound or refuse
	without asking a second question.
]]
function Dash.request(now: number, desired: Vector3, facing: Vector3): boolean
	if now < readyAt or now < endsAt then
		return false
	end

	local direction = flatten(desired) or flatten(facing)
	if not direction then
		return false
	end

	heading = direction
	endsAt = now + Balance.Player.dash.duration
	--[[ Measured from the start, not the end, so the cooldown a player feels
	     is the number in the config rather than that plus the duration.
	     Taken from the replicated stats so Lightfoot shortens it. ]]
	readyAt = now + PlayerStats.get().dashCooldown
	return true
end

--[[ The direction and speed to move at this frame, or nil when not dashing.
     `MoveController` uses the presence of a direction here to decide whether
     to override player input at all. ]]
function Dash.current(now: number): (Vector3?, number)
	if now >= endsAt then
		return nil, 0
	end

	return heading, dashSpeed()
end

function Dash.isDashing(now: number): boolean
	return now < endsAt
end

--[[
	How ready the next dash is, from 0 to 1.

	For the button, which has to answer "can I press this" at a glance on a
	phone without reading a number. 1 means ready.
]]
function Dash.readiness(now: number): number
	local cooldown = PlayerStats.get().dashCooldown
	if cooldown <= 0 then
		return 1
	end

	local remaining = readyAt - now
	if remaining <= 0 then
		return 1
	end

	return math.clamp(1 - remaining / cooldown, 0, 1)
end

--[[ Clears every window. Called when a character dies or respawns, so a dash
     in flight cannot survive into the next life and a cooldown cannot be
     carried across a death the player did not choose. ]]
function Dash.reset()
	endsAt = 0
	readyAt = 0
	heading = Vector3.zero
end

return Dash
