--!strict
--[[
	A dash that cuts (`Config/Classes.dash`; the Assassin's Shadow Dash): the
	ground a dash covered, and who stood in it.

	The dash itself is the client's movement, as every position is
	(`Input/Dash`). The server only notes where the character was when the
	dash began and where it is when the dash is over, and strikes every
	enemy within `width` of the line between (`Combat/MeleeSystem.dash`).
	`path` never trusts that line to be longer than a dash can be, so a
	client that moves its character somewhere else mid-dash cuts no more
	ground than an honest one.

	Pure geometry, flat on the floor, so `tests/DashCut.spec` can pin its
	edges. Height never decides a hit.
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local Classes = require(script.Parent.Parent.Config.Classes)

local DashCut = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[ Seconds between dashes for `class`: its own (`Classes.dash.cooldown`),
     or everyone's (`Balance.Player.dash.cooldown`). ]]
function DashCut.cooldown(class: string?): number
	local config = class and Classes[class]
	local own = config and config.dash
	return if own then own.cooldown else Balance.Player.dash.cooldown
end

--[[ The line a dash cut, flat: from where it began to where it ended, and
     no longer than `most` studs however far apart the two are. ]]
function DashCut.path(from: Vector3, to: Vector3, most: number): (Vector3, Vector3)
	local a, b = flat(from), flat(to)
	local span = b - a
	if span.Magnitude > most and most >= 0 then
		b = a + span.Unit * most
	end
	return a, b
end

--[[ The point of the line from `a` to `b` nearest `at`, flat. ]]
function DashCut.nearest(a: Vector3, b: Vector3, at: Vector3): Vector3
	local start, finish, point = flat(a), flat(b), flat(at)
	local span = finish - start
	local length = span.Magnitude
	if length < 1e-6 then
		return start
	end
	local along = math.clamp((point - start):Dot(span) / (length * length), 0, 1)
	return start + span * along
end

--[[ Whether a body at `at`, `halfWidth` across, stood in a cut `width`
     studs across along the line from `a` to `b`. A dash that went nowhere
     (into a wall) still cuts what it stands in. ]]
function DashCut.hits(
	a: Vector3,
	b: Vector3,
	width: number,
	at: Vector3,
	halfWidth: number
): boolean
	local near = DashCut.nearest(a, b, at)
	return (flat(at) - near).Magnitude <= width / 2 + halfWidth
end

return DashCut
