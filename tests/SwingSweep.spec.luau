--!strict
--[[
	The red of a melee swing is drawn on its hitbox (`Shared/Combat/
	SwingSweep`, owner 2026-10-23): over a swing the ribbon's ends must stay
	inside the shape `SwingBox` hits, and sweep all of it, so what is
	painted is exactly that shape. The shapes are built the way
	`MeleeSystem` builds them, cards included.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local SwingSweep = require(ReplicatedStorage.Shared.Combat.SwingSweep)
local TestRunner = require(script.Parent.TestRunner)

local swing = Classes.Warden.swing :: Classes.Swing
local BLOWS = #swing.damage
local ORIGIN = Vector3.zero
local FORWARD = Vector3.new(0, 0, -1)
local STEPS = 24

--[[ Every blow's shape, with and without the size cards at their highest. ]]
local function shapes(): { { blow: number, shape: SwingBox.Shape } }
	local out = {}
	for _, counts in { {}, { Cleave = 3, LongReach = 3 } } do
		local stats = AbilityEffects.clientStats(counts, "Warden")
		for blow = 1, BLOWS do
			table.insert(out, {
				blow = blow,
				shape = SwingBox.shape(swing, blow, BLOWS, stats.widthScale, stats.reachBonus),
			})
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("the swing's red never leaves its hitbox", function()
		for _, entry in shapes() do
			local sweep: SwingSweep.Sweep =
				SwingSweep.forBlow(entry.blow, BLOWS) :: SwingSweep.Sweep
			for step = 0, STEPS do
				local a, b = SwingSweep.edge(entry.shape, sweep, step / STEPS)
				-- A hair inside, so a point exactly on the edge counts.
				local inA = a:Lerp(b, 0.001)
				local inB = b:Lerp(a, 0.001)
				--[[ A thousandth of a stud of width, so a point exactly on
				     the arc's edge is not lost to rounding. ]]
				t.isTrue(
					SwingBox.hits(entry.shape, ORIGIN, FORWARD, inA, 1e-3),
					"a ribbon end strays out"
				)
				t.isTrue(
					SwingBox.hits(entry.shape, ORIGIN, FORWARD, inB, 1e-3),
					"a ribbon end strays out"
				)
			end
		end
	end)

	--[[ The blade's tip runs the arc's full reach across its whole angle,
	     or right round the slam's circle at its edge, so the slash traces
	     the blow's whole shape. ]]
	t.test("the swing's tip traces the whole hitbox", function()
		for _, entry in shapes() do
			local shape = entry.shape
			local sweep: SwingSweep.Sweep =
				SwingSweep.forBlow(entry.blow, BLOWS) :: SwingSweep.Sweep
			local a0, b0 = SwingSweep.edge(shape, sweep, 0)
			local a1, b1 = SwingSweep.edge(shape, sweep, 1)
			if shape.kind == "Arc" then
				-- Vector3 is single precision: about 1e-6 of a 15-stud reach
				t.near(b0.Magnitude, shape.reach, 1e-5)
				t.near((b0 - a0).Magnitude, shape.reach * (1 - SwingSweep.INNER), 1e-5)
				local turned = math.deg(math.acos(math.clamp(b0.Unit:Dot(b1.Unit), -1, 1)))
				t.near(turned, math.min(shape.arc, 360 - shape.arc), 1e-3)
			else
				local centre = Vector3.new(0, 0, -shape.ahead)
				t.near((b0 - centre).Magnitude, shape.radius, 1e-5)
				t.near((b0 - a0).Magnitude, shape.radius * (1 - SwingSweep.INNER), 1e-5)
				t.near((b0 - b1).Magnitude, 0, 1e-5)
				local _, half = SwingSweep.edge(shape, sweep, 0.5)
				t.near((half - centre).Magnitude, shape.radius, 1e-5)
				t.isTrue((a1 - centre).Magnitude < shape.radius, "the streak leaves the circle")
			end
		end
	end)

	t.test("the side blows sweep opposite ways, and the slam spins", function()
		t.equal(SwingSweep.forBlow(BLOWS, BLOWS), "Spin")
		t.isTrue(
			SwingSweep.forBlow(1, BLOWS) ~= SwingSweep.forBlow(2, BLOWS),
			"the side blows sweep the same way"
		)
	end)
end
