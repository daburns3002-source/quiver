--!strict
--[[
	A dash that cuts (`Config/Classes.dash`; the Assassin's Shadow Dash): the
	ground a dash covered, and who stood in it.

	The dash itself is the client's movement, as every position is
	(`Input/Dash`), and it is over in an eighth of a second: by the time
	the server sees the character move, half the dash is done (measured in
	Studio, 2026-11-16: 3.2 studs seen of 6). So the client says which way
	it dashed and the server draws the line itself: from where the
	character stands as the word arrives, along that way, a dash's length
	or as far as a wall lets it (`Combat/MeleeSystem.dash`). Every enemy
	within `width` of that line is struck. The way is the only thing the
	client says; a dash may go any way, so a client that lies about it has
	only dashed somewhere else.

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

--[[ The way a dash went, flat and unit length, from what a client sent:
     nil for anything that is not a direction (not a vector, not a number,
     straight up). ]]
function DashCut.heading(sent: unknown): Vector3?
	if typeof(sent) ~= "Vector3" then
		return nil
	end
	local way = flat(sent :: Vector3)
	if way.X ~= way.X or way.Z ~= way.Z or way.Magnitude < 1e-3 or way.Magnitude > 1e6 then
		return nil
	end
	return way.Unit
end

--[[ The line a dash cut, flat: `length` studs from `from` along `heading`
     (unit length). ]]
function DashCut.line(from: Vector3, heading: Vector3, length: number): (Vector3, Vector3)
	local a = flat(from)
	return a, a + flat(heading) * math.max(length, 0)
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
