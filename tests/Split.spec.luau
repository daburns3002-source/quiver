--!strict
--[[
	Enemies that split when they die (`EnemyConfig.split`, `Balance.Split`).
	Relationships only: what a split may become, and that its pieces land
	clear of the body they came out of.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local function radius(config: Balance.EnemyConfig): number
	return math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
end

return function(t: TestRunner.Helper)
	t.test("at least one archetype splits", function()
		local found = false
		for _, value in Balance.Enemies do
			if (value :: Balance.EnemyConfig).split then
				found = true
			end
		end
		t.isTrue(found, "nothing splits, so the split path is dead")
	end)

	t.test("a split becomes known, smaller archetypes that do not split again", function()
		local known: { [Balance.EnemyConfig]: boolean } = {}
		for _, value in Balance.Enemies do
			known[value :: Balance.EnemyConfig] = true
		end

		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			local split = config.split
			if split then
				t.isTrue(
					known[split.into],
					`{config.displayName} splits into an unlisted archetype`
				)
				t.isTrue(split.count >= 1, `{config.displayName} splits into nothing`)
				t.isTrue(split.into.split == nil, `{config.displayName}'s pieces split again`)
				t.isTrue(
					radius(split.into) < radius(config),
					`{config.displayName} splits into something as big as itself`
				)
			end
		end
	end)

	--[[ A piece landing inside the body it left would read as the body
	     surviving, not splitting. ]]
	t.test("pieces land clear of the body they came out of", function()
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			local split = config.split
			if split then
				t.isTrue(
					Balance.Split.reach >= radius(config) + radius(split.into),
					`{config.displayName}'s pieces land inside it`
				)
			end
		end
	end)

	t.test("a piece is in the air before it lands", function()
		t.isTrue(Balance.Split.flight > 0, "pieces arrive with no flight")
		t.isTrue(Balance.Split.settle >= 0, "a negative settle")
		t.isTrue(Balance.Split.arcHeight > 0, "pieces fly flat")
	end)
end
