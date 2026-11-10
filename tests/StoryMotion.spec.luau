--!strict
--[[
	How the story cutscene moves (`Config/StoryMotion`, `Util/StoryMotion`),
	ported from the owner's approved Claude Design animation.

	Its groups cover every frame once, in order, on both stages; the camera
	never shows past a frame's edge; it fades in from black and out to black;
	the roar flashes; every overlay block sits on whole pixels; and a frame
	not yet down never draws, the one before it staying up instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.StoryMotion)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local StoryMotion = require(ReplicatedStorage.Shared.Util.StoryMotion)
local TestRunner = require(script.Parent.TestRunner)

local holds = {}
for _, shot in Story.shots do
	for _, frame in shot.frames do
		table.insert(holds, frame.hold)
	end
end
local cues = StoryMotion.cues(holds)

local function always(_: number): boolean
	return true
end

return function(t: TestRunner.Helper)
	t.test("both stages' groups cover every frame once, in order", function()
		for _, layout in { Config.landscape, Config.portrait } do
			local expect = 1
			for _, group in layout.groups do
				for _, n in group.f do
					t.equal(n, expect)
					expect += 1
				end
			end
			t.equal(expect - 1, #holds, "every frame the story shows")
		end
	end)

	t.test("it runs the story's own length, so the sounds land as before", function()
		t.near(cues.black, 41.1, 1e-6)
	end)

	t.test("the camera never shows past a frame's edge", function()
		local scene = StoryMotion.newScene()
		for _, layout in { Config.landscape, Config.portrait } do
			local stage = layout.stage
			for step = 0, math.floor(cues.black * 20) do
				StoryMotion.draw(scene, layout, cues, step / 20, always)
				for i = 1, scene.count do
					local layer = scene.layers[i]
					t.isTrue(layer.tx <= 1e-6 and layer.ty <= 1e-6, "no gap at the top left")
					t.isTrue(
						layer.tx + Config.image.X * layer.s >= stage.X - 1e-3,
						"covers the right"
					)
					t.isTrue(
						layer.ty + Config.image.Y * layer.s >= stage.Y - 1e-3,
						"covers the bottom"
					)
				end
			end
		end
	end)

	t.test("it fades in from black and out to black, and the roar flashes", function()
		local scene = StoryMotion.newScene()
		StoryMotion.draw(scene, Config.landscape, cues, 0, always)
		t.near(scene.black, 1, 1e-6)
		StoryMotion.draw(scene, Config.landscape, cues, 2, always)
		t.near(scene.black, 0, 1e-6)
		StoryMotion.draw(scene, Config.landscape, cues, cues.black, always)
		t.near(scene.black, 1, 1e-6)
		StoryMotion.draw(scene, Config.landscape, cues, cues.starts[29] + 0.01, always)
		t.isTrue(scene.flash > 0.3)
	end)

	t.test("every overlay block sits on whole pixels, and there are not too many", function()
		local scene = StoryMotion.newScene()
		local most = 0
		for _, layout in { Config.landscape, Config.portrait } do
			for step = 0, math.floor(cues.black * 10) do
				StoryMotion.draw(scene, layout, cues, step / 10, always)
				local total = scene.screen.n
				for i = 1, scene.count do
					local r = scene.layers[i].rects
					total += r.n
					for b = 1, r.n do
						t.equal(r.x[b] % 1, 0)
						t.equal(r.y[b] % 1, 0)
					end
				end
				most = math.max(most, total)
			end
		end
		t.isTrue(most > 0, "overlays draw")
		t.isTrue(most < 2500, `{most} blocks at most`)
	end)

	t.test("a frame not yet down never draws; the one before it stays up", function()
		local scene = StoryMotion.newScene()
		local at = cues.starts[3] + 0.6
		StoryMotion.draw(scene, Config.landscape, cues, at, function(n)
			return n ~= 3
		end)
		local seen: { [number]: boolean } = {}
		for i = 1, scene.count do
			local layer = scene.layers[i]
			for f = 1, layer.count do
				seen[layer.frames[f]] = true
			end
		end
		t.isFalse(seen[3] == true)
		t.isTrue(seen[2] == true)
	end)
end
