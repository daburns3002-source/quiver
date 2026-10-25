--!strict
--[[
	Which `Config/Weapons` entry is in a player's hand: the class's own, or
	one the sandbox put there, unless a drafted card puts another there
	(`Ability.weapon`, the Dual Bows Mythic). A card's pair of bows is the
	pair of the bow already in hand, so a skin stays the skin (owner,
	2026-10-25); a bow with no pair of its own takes the card's.

	Shared and pure so `tests/HeldWeaponChoice.spec` can pin it;
	`Run/RunSession.applyLoadout` records the answer as the player's
	`Weapon` attribute.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local HeldWeaponChoice = {}

--[[ The pair of `single` (an entry whose `dualOf` is it), or nil. ]]
function HeldWeaponChoice.dualOf(single: string): string?
	for name, weapon in Weapons :: any do
		if (weapon :: Weapons.Weapon).dualOf == single then
			return name
		end
	end
	return nil
end

--[[ The weapon held: `inHand` (the class's or the sandbox's), or the
     `cardWeapon` a drafted card puts there, as the pair of `inHand` when
     the card's weapon is a pair and `inHand` has one. ]]
function HeldWeaponChoice.pick(inHand: string, cardWeapon: string?): string
	if not cardWeapon then
		return inHand
	end
	local card = (Weapons :: any)[cardWeapon] :: Weapons.Weapon?
	if card and card.dualOf then
		local held = (Weapons :: any)[inHand] :: Weapons.Weapon?
		if held and held.dualOf then
			-- already a pair (the sandbox's)
			return inHand
		end
		return HeldWeaponChoice.dualOf(inHand) or cardWeapon
	end
	return cardWeapon
end

return HeldWeaponChoice
