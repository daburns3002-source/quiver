--!strict
--[[
	How fast a weapon's attack clips play, and when in them a blow lands.

	Shared because two sides need the same answer: `Fx/WeaponPose` plays the
	clips on the client, and `Combat/MeleeSystem` lands a swing's damage on
	the server at the moment the drawn blade reaches its `Hit` marker. The
	clips are `Config/WeaponAnimations`; which plays when is
	`Config/Weapons.clips`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WeaponTiming = {}

--[[ The share of the attack cooldown that a `fire` clip and the `ready`
     after it may take, so the weapon is ready again before the next
     attack. ]]
WeaponTiming.CYCLE_SHARE = 0.9

local function weaponOf(name: string): Weapons.Weapon
	return (Weapons :: any)[name] :: Weapons.Weapon
end

--[[ The animations `weaponName` plays: its own, or its kit's (a skin plays
     its base weapon's until it has its own, `Config/Weapons.kit`). ]]
function WeaponTiming.clips(weaponName: string): any
	local weapon = weaponOf(weaponName)
	return WeaponAnimations[weapon and weapon.kit or weaponName]
end

--[[ How much faster than written the `fire` clip numbered `index` in the
     combo, and the `ready` after it, play to fit inside `cooldown`. Never
     slower than written. ]]
function WeaponTiming.cycleSpeed(weaponName: string, index: number, cooldown: number): number
	local weapon = weaponOf(weaponName)
	local clips = WeaponTiming.clips(weaponName)
	local fire = clips[weapon.clips.fire[index]]
	--[[ A weapon that goes back to aiming after a shot draws only once,
	     so its shots are only the fire clip. ]]
	local redraws = weapon.clips.ready ~= nil and weapon.clips.afterFire ~= "aim"
	local ready = if redraws then clips[weapon.clips.ready :: string] else nil
	local natural = fire.length + (if ready then ready.length else 0)
	return math.max(1, natural / (cooldown * WeaponTiming.CYCLE_SHARE))
end

--[[ Seconds from the start of attack `index` to its blow landing: the
     clip's `Hit` marker at the speed it plays. 0 for a clip without one. ]]
function WeaponTiming.hitDelay(weaponName: string, index: number, cooldown: number): number
	local weapon = weaponOf(weaponName)
	local clip = WeaponTiming.clips(weaponName)[weapon.clips.fire[index]]
	local hit = clip.markers.Hit
	if not hit then
		return 0
	end
	return hit / WeaponTiming.cycleSpeed(weaponName, index, cooldown)
end

--[[ The combo's next attack after `index` (0 for none yet). A combo keeps
     its place however long the wielder moves between attacks (owner,
     2026-10-23: "stand still, first attack, move around, second attack,
     move around, 3rd attack"); only a new run starts it over. ]]
function WeaponTiming.nextInCombo(weaponName: string, index: number): number
	local count = #weaponOf(weaponName).clips.fire
	return index % count + 1
end

return WeaponTiming
