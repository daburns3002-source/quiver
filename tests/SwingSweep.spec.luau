--!strict
--[[
	The red of a melee swing is drawn on its hitbox (`Shared/Combat/
	SwingSweep`, owner 2026-10-23): over a swing the ribbon's ends must stay
	inside the box `SwingBox` checks, start on one of its edges and finish
	on the opposite one, so what is painted is exactly that box. The box is
	built the way `MeleeSystem` builds it, cards included.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SwingSweep = require(ReplicatedStorage.Shared.Combat.SwingSweep)
local TestRunner = require(script.Parent.TestRunner)

local EPSILON = 1e-6

local LEFT_TO_RIGHT: SwingSweep.Sweep = "LeftToRight"
local RIGHT_TO_LEFT: SwingSweep.Sweep = "RightToLeft"
local OUTWARD: SwingSweep.Sweep = "Outward"
local SWEEPS: { SwingSweep.Sweep } = { LEFT_TO_RIGHT, RIGHT_TO_LEFT, OUTWARD }
local SIDEWAYS: { SwingSweep.Sweep } = { LEFT_TO_RIGHT, RIGHT_TO_LEFT }

--[[ The Warden's box, with and without his size cards at their highest. ]]
local function boxes(): { { width: number, depth: number } }
	local swing = Classes.Warden.swing :: any
	local out = {}
	for _, counts in { {}, { Cleave = 3, LongReach = 3 } } do
		local stats = AbilityEffects.clientStats(counts, "Warden")
		table.insert(
			out,
			{ width = swing.width * stats.widthScale, depth = swing.depth + stats.reachBonus }
		)
	end
	return out
end

local function inside(point: Vector3, width: number, depth: number): boolean
	return math.abs(point.X) <= width / 2 + EPSILON
		and point.Z <= EPSILON
		and point.Z >= -depth - EPSILON
end

return function(t: TestRunner.Helper)
	t.test("the swing's red never leaves its hitbox", function()
		for _, box in boxes() do
			for _, sweep in SWEEPS do
				for step = 0, 20 do
					local a, b =
						SwingSweep.edge(box.width, box.depth, sweep :: SwingSweep.Sweep, step / 20)
					t.isTrue(
						inside(a, box.width, box.depth),
						"the sweep strays out at " .. step / 20
					)
					t.isTrue(
						inside(b, box.width, box.depth),
						"the sweep strays out at " .. step / 20
					)
				end
			end
		end
	end)

	--[[ Start on one edge, finish on the opposite one, spanning the box the
	     other way the whole time: the swept ribbon is the whole box. ]]
	t.test("the swing's red covers the whole hitbox", function()
		for _, box in boxes() do
			for _, sweep in SIDEWAYS do
				local a0, b0 = SwingSweep.edge(box.width, box.depth, sweep :: SwingSweep.Sweep, 0)
				local a1 = SwingSweep.edge(box.width, box.depth, sweep :: SwingSweep.Sweep, 1)
				t.near(math.abs(a1.X - a0.X), box.width, EPSILON)
				t.near((a0 - b0).Magnitude, box.depth, EPSILON)
			end
			local a0, b0 = SwingSweep.edge(box.width, box.depth, OUTWARD, 0)
			local a1 = SwingSweep.edge(box.width, box.depth, OUTWARD, 1)
			t.near(math.abs(a1.Z - a0.Z), box.depth, EPSILON)
			t.near((a0 - b0).Magnitude, box.width, EPSILON)
		end
	end)

	t.test("Cleave and Long Reach grow the red with the hitbox", function()
		local plain, carded = table.unpack(boxes())
		t.isTrue(carded.width > plain.width, "Cleave does not widen it")
		t.isTrue(carded.depth > plain.depth, "Long Reach does not lengthen it")
	end)

	t.test("the combo's last blow sweeps outward, the others side to side", function()
		t.equal(SwingSweep.forBlow(3, 3), "Outward")
		t.isTrue(
			SwingSweep.forBlow(1, 3) ~= SwingSweep.forBlow(2, 3),
			"the side blows sweep the same way"
		)
	end)
end
