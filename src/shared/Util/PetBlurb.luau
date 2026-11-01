--!strict
--[[
	What a pet does, in words, read straight off `Config/PetCombat` (Codex's
	hatchery screen, 2026-10-29; owner, 2026-10-31: "codex made a good one a
	couple days ago that i want to use").

	The numbers are never written down twice: every sentence is formatted
	from the same spec the server fights with, so retuning a pet retunes
	what the hatchery says about it and the two can never drift. A pet with
	no combat spec says so rather than inventing a line.

	Pure, so `tests/PetBlurb.spec` pins it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bleed = require(ReplicatedStorage.Shared.Combat.Bleed)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetWake = require(ReplicatedStorage.Shared.Util.PetWake)
local Shelter = require(ReplicatedStorage.Shared.Util.Shelter)

local PetBlurb = {}

--[[ Said when a pet has no `Config/PetCombat` entry at all. ]]
PetBlurb.NONE = "This pet has no combat behaviour yet."

local function percent(n: number): string
	return string.format("%g%%", n)
end

--[[ The lines describing pet `key`, in the order they are shown: what it
     does on its clock first, then what it does to the enemy, then what it
     does for the player. Empty for a pet with no spec. ]]
function PetBlurb.lines(key: string): { string }
	local spec = PetCombat.pets[key]
	if not spec then
		return {}
	end
	local out: { string } = {}
	local function add(line: string)
		table.insert(out, line)
	end

	if spec.guard then
		add("Shell Guard blocks the next hit you would take. The shell comes back each room.")
	end
	if spec.reflect then
		add(
			string.format(
				"Blocking bursts thorns for %g damage to every enemy within %g studs.",
				spec.reflect.damage,
				spec.reflect.radius
			)
		)
	end

	local aura = spec.aura
	if aura then
		add(
			string.format(
				"A ring of thorns turns around you, hitting everything within %g studs for %g damage every %g seconds.",
				aura.radius,
				aura.damage,
				aura.every
			)
		)
	end

	local damage = spec.damage
	if damage then
		local hits = spec.hits or 1
		local targets = spec.targets or 1
		if spec.beam then
			add(
				string.format(
					"Fires a piercing beam for %g damage every %g seconds, hitting everything along it.",
					damage,
					spec.every
				)
			)
		elseif spec.dash then
			add(
				string.format(
					"Dashes to up to %g enemies for %g damage each, %g seconds between attacks.",
					targets,
					damage,
					spec.every
				)
			)
		elseif hits > 1 then
			add(
				string.format(
					"Fires %g shots for %g damage each every %g seconds (%g in all if every one lands).",
					hits,
					damage,
					spec.every,
					hits * damage
				)
			)
		elseif targets > 1 then
			add(
				string.format(
					"Deals %g damage to up to %g enemies every %g seconds.",
					damage,
					targets,
					spec.every
				)
			)
		else
			add(string.format("Deals %g damage every %g seconds.", damage, spec.every))
		end
	end

	if spec.bossDamage then
		add(
			string.format(
				"Hits bosses for %g more, so %g a hit.",
				spec.bossDamage,
				(damage or 0) + spec.bossDamage
			)
		)
	end
	if spec.slow then
		add(
			string.format(
				"Slows what it hits by %s for %g seconds.",
				percent((1 - spec.slow.scale) * 100),
				spec.slow.duration
			)
		)
	end
	local hold = spec.root
	if hold then
		add(
			string.format(
				"Holds its target still for %g seconds.%s",
				hold.duration,
				if hold.boss > 0
					then string.format(" Even a boss, for %g.", hold.boss)
					else " Bosses cannot be held."
			)
		)
	end
	if spec.chain then
		add(
			string.format(
				"The hold jumps to %g more enemy beside it, which takes no damage.",
				spec.chain
			)
		)
	end
	if spec.burn then
		add(
			string.format(
				"Burns for %g a second over %g seconds.",
				spec.burn.rate,
				spec.burn.duration
			)
		)
	end
	local bleed = spec.bleed
	if bleed then
		add(
			string.format(
				"Every hit drives in a thorn, up to %g: %g a second each, so %g a second on a full stack. They lapse %g seconds after the last one.",
				bleed.stacks,
				bleed.rate,
				Bleed.rate(bleed, bleed.stacks),
				bleed.duration
			)
		)
	end
	if spec.mark then
		add(
			string.format(
				"Marks a target every %g seconds; it takes %s more damage for %g seconds.",
				spec.every,
				percent((spec.mark.scale - 1) * 100),
				spec.mark.duration
			)
		)
	end
	if spec.heal then
		add(
			string.format(
				"Lays a healing patch every %g seconds: %g HP a second for %g seconds to anyone standing in it.",
				spec.every,
				spec.heal.perSecond,
				spec.heal.duration
			)
		)
	end
	if spec.haste then
		add(
			string.format(
				"Every %g attacks, gives you %s attack speed for %g seconds.",
				spec.haste.every,
				percent(spec.haste.bonus * 100),
				spec.haste.duration
			)
		)
	end
	if spec.healPerHit then
		add(string.format("Heals you %g HP for every enemy it hits.", spec.healPerHit))
	end
	if spec.revive then
		add(
			string.format(
				"Once a run, saves you from a killing blow and brings you back on %s of your health.",
				percent(spec.revive * 100)
			)
		)
	end
	if spec.magnet then
		add("Pulls the room's XP crystals to you.")
	end
	--[[ Drowned Village (docs/PETS-DROWNED.md). Each says what it does
	     *not* do as well, because all four of these are easy to read as
	     something stronger than they are: a cut is not a shield, ink is
	     not a stun, foam on something standing still is nothing, and a
	     canopy adds no damage at all. ]]
	local shelter = spec.shelter
	if shelter then
		add(
			string.format(
				"Roof Huddle: every %g seconds it tucks in beside you for %g seconds, and you take %s less from everything. Hits still land -- nothing is blocked. About %s less damage over a fight.",
				spec.every,
				shelter.duration,
				percent(shelter.reduction * 100),
				percent(Shelter.averageCut(shelter, spec.every) * 100)
			)
		)
	end
	local payback = spec.payback
	if payback and spec.damage then
		add(
			string.format(
				"Payback Puff: it does nothing until you are hurt. Then it fires one spine for %g damage, %gx its usual, and no more often than every %g seconds.",
				spec.damage * payback.scale,
				payback.scale,
				spec.every
			)
		)
	end
	local blind = spec.blind
	if blind then
		add(
			string.format(
				"Ink Blink: every %g seconds it inks one enemy's face. For %g seconds it cannot pick a target more than %g studs away, so anything shooting from range stops. It still moves, and still swings up close. No damage, and bosses see through it.",
				spec.every,
				blind.duration,
				blind.range
			)
		)
	end
	local wake = spec.wake
	if wake then
		add(
			string.format(
				"Wake Chase: every %g seconds it splashes foam on one enemy for %g seconds. Every %g studs that enemy walks costs it %g, up to %g times -- %g in all if it keeps running. An enemy that stands still takes nothing.",
				spec.every,
				wake.duration,
				wake.perStud,
				wake.damage,
				wake.hits,
				PetWake.total(wake)
			)
		)
	end
	local accord = spec.accord
	if accord then
		add(
			string.format(
				"Deep Accord: every %g seconds it joins up to %g enemies under a canopy for %g seconds. Damage you deal to one is split evenly between them, so one shot chips them all. It adds no damage of its own -- the total is exactly what you dealt.",
				spec.every,
				accord.targets,
				accord.duration
			)
		)
	end

	return out
end

--[[ The same, as one block of text for a detail card. ]]
function PetBlurb.text(key: string): string
	local lines = PetBlurb.lines(key)
	if #lines == 0 then
		return PetBlurb.NONE
	end
	return table.concat(lines, "\n\n")
end

return PetBlurb
