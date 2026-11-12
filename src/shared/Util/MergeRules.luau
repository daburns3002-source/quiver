--!strict
--[[
	Merge tiers (owner, 2026-10-28: "the player has to get 3 of 1 tier and
	then they can merge into the next tier. starting at C going to B, then
	A, then S"), pure, so the server, the gear screen and `tests/Merge.spec`
	agree. A weapon or pet is held as copies at each tier; every copy from a
	crate or an egg is a C; three at one tier merge into one of the next.
	S is the top.

	The copy held in runs is the best tier owned, and each step multiplies
	the one before (owner, 2026-10-28: "B tier should raise damage by 1.2x
	over C, A should raise damage 1.2x over B, S tier should raise damage
	1.5x over A"), for a weapon's damage and a pet's alike:
	C x1.00, B x1.20, A x1.44, S x2.16.
]]

local MergeRules = {}

export type Counts = { [string]: number }

MergeRules.TIERS = { "C", "B", "A", "S" }

--[[ Copies of one tier merged into one of the next. ]]
MergeRules.COST = 3

--[[ Each tier's step over the one before it. ]]
local STEP = { B = 1.2, A = 1.2, S = 1.5 }
local SCALE = { C = 1, B = STEP.B, A = STEP.B * STEP.A, S = STEP.B * STEP.A * STEP.S }
MergeRules.weaponScale = SCALE :: { [string]: number }
MergeRules.petScale = SCALE :: { [string]: number }

--[[ The tier a merge of `tier` makes, nil for S or no tier. ]]
function MergeRules.nextTier(tier: string): string?
	local index = table.find(MergeRules.TIERS, tier)
	return if index then MergeRules.TIERS[index + 1] else nil
end

function MergeRules.canMerge(counts: Counts?, tier: string): boolean
	return counts ~= nil
		and MergeRules.nextTier(tier) ~= nil
		and (counts[tier] or 0) >= MergeRules.COST
end

--[[ Merges three of `tier` into one of the next, in place; false (and
     nothing changed) when it cannot. ]]
function MergeRules.merge(counts: Counts, tier: string): boolean
	local up = MergeRules.nextTier(tier)
	if not up or not MergeRules.canMerge(counts, tier) then
		return false
	end
	local left = (counts[tier] or 0) - MergeRules.COST
	local open = counts :: { [string]: number? }
	open[tier] = if left > 0 then left else nil
	counts[up] = (counts[up] or 0) + 1
	return true
end

--[[ The best tier with a copy, nil for none. ]]
function MergeRules.best(counts: Counts?): string?
	if not counts then
		return nil
	end
	for index = #MergeRules.TIERS, 1, -1 do
		local tier = MergeRules.TIERS[index]
		if (counts[tier] or 0) > 0 then
			return tier
		end
	end
	return nil
end

--[[ Every copy, any tier. ]]
function MergeRules.total(counts: Counts?): number
	local n = 0
	for _, tier in MergeRules.TIERS do
		n += if counts then counts[tier] or 0 else 0
	end
	return n
end

--[[ Valid tier counts from anything stored: whole, positive, known tiers. ]]
function MergeRules.clean(value: unknown): Counts
	local out = {}
	if type(value) == "table" then
		for _, tier in MergeRules.TIERS do
			local n = (value :: any)[tier]
			if type(n) == "number" and n == n and n >= 1 then
				out[tier] = math.floor(n)
			end
		end
	end
	return out
end

return MergeRules
