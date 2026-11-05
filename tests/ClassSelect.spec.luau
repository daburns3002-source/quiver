--!strict
--[[ Approved class order, lock ownership and slanted panel hit testing. ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = require(ReplicatedStorage.Shared.Config.ClassSelectAssets)
local Hit = require(ReplicatedStorage.Shared.Util.ClassSelectHit)
local TestRunner = require(script.Parent.TestRunner)
return function(t: TestRunner.Helper)
	t.test("eight sections pair two looks in class order; only Assassin is locked", function()
		t.equal(#Assets.sections, 8)
		for i, class in { "Ranger", "Arcanist", "Warden", "Assassin" } do
			for j, look in { "male", "female" } do
				local section = Assets.sections[(i - 1) * 2 + j]
				t.equal(section.class, class)
				t.equal(section.look, look)
				t.equal(section.locked, class == "Assassin")
			end
		end
	end)
	t.test("slanted hit test owns every section centre and follows its slope", function()
		local borders = { 87, 313, 538, 768, 993, 1221, 1460, 1686, 1914 }
		for i = 1, 8 do
			local x = (borders[i] + borders[i + 1]) / 2
			t.equal(Hit.section(x, 300), i)
			t.equal(Hit.section(x - 0.245 * 100, 400), i)
		end
		t.equal(Hit.section(-1, 300), nil)
		t.equal(Hit.section(960, 1081), nil)
	end)
	--[[ The upright screen (owner, 2026-11-05: "make the character select
	     screen the classes on top of eachother"): a band per class in
	     order, male on the left, and its tiles within what Roblox keeps. ]]
	t.test("upright hit test: a band per class, male left and female right", function()
		local upright = Assets.portrait
		t.equal(#upright.bands, 4)
		for band, edges in upright.bands do
			local y = (edges.top + edges.bottom) / 2
			t.equal(Hit.upright(upright, upright.split / 2, y), (band - 1) * 2 + 1)
			t.equal(Hit.upright(upright, (upright.split + upright.size.X) / 2, y), band * 2)
		end
		t.equal(Hit.upright(upright, 540, upright.bands[1].top - 1), nil)
		t.equal(Hit.upright(upright, 540, upright.choose), nil)
	end)
	t.test("upright picture is tiled within the upload limit", function()
		local upright = Assets.portrait
		local rows = math.ceil(#upright.tiles / upright.columns)
		t.isTrue(
			upright.size.X / upright.columns + 2 * upright.overlap <= 1024
				and upright.size.Y / rows + 2 * upright.overlap <= 1024,
			"the upright class picture's tiles are larger than Roblox keeps"
		)
	end)
end
