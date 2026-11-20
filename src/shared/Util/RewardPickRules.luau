--!strict
--[[
	Reward picks (owner, 2026-11-19: "make sure that the player has a choice
	BETWEEN THE MYTHICS AND LEGENDARIES FOR ALL CLASSES for the endless
	rewards and the battlepass", "the space and sakura ones"). A reward that
	gives a themed set's weapon gives a pick of that set's four, one for each
	class, and the player takes the one they want:

	- Endless room 100: the Voidglass set (`Balance.Endless.milestones`
	  `pick`): the Nebula Blade, a Mythic, or the Orbit Bow, Starwell Staff
	  or Comet Daggers, Legendaries.
	- Season 1's premium tier 30: the Lantern Bloom set (`Config/Season`
	  `picks`): the Petalfall Blade, a Mythic, or the Blossom Bow, Paperglow
	  Staff or Bellchime Daggers.

	A pick owed is saved by the reward's id, holding the set's key
	(`SaveSchema` v29 `rewardPicks`), until it is taken: on the lobby's pick
	panel (`UI/RewardPick`), which comes up again on every return to the
	lobby while one is owed. The client sends only the weapon
	(`Remotes.RewardPick`); the server takes the pick it belongs to (`find`),
	so nothing outside an owed set can be had. A weapon held once
	(`ShopRules.merges` false: the earned blades) that is held already
	cannot be picked; one that merges is picked as another copy.

	Pure: `tests/RewardPicks.spec` runs it.
]]

local ClassList = require(script.Parent.ClassList)
local ShopRules = require(script.Parent.ShopRules)

local RewardPickRules = {}

local RARITY = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

--[[ The id of Endless milestone `floor`'s pick: "Endless:100". ]]
function RewardPickRules.endlessId(floor: number): string
	return `Endless:{math.floor(floor)}`
end

--[[ The id of season `number`'s pick on `track`: "Season:1:premium". ]]
function RewardPickRules.seasonId(number: number, track: string): string
	return `Season:{math.floor(number)}:{track}`
end

--[[ What gave the pick `id`, in the panel's words: "ENDLESS ROOM 100",
     "SEASON 1 PREMIUM PASS". ]]
function RewardPickRules.from(id: string): string
	local floor = string.match(id, "^Endless:(%d+)$")
	if floor then
		return `ENDLESS ROOM {floor}`
	end
	local number, track = string.match(id, "^Season:(%d+):(%a+)$")
	if number then
		return if track == "premium" then `SEASON {number} PREMIUM PASS` else `SEASON {number} PASS`
	end
	return "A REWARD"
end

--[[ Where class `class` stands in the class list, for the panel's order. ]]
local function classOrder(class: string): number
	return table.find(ClassList.open(), class) or math.huge
end

--[[ Set `set`'s weapons, one for each open class, in the class list's
     order (Ranger, Arcanist, Warden, Assassin). ]]
function RewardPickRules.options(set: string): { ShopRules.Entry }
	local out = ShopRules.setPool(set)
	table.sort(out, function(a, b)
		local ca, cb = classOrder(a.class), classOrder(b.class)
		if ca ~= cb then
			return ca < cb
		end
		return a.weapon < b.weapon
	end)
	return out
end

--[[ Whether `weapon` can be taken by a player holding `owned`: not held,
     or one that merges (another copy). ]]
function RewardPickRules.canTake(weapon: string, owned: { [string]: boolean }): boolean
	return not owned[weapon] or ShopRules.merges(weapon)
end

--[[ The weapons of `set` a player holding `owned` can take. ]]
function RewardPickRules.pickable(set: string, owned: { [string]: boolean }): { string }
	local out: { string } = {}
	for _, entry in RewardPickRules.options(set) do
		if RewardPickRules.canTake(entry.weapon, owned) then
			table.insert(out, entry.weapon)
		end
	end
	return out
end

--[[ The picks' ids in a fixed order, so every screen and the server
     agree which comes first. ]]
local function ids(picks: { [string]: string }): { string }
	local out: { string } = {}
	for id in picks do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

--[[ The first owed pick whose set holds `weapon` and lets it be taken,
     nil for none: the server's check of what a client asks for. ]]
function RewardPickRules.find(
	picks: { [string]: string },
	weapon: string,
	owned: { [string]: boolean }
): string?
	for _, id in ids(picks) do
		if table.find(RewardPickRules.pickable(picks[id], owned), weapon) then
			return id
		end
	end
	return nil
end

--[[ The first owed pick not in `skip`, as its id and set, nil for none:
     the one the panel shows. ]]
function RewardPickRules.next(
	picks: { [string]: string },
	skip: { [string]: boolean }?
): (string?, string?)
	for _, id in ids(picks) do
		if not (skip and skip[id]) then
			return id, picks[id]
		end
	end
	return nil, nil
end

--[[ The set's star, for a picture that stands for the whole pick: its
     rarest weapon, the first in class order of those. ]]
function RewardPickRules.headline(set: string): string?
	local best: ShopRules.Entry? = nil
	for _, entry in RewardPickRules.options(set) do
		if not best or (RARITY[entry.rarity] or 0) > (RARITY[best.rarity] or 0) then
			best = entry
		end
	end
	return if best then best.weapon else nil
end

return RewardPickRules
