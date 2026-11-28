--!strict
--[[
	The outer forests drawn as merged chunks (`Config/ForestChunks`,
	docs/PERFORMANCE.md option 2): every room of an area draws its own
	forest's chunks, a handful of meshes rather than one per tree, and the
	trees' crowns the scenery's life settles on are all still there, one
	for every crown in the forest's layout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local ForestChunks = require(ReplicatedStorage.Shared.Config.ForestChunks)
local TestRunner = require(script.Parent.TestRunner)

local LAYOUTS: { [string]: { ArenaModels.ArenaPart } } = {
	Glade = require(ReplicatedStorage.Shared.Config.GladeForest),
	Thornwood = require(ReplicatedStorage.Shared.Config.ThornwoodForest),
	Drowned = require(ReplicatedStorage.Shared.Config.DrownedForest),
	Bogheart = require(ReplicatedStorage.Shared.Config.BogheartForest),
	Windswept = require(ReplicatedStorage.Shared.Config.WindsweptForest),
}

-- A Roblox mesh holds 20,000 triangles; the most chunks a forest may take.
local MOST_CHUNKS = 16

return function(t: TestRunner.Helper)
	t.test("every room draws its own area's forest, merged where it has chunks", function()
		for name, model in ArenaModels :: { [string]: ArenaModels.ArenaModel } do
			local key = model.forest
			if key then
				local layout = LAYOUTS[key]
				t.isTrue(layout ~= nil, `{name}'s forest {key} has no layout`)
				local chunks = ForestChunks[key]
				t.isTrue(
					model.parts == (if chunks then chunks.parts else layout),
					`{name} does not draw {key}'s forest`
				)
			end
		end
	end)

	t.test("a forest's chunks are few, named once, and keep every crown", function()
		for key, forest in ForestChunks do
			local layout = LAYOUTS[key]
			t.isTrue(layout ~= nil, `{key}'s chunks have no layout`)
			t.isTrue(
				#forest.parts > 0 and #forest.parts <= MOST_CHUNKS,
				`{key} is drawn in {#forest.parts} chunks`
			)
			local seen: { [string]: boolean } = {}
			for _, part in forest.parts do
				t.isFalse(seen[part.name] == true, `{key} names {part.name} twice`)
				seen[part.name] = true
				t.isTrue(
					string.sub(part.meshId, 1, 13) == "rbxassetid://",
					`{part.name} has no mesh`
				)
				t.isTrue(part.glow ~= true or part.tint ~= nil, `{part.name} glows untinted`)
			end
			local crowns = 0
			for _, part in layout do
				if string.sub(part.name, 1, 10) == "CanopyMesh" then
					crowns += 1
				end
			end
			t.isTrue(#forest.crowns == crowns, `{key} keeps {#forest.crowns} of {crowns} crowns`)
		end
	end)
end
