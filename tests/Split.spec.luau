--!strict
--[[
	Enemies that split when they die (`EnemyConfig.split`, `Balance.Split`).
	Relationships only: what a split may become, and that its pieces land
	clear of the body they came out of.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local TestRunner = require(script.Parent.TestRunner)

local function radius(config: Balance.EnemyConfig): number
	return math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
end

--[[ The clip `name` of the model an archetype is drawn with, if it plays its own. ]]
local function clipOf(config: Balance.EnemyConfig, name: string): ModelClip.Clip?
	local design = EnemyDesigns.Imported[config.displayName]
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
	local module = if design and folder then folder:FindFirstChild(design.clips) else nil
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local data = (require :: any)(module) :: ModelClip.Model
	return data.clips[name]
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
				t.isTrue(
					split.health > 0 and split.health <= 1,
					`{config.displayName}'s pieces have {split.health} of their health`
				)
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

	--[[ A clip named in a split that its model lacks would fall back to
	     Death and the jelly without a word. ]]
	t.test("a split's clips are its models' own, and a piece's lasts its throw", function()
		local throw = Balance.Split.flight + Balance.Split.settle
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			local split = config.split
			if split and split.clip then
				t.isTrue(
					clipOf(config, split.clip) ~= nil,
					`{config.displayName} has no {split.clip} clip`
				)
			end
			if split and split.pieceClip then
				local clip = clipOf(split.into, split.pieceClip)
				t.isTrue(clip ~= nil, `{split.into.displayName} has no {split.pieceClip} clip`)
				if clip then
					t.isTrue(
						not clip.loops,
						`{split.pieceClip} loops, so it would not end standing`
					)
					t.near(clip.length, throw, 0.1, `{split.pieceClip} does not last the throw`)
				end
			end
		end
	end)

	t.test("a piece is in the air before it lands", function()
		t.isTrue(Balance.Split.flight > 0, "pieces arrive with no flight")
		t.isTrue(Balance.Split.settle >= 0, "a negative settle")
		t.isTrue(Balance.Split.arcHeight > 0, "pieces fly flat")
	end)
end
