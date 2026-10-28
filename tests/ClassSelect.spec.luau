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
end
