--!strict
--[[
	The blocky end screens (2026-10-25) are laid out in their reference
	sheets' pixels (`Config/EndScreenLayout`). Moving one box must not push
	it off the panel or into its neighbour: every box stays on the panel,
	the rows and the rewards box sit inside the stats panel without
	overlapping, the button below it, and Defeat's progress bar on its
	third row. Every image they draw must be uploaded.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local EndScreenLayout = require(ReplicatedStorage.Shared.Config.EndScreenLayout)
local TestRunner = require(script.Parent.TestRunner)

type Box = { x: number, y: number, w: number, h: number }

local function inside(inner: Box, outer: Box): boolean
	return inner.x >= outer.x
		and inner.y >= outer.y
		and inner.x + inner.w <= outer.x + outer.w
		and inner.y + inner.h <= outer.y + outer.h
end

return function(t: TestRunner.Helper)
	for _, name in { "victory", "defeat" } do
		local layout: any = (EndScreenLayout :: any)[name]
		local panel: Box = layout.panel
		local stats: Box = layout.stats
		local rows = layout.rows
		local lastRow: Box = {
			x = rows.x,
			y = rows.y + 2 * rows.pitch,
			w = rows.w,
			h = rows.h,
		}

		t.test(`{name}: the panel's pieces stay on it, and it on the sheet`, function()
			local canvas = EndScreenLayout.canvas
			t.isTrue(
				inside(panel, { x = 0, y = 0, w = canvas.X, h = canvas.Y }),
				"panel off the sheet"
			)
			for _, key in { "ribbon", "sub", "hero", "tab", "stats", "rewards", "button" } do
				t.isTrue(inside(layout[key], panel), `{key} off the panel`)
			end
		end)

		t.test(`{name}: the rows, then the rewards, inside the stats panel`, function()
			t.isTrue(inside({ x = rows.x, y = rows.y, w = rows.w, h = rows.h }, stats), "first row")
			t.isTrue(inside(lastRow, stats), "third row")
			t.isTrue(inside(layout.rewards, stats), "rewards box")
			t.isTrue(
				layout.rewards.y >= lastRow.y + lastRow.h - 6,
				"the rewards box overlaps the rows"
			)
			for _, slot in layout.slots do
				t.isTrue(inside(slot, layout.rewards), "a reward slot off its box")
			end
			t.isTrue(layout.button.y >= stats.y + stats.h - 20, "the button overlaps the stats")
		end)

		if layout.bar then
			t.test(`{name}: the progress bar sits on the third row`, function()
				t.isTrue(inside(layout.bar, lastRow), "progress bar off its row")
			end)
		end
	end

	t.test("every end-screen image is uploaded", function()
		for key, id in EndScreenAssets :: any do
			t.isTrue(string.match(id, "^rbxassetid://%d+$") ~= nil, `{key} has no asset id`)
		end
	end)
end
