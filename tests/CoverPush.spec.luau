--!strict
--[[
	`Util/CoverPush`: a drawn slime's body is kept out of cover the way the
	server keeps its hitbox out (`rg-cover`, 2026-11-26).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoverPush = require(ReplicatedStorage.Shared.Util.CoverPush)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local log: CoverPush.Box = { centre = Vector2.new(0, 0), half = Vector2.new(1, 3) }

	t.test("a body clear of cover is left where it is", function()
		local at = Vector2.new(3, 0)
		local out = CoverPush.out(at, Vector2.new(1.5, 1.5), { log })
		t.near((out - at).Magnitude, 0, 1e-5)
	end)

	t.test("a body reaching into cover is pushed the shortest way out, just touching", function()
		local out = CoverPush.out(Vector2.new(2, 0.5), Vector2.new(1.5, 1.5), { log })
		t.near(out.X, 2.5, 1e-5)
		t.near(out.Y, 0.5, 1e-5)
		local below = CoverPush.out(Vector2.new(0.2, -4), Vector2.new(1.5, 1.5), { log })
		t.near(below.X, 0.2, 1e-5)
		t.near(below.Y, -4.5, 1e-5)
	end)

	t.test("a turned footprint reaches as far as its corners", function()
		local square = CoverPush.turned(Vector2.new(1, 1), math.pi / 4)
		t.near(square.X, math.sqrt(2), 1e-5)
		t.near(square.Y, math.sqrt(2), 1e-5)
		local quarter = CoverPush.turned(Vector2.new(2, 1), math.pi / 2)
		t.near(quarter.X, 1, 1e-5)
		t.near(quarter.Y, 2, 1e-5)
	end)
end
