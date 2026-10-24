--!strict
--[[
	The pure half of the slime residue (`Fx/SlimeResidue`, `Balance.
	SlimeResidue`): how many cubes a hit throws, which way each one goes,
	how big and what colour, and which pooled cube it takes. No instances,
	so `tests/ResidueSpray.spec.luau` can pin the shapes it makes.
]]

local ResidueSpray = {}

--[[ One slime's residue, from `Balance.SlimeResidue.kinds`. ]]
export type Kind = {
	light: Color3,
	dark: Color3,
	moss: Color3,
	--[[ Studs along each edge of a typical cube. ]]
	size: number,
	--[[ Cubes thrown by a plain hit. ]]
	count: number,
}

export type Range = { min: number, max: number }

--[[ The numbers every slime shares, `Balance.SlimeResidue` itself. ]]
export type Settings = {
	kinds: { [string]: Kind },
	mossShare: number,
	sizeJitter: number,
	critScale: number,
	killScale: number,
	arc: number,
	speed: Range,
	rise: Range,
	gravity: number,
	spin: number,
	splatWide: number,
	splatFlat: number,
	floorLift: number,
	rest: number,
	shrink: number,
}

--[[ How many cubes a hit of `hitKind` throws, `killed` or not. Never
     fewer than one: a hit with nothing thrown reads as a miss. ]]
function ResidueSpray.count(
	kind: Kind,
	hitKind: string?,
	killed: boolean,
	settings: Settings
): number
	local n = kind.count
	if hitKind == "Crit" then
		n *= settings.critScale
	end
	if killed then
		n *= settings.killScale
	end
	return math.max(1, math.round(n))
end

--[[ Radians across the fan a hit throws into: the configured arc, or all
     the way round on a kill. ]]
function ResidueSpray.arc(killed: boolean, settings: Settings): number
	if killed then
		return math.pi * 2
	end
	return math.rad(settings.arc)
end

--[[ The flat direction a hit throws towards: out of the face the shot came
     in by, which is from the body back towards `from`. Any direction when
     `from` is missing or on top of the body. ]]
function ResidueSpray.back(centre: Vector3, from: Vector3?, rng: Random): Vector3
	if from then
		local flat = Vector3.new(from.X - centre.X, 0, from.Z - centre.Z)
		if flat.Magnitude > 1e-3 then
			return flat.Unit
		end
	end
	local angle = rng:NextNumber() * math.pi * 2
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

--[[ How fast each of `count` cubes leaves, fanned evenly across `arc`
     radians centred on `back`, each jittered inside its own share of the
     fan so a burst never looks like a ruled comb. Every one rises. ]]
function ResidueSpray.velocities(
	back: Vector3,
	count: number,
	arc: number,
	settings: Settings,
	rng: Random
): { Vector3 }
	local out = table.create(count)
	local slot = arc / count
	for index = 1, count do
		local centre = ((index - 0.5) / count - 0.5) * arc
		local angle = centre + (rng:NextNumber() - 0.5) * slot * 0.8
		local turned = CFrame.Angles(0, angle, 0):VectorToWorldSpace(back)
		local speed = settings.speed.min
			+ rng:NextNumber() * (settings.speed.max - settings.speed.min)
		local rise = settings.rise.min + rng:NextNumber() * (settings.rise.max - settings.rise.min)
		out[index] = turned * speed + Vector3.yAxis * rise
	end
	return out
end

--[[ One cube's edge, within `sizeJitter` of the slime's size. ]]
function ResidueSpray.size(kind: Kind, settings: Settings, rng: Random): number
	return kind.size * (1 + (rng:NextNumber() * 2 - 1) * settings.sizeJitter)
end

--[[ One cube's colour: moss now and then, else the jelly's light and dark
     shades taking turns. ]]
function ResidueSpray.colour(kind: Kind, index: number, settings: Settings, rng: Random): Color3
	if rng:NextNumber() < settings.mossShare then
		return kind.moss
	end
	return if index % 2 == 0 then kind.dark else kind.light
end

--[[ The pooled cube after `last`, of `cap`: round and round, so a burst
     beyond the cap takes the oldest cubes back rather than making more. ]]
function ResidueSpray.slot(last: number, cap: number): number
	return last % cap + 1
end

return ResidueSpray
