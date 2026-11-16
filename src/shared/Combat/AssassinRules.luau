--!strict
--[[
	The arithmetic of the Assassin's cards (`Config/Abilities`, group
	"dagger"; numbers in `Balance.Player.assassin`): what counts as behind an
	enemy, how a fan of knives spreads, where each phantom blade is at a
	given moment, and which enemies a round of Thousand Cuts takes.

	Pure, so the server (`Combat/MeleeSystem`, `Combat/AssassinUpgrades`)
	and the client that draws it (`Fx/Upgrades/AssassinFx`) ask the same
	question of the same numbers, and `tests/AssassinCards.spec` pins them.
]]

local AssassinRules = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[ Backstab: whether a strike from `attackerAt` comes from behind an
     enemy at `enemyAt` that faces `facing`: within `arc` degrees round
     straight behind it. Standing on top of it is not behind it. ]]
function AssassinRules.behind(
	facing: Vector3,
	enemyAt: Vector3,
	attackerAt: Vector3,
	arc: number
): boolean
	local forward = flat(facing)
	local to = flat(attackerAt) - flat(enemyAt)
	if forward.Magnitude < 1e-6 or to.Magnitude < 1e-3 then
		return false
	end
	local cosine = math.clamp(to.Unit:Dot(-forward.Unit), -1, 1)
	return math.deg(math.acos(cosine)) <= arc / 2
end

--[[ Fan of Knives: the angle of each of `count` knives, in radians from
     the strike's own direction, evenly over `spread` degrees and centred
     on it. One knife flies straight. ]]
function AssassinRules.fan(count: number, spread: number): { number }
	local out: { number } = {}
	local n = math.max(math.floor(count), 0)
	if n == 1 then
		return { 0 }
	end
	local whole = math.rad(spread)
	for index = 0, n - 1 do
		table.insert(out, -whole / 2 + whole * index / (n - 1))
	end
	return out
end

--[[ `direction` turned `angle` radians about the upright, flat. ]]
function AssassinRules.turned(direction: Vector3, angle: number): Vector3
	local d = flat(direction)
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(d.X * c - d.Z * s, 0, d.X * s + d.Z * c)
end

--[[ Phantom Blades: where blade `index` of `count` is, `radius` out from
     `centre`, at `time` seconds (the server's clock, which every client
     shares), turning `turn` radians a second. Flat, at the centre's
     height. ]]
function AssassinRules.orbit(
	centre: Vector3,
	radius: number,
	turn: number,
	time: number,
	index: number,
	count: number
): Vector3
	local angle = time * turn + (index - 1) * (2 * math.pi / math.max(count, 1))
	return centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

--[[ Thousand Cuts: up to `most` of `enemies` within `range` of `from`, the
     nearest first: the order the shadows strike them in. ]]
function AssassinRules.round<T>(
	from: Vector3,
	enemies: { [T]: Vector3 },
	range: number,
	most: number
): { T }
	local found: { { key: T, away: number } } = {}
	for key, position in enemies do
		local away = (flat(position) - flat(from)).Magnitude
		if away <= range then
			table.insert(found, { key = key, away = away })
		end
	end
	table.sort(found, function(a, b)
		return a.away < b.away
	end)
	local out: { T } = {}
	for index = 1, math.min(#found, math.max(math.floor(most), 0)) do
		table.insert(out, found[index].key)
	end
	return out
end

--[[ Death Mark: the enemy of `enemies` nearest `from` within `reach`, or
     nil when there is none. ]]
function AssassinRules.nearest<T>(from: Vector3, enemies: { [T]: Vector3 }, reach: number): T?
	return AssassinRules.round(from, enemies, reach, 1)[1]
end

return AssassinRules
