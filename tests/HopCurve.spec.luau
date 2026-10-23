--!strict
--[[
	The slimes' hop (`Shared/Util/HopCurve`, `Balance.SlimeHop`, the owner's
	design_handoff_slime_movement): a hop must start and end at rest, so
	one hop runs into the next and a slime that stops is whole; it must
	never jump, or the body pops; and the body must stay near its hitbox,
	or what is drawn is not what is hit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local HopCurve = require(ReplicatedStorage.Shared.Util.HopCurve)
local TestRunner = require(script.Parent.TestRunner)

local config = Balance.SlimeHop
local keys = config.keys :: { HopCurve.Key }
local STEPS = 400

return function(t: TestRunner.Helper)
	t.test("a hop starts and ends at rest", function()
		for _, f in { 0, 1 - 1e-9 } do
			local sample = HopCurve.sample(keys, f)
			t.near(sample.tall, 1, 1e-6)
			t.near(sample.wide, 1, 1e-6)
			t.near(sample.deep, 1, 1e-6)
			t.near(sample.tilt, 0, 1e-6)
			t.near(sample.lift, 0, 1e-6)
		end
		t.near(HopCurve.sample(keys, 0).ease, 0, 1e-6)
		t.near(HopCurve.sample(keys, 1 - 1e-9).ease, 1, 1e-6)
	end)

	t.test("a hop never jumps", function()
		local before = HopCurve.sample(keys, 0)
		for i = 1, STEPS - 1 do
			local now = HopCurve.sample(keys, i / STEPS)
			for _, field in { "tall", "wide", "deep", "tilt", "lift", "ease" } do
				local a = (before :: any)[field] :: number
				local b = (now :: any)[field] :: number
				t.isTrue(math.abs(b - a) < 0.05, "the hop's " .. field .. " jumps")
			end
			before = now
		end
	end)

	--[[ The body is drawn `hop × (ease − through)` ahead of its hitbox. ]]
	t.test("the body stays within a third of a hop of its hitbox", function()
		for i = 0, STEPS - 1 do
			local f = i / STEPS
			local sample = HopCurve.sample(keys, f)
			t.isTrue(math.abs(sample.ease - f) <= 0.34, "the body strays from its hitbox")
		end
	end)

	t.test("every slime that hops has a body", function()
		for name, kind in config.kinds :: { [string]: { hop: number, height: number } } do
			t.isTrue((EnemyDesigns :: any)[name] ~= nil, name .. " hops but has no design")
			t.isTrue(kind.hop > 0 and kind.height > 0, name .. "'s hop is empty")
		end
	end)
end
