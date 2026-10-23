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

--[[ Seconds after a combo's last attack ends before the next one starts
     the combo over. ]]
WeaponTiming.COMBO_RESET = 0.6

local function weaponOf(name: string): Weapons.Weapon
	return (Weapons :: any)[name] :: Weapons.Weapon
end

--[[ How much faster than written the `fire` clip numbered `index` in the
     combo, and the `ready` after it, play to fit inside `cooldown`. Never
     slower than written. ]]
function WeaponTiming.cycleSpeed(weaponName: string, index: number, cooldown: number): number
	local weapon = weaponOf(weaponName)
	local clips = WeaponAnimations[weaponName]
	local fire = clips[weapon.clips.fire[index]]
	local ready = if weapon.clips.ready then clips[weapon.clips.ready] else nil
	local natural = fire.length + (if ready then ready.length else 0)
	return math.max(1, natural / (cooldown * WeaponTiming.CYCLE_SHARE))
end

--[[ Seconds from the start of attack `index` to its blow landing: the
     clip's `Hit` marker at the speed it plays. 0 for a clip without one. ]]
function WeaponTiming.hitDelay(weaponName: string, index: number, cooldown: number): number
	local weapon = weaponOf(weaponName)
	local clip = WeaponAnimations[weaponName][weapon.clips.fire[index]]
	local hit = clip.markers.Hit
	if not hit then
		return 0
	end
	return hit / WeaponTiming.cycleSpeed(weaponName, index, cooldown)
end

--[[ The combo's next attack after `index` (0 for none yet), and whether the
     pause since the last one has reset it. ]]
function WeaponTiming.nextInCombo(weaponName: string, index: number, sinceLast: number): number
	local count = #weaponOf(weaponName).clips.fire
	if index == 0 or sinceLast > WeaponTiming.COMBO_RESET then
		return 1
	end
	return index % count + 1
end

return WeaponTiming
