--!strict
--[[
	Hard mode (owner, 2026-11-18: "yes all of these create them"), pure, so
	the server decides with it, the screens draw with it, and
	`tests/HardRules.spec` pins it.

	**When.** Once an area's boss is beaten, its levels can be played on HARD
	(`offered`): the area's level screen gets a NORMAL / HARD toggle
	(`UI/PortalScreen`). Hard levels open in order as normal ones do, the
	first at once and each after the one before it is won on hard
	(`isOpen`, `Util/LevelUnlocks` over the hard wins). The server asks the
	same before it starts one (`Run/Lobby.hardOpen`), so a hard level whose
	area boss stands is refused whatever a client sends.

	**Harder.** Every enemy's health and damage, bosses included, are
	multiplied by `Balance.Hard` on top of the level's own numbers and its
	within-level ramp, with co-op's scaling on top as on normal
	(`Enemies/EnemyManager`). Every fight without a boss has one elite
	(`eliteSlot`), `Balance.Hard.eliteHealth` times as tough and marked in
	gold over its head (`Fx/EnemyHealthBars`). No new models.

	**Better paid.** Kill and clear coins get `Config/Rewards.hard.coins`
	added to their scale (`Util/RunBonus.hard`). Each level's first hard
	clear pays gems (`gems`), more for an area's last level. Winning an
	area's last level on hard (so every hard level there) earns that area's
	name-tag frame, a plate behind the name in the area's colour that
	everyone sees (`frame`, `UI/NameTags`): the furthest area's is worn.

	**No stars of its own** (`starLevel`): an area's 30 stars and their
	chests at 10, 20 and 30 are earned on normal, and a second set would
	double those chests. A hard win fills the level's normal stars instead.

	Saved as `profile.hardBeaten` (save version 24), the level names won on
	hard. The run being played is on hard while the Workspace's `Hard`
	attribute is true (`ATTRIBUTE`, read through `Util/CurrentStage.hard`).
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local LevelUnlocks = require(script.Parent.LevelUnlocks)
local Rewards = require(script.Parent.Parent.Config.Rewards)

local HardRules = {}

--[[ The Workspace attribute that says the run being played is on hard. ]]
HardRules.ATTRIBUTE = "Hard"
--[[ The attribute that marks a fight's elite enemy (its model). ]]
HardRules.ELITE = "HardElite"
--[[ The Player attribute naming the area whose frame their name tag wears. ]]
HardRules.FRAME = "HardFrame"

export type Beaten = LevelUnlocks.Beaten
type Stages = { [number]: Balance.StageConfig }

--[[ The area a portal's levels are in: the first of them that is a named
     campaign level of an area. Nil for Endless and for an arch with none. ]]
function HardRules.areaOf(levels: { number }?, stages: Stages): string?
	if not levels then
		return nil
	end
	for _, index in levels do
		local stage = stages[index]
		if
			stage
			and stage.area
			and stage.level
			and not stage.tutorial
			and stage.mode ~= "Endless"
		then
			return stage.area
		end
	end
	return nil
end

--[[ Whether a portal's levels can be played on hard at all: the boss of
     their area is beaten. ]]
function HardRules.offered(
	levels: { number }?,
	stages: Stages,
	bosses: { [string]: boolean }?
): boolean
	local area = HardRules.areaOf(levels, stages)
	return area ~= nil and bosses ~= nil and bosses[area] == true
end

--[[ Whether the `position`th of `levels` is open on hard: offered, a named
     level, and the one before it won on hard (the first is open at once). ]]
function HardRules.isOpen(
	levels: { number }?,
	stages: Stages,
	bosses: { [string]: boolean }?,
	hardBeaten: Beaten?,
	position: number
): boolean
	if not levels or not HardRules.offered(levels, stages, bosses) then
		return false
	end
	local stage = stages[levels[position] or 0]
	if not stage or not stage.level then
		return false
	end
	return LevelUnlocks.isUnlocked(levels, stages, hardBeaten, position)
end

--[[ The level a hard screen opens on: the first open one not yet won on
     hard, as normal's (`LevelUnlocks.suggested`). ]]
function HardRules.suggested(levels: { number }, stages: Stages, hardBeaten: Beaten?): number
	return LevelUnlocks.suggested(levels, stages, hardBeaten)
end

--[[ What enemy health and damage are multiplied by: `Balance.Hard` on
     hard, nothing otherwise. ]]
function HardRules.scale(on: boolean): { health: number, damage: number }
	if not on then
		return { health = 1, damage = 1 }
	end
	return { health = Balance.Hard.health, damage = Balance.Hard.damage }
end

--[[ Which of a fight's `count` spawns (in order, from 1) is its elite: the
     middle one, so a room is the same fight every run. 0 for none: off
     hard, a fight with a boss in it, or nothing to spawn. ]]
function HardRules.eliteSlot(count: number, boss: boolean, on: boolean): number
	if not on or boss or count < 1 then
		return 0
	end
	return math.ceil(math.floor(count) / 2)
end

--[[ The gems the first hard clear of the `position`th of `levels` pays:
     `lastGems` for an area's last level, `gems` for the rest. ]]
function HardRules.gems(levels: { number }, position: number): number
	if position == #levels then
		return Rewards.hard.lastGems
	end
	return Rewards.hard.gems
end

--[[ The levels of the portal holding stage `index`, and its place there. ]]
function HardRules.find(portals: { any }, index: number): ({ number }?, number?)
	for _, portal in portals do
		local levels = if type(portal) == "table" then portal.levels else nil
		if type(levels) == "table" then
			local at = table.find(levels, index)
			if at then
				return levels, at
			end
		end
	end
	return nil, nil
end

--[[ The stage NEXT LEVEL plays after a hard win of stage `index`: the
     area's next level, on hard. Nil after an area's last: a hard run never
     goes on into the next area, whose boss may stand, so that win is won
     into the lobby. ]]
function HardRules.nextIndex(portals: { any }, index: number): number?
	local levels, at = HardRules.find(portals, index)
	if not levels or not at then
		return nil
	end
	return levels[at + 1]
end

--[[ The area whose name-tag frame a player wears: the furthest, in the
     portals' order, whose last level they have won on hard. Nil for none. ]]
function HardRules.frame(portals: { any }, stages: Stages, hardBeaten: Beaten?): string?
	if not hardBeaten then
		return nil
	end
	local worn: string? = nil
	for _, portal in portals do
		local levels = if type(portal) == "table" then portal.levels else nil
		if type(levels) == "table" and #levels > 0 then
			local area = HardRules.areaOf(levels, stages)
			local last = stages[levels[#levels]]
			if area and last and last.level and hardBeaten[last.level] == true then
				worn = area
			end
		end
	end
	return worn
end

--[[ A frame's colour: its area's portal tint. Nil for an area with none. ]]
function HardRules.frameColour(portals: { any }, stages: Stages, area: string?): Color3?
	if not area then
		return nil
	end
	for _, portal in portals do
		local levels = if type(portal) == "table" then portal.levels else nil
		if HardRules.areaOf(levels, stages) == area and typeof(portal.tint) == "Color3" then
			return portal.tint
		end
	end
	return nil
end

--[[ The level a hard win's stars are written to: the level's own. Hard has
     no stars of its own (see the top). ]]
function HardRules.starLevel(stage: Balance.StageConfig): string?
	return stage.level
end

return HardRules
