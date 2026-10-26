--!strict
--[[
	A pet's root (`Config/PetCombat` `root`, Stumpy's Root Snare): how long
	it holds an enemy, and how two holds on one enemy combine. Pure, so the
	server's hold (`Enemies/EnemyManager.root`) and the roots drawn round the
	held enemy's feet (`Fx/RootHoldFx`) keep one clock, and
	`tests/RootHold.spec` pins it.

	A held enemy does not walk, lunge, dive or slide with a hit's shove; it
	still attacks from where it stands.
]]

export type Root = {
	--[[ Seconds it holds an enemy, and a boss (0: not at all). ]]
	duration: number,
	boss: number,
}

local RootHold = {}

--[[ Seconds a root holds this enemy. ]]
function RootHold.seconds(root: Root, isBoss: boolean): number
	return math.max(0, if isBoss then root.boss else root.duration)
end

--[[ When an enemy held until `current` is let go after a new root of
     `seconds` lands at `now`: the longer of the two, never their sum, so
     roots refresh a hold rather than chaining it. ]]
function RootHold.extend(current: number, now: number, seconds: number): number
	return math.max(current, now + seconds)
end

function RootHold.held(untilTime: number, now: number): boolean
	return now < untilTime
end

--[[ The share of the time one pet keeps a single enemy held, at most:
     attacking every `every` seconds. ]]
function RootHold.uptime(root: Root, every: number): number
	return if every > 0 then math.min(1, root.duration / every) else 1
end

return RootHold
