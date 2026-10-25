--!strict
--[[
	The Glade Fox's Leaf Dash (`Shared/Util/PetDash`, `Config/PetCombat`
	GladeFox `dash`; owner, 2026-10-25: "glade fox needs to actually dash to
	the enemies when it attacks").

	What is pinned is what the owner asked for and what keeps it honest: the
	fox is beside each enemy when its blow lands (the server's damage and
	the client's fox read the same plan), it runs every route rather than
	blinking, it comes back to where it started, the dash is over before the
	next attack, and its Attack clip's own lunge plays over each run.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetDash = require(ReplicatedStorage.Shared.Util.PetDash)
local TestRunner = require(script.Parent.TestRunner)

local fox = PetCombat.pets.GladeFox
local dash = fox.dash :: PetDash.Dash

local START = Vector3.new(0, 0, 10)
local ENEMIES = { Vector3.new(6, 0, -8), Vector3.new(-10, 0, -20), Vector3.new(12, 0, -24) }
local GAP = 1.5 + dash.radius + dash.gap

--[[ A plan over open floor: straight routes, as `Pathing` gives with no
     cover between. ]]
local function openPlan(enemies: { Vector3 }): (PetDash.Plan, { Vector3 })
	local routes, lands = {}, {}
	local from = START
	for _, enemy in enemies do
		local land = PetDash.landing(from, enemy, GAP)
		table.insert(routes, { land })
		table.insert(lands, land)
		from = land
	end
	table.insert(routes, { START })
	return PetDash.plan(START, routes, enemies, dash), lands
end

return function(t: TestRunner.Helper)
	t.test("the fox dashes: a dash setting, up to three enemies", function()
		t.notNil(fox.dash, "GladeFox has a dash")
		t.equal(fox.targets, 3)
		t.isTrue((fox.damage or 0) > 0, "it does damage")
	end)

	t.test("it lands beside each enemy as the blow lands", function()
		local plan, lands = openPlan(ENEMIES)
		local hits = PetDash.hits(plan)
		t.equal(#hits, #ENEMIES)
		for i, at in hits do
			local place = PetDash.at(plan, at)
			t.near((place - lands[i]).Magnitude, 0, 0.01, `on its landing at enemy {i}'s blow`)
			t.near((lands[i] - ENEMIES[i]).Magnitude, GAP, 0.01, `beside enemy {i}, not in it`)
			local before = PetDash.at(plan, at - 0.1)
			t.isTrue((before - lands[i]).Magnitude > 0.1, `still running to enemy {i} just before`)
		end
	end)

	t.test("it runs each route, never blinks, and stays to slash", function()
		local plan = openPlan(ENEMIES)
		local last = PetDash.at(plan, 0)
		local fastest = 0
		local frame = 1 / 60
		for step = 1, math.ceil(plan.length / frame) do
			local place = PetDash.at(plan, step * frame)
			fastest = math.max(fastest, (place - last).Magnitude / frame)
			last = place
		end
		-- the ease starts at twice its average pace
		local farthest = 0
		local from = START
		for _, stop in plan.stops do
			local to = stop.route[#stop.route]
			farthest = math.max(farthest, (to - from).Magnitude / (stop.arrive - stop.leave))
			from = to
		end
		t.isTrue(fastest <= farthest * 2 + 1, `no jump between frames ({fastest} studs/s)`)
		for i, stop in plan.stops do
			t.isTrue(stop.arrive - stop.leave >= dash.shortest - 1e-6, `route {i} is a run`)
			if stop.aim then
				local next = plan.stops[i + 1]
				t.near(next.leave - stop.arrive, dash.slash, 1e-6, `it slashes at enemy {i}`)
			end
		end
		t.near(plan.stops[1].leave, dash.windup, 1e-6, "it crouches first")
	end)

	t.test("it comes home, and is back before its next attack", function()
		local plan = openPlan(ENEMIES)
		local home = PetDash.at(plan, plan.length + 1)
		t.near((home - START).Magnitude, 0, 0.01, "back where it started")
		-- three enemies as far apart as a room allows
		local far = { Vector3.new(15, 0, -25), Vector3.new(-15, 0, 25), Vector3.new(15, 0, 25) }
		local longest = openPlan(far)
		t.isTrue(longest.length < fox.every, `a dash of {longest.length}s is over before the next`)
	end)

	t.test("it follows its route round cover", function()
		local corner = Vector3.new(8, 0, 10)
		local land = Vector3.new(8, 0, 0)
		local plan = PetDash.plan(
			START,
			{ { corner, land }, { START } },
			{ Vector3.new(8, 0, -1.5) },
			dash
		)
		local stop = plan.stops[1]
		local midway = PetDash.at(plan, stop.leave + (stop.arrive - stop.leave) * 0.1)
		-- early on, still on the first leg along z = 10: it never cuts the corner
		t.near(midway.Z, 10, 0.01, "on the route's first leg, not the straight line")
	end)

	t.test("its Attack clip lunges over each run and holds the slash", function()
		local plan = openPlan(ENEMIES)
		local clip = dash.clip
		t.near(PetDash.clipTime(plan, 0, clip), 0, 1e-6, "the crouch starts the clip")
		local first = plan.stops[1]
		t.near(
			PetDash.clipTime(plan, first.leave, clip),
			clip.out,
			1e-6,
			"the lunge leaves with it"
		)
		t.near(PetDash.clipTime(plan, first.arrive, clip), clip.hit, 1e-6, "and lands with it")
		t.near(PetDash.clipTime(plan, plan.length, clip), clip.home, 1e-6, "home as it gets back")
		t.near(dash.windup, clip.out, 0.01, "the server's crouch is the clip's")

		-- the beats are where the fox's own clip lunges
		local data = (require :: any)(
				ReplicatedStorage.Shared.Config.ModelClips.GladeFox
			) :: ModelClip.Model
		local attack = data.clips[clip.name]
		t.notNil(attack, "the fox has its Attack clip")
		local function reach(time: number): number
			return ModelClip.pose(data, attack, time)[clip.root].t.Z
		end
		local rest = reach(0)
		t.isTrue(math.abs(reach(clip.out) - rest) < 0.05, "still home at the lunge's start")
		t.isTrue(reach(clip.hit) - rest > 0.5, "lunged forward by its landing")
		t.isTrue(reach(clip.back) - rest > 0.5, "still out when it turns back")
		t.isTrue(math.abs(reach(clip.home) - rest) < 0.05, "home again at its end")
		t.isTrue(clip.home <= attack.length, "the beats are inside the clip")
	end)
end
