--!strict
--[[
	Every pet moves as itself (`Config/PetGaits`; owner, 2026-11-08: "make
	sure the pet animations all feel unique to each other"). What is pinned
	is the shape of each motion: a gait that differs from another only in its
	numbers is the thing this exists to stop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetGait = require(ReplicatedStorage.Shared.Util.PetGait)
local PetGaits = require(ReplicatedStorage.Shared.Config.PetGaits)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local TestRunner = require(script.Parent.TestRunner)

local function shape(layers: { PetGaits.Layer }): string
	local parts = {}
	for _, layer in layers do
		table.insert(parts, `{layer.axis}:{layer.wave}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function signature(gait: PetGaits.Gait): string
	local float = if gait.float then "air" else "floor"
	return `{gait.pace.kind}|{float}|{shape(gait.moving)}|{shape(gait.idle)}`
end

local function clipsOf(key: string): any
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
	return (require :: any)((folder :: Instance):FindFirstChild(key))
end

return function(t: TestRunner.Helper)
	t.test("every pet has a gait and every gait a pet", function()
		for key in Pets do
			t.notNil(PetGaits[key], `{key} has no gait`)
		end
		for key in PetGaits do
			t.notNil(Pets[key], `{key} is no pet`)
		end
	end)

	t.test("no two pets move in the same shape", function()
		local seen: { [string]: string } = {}
		for key, gait in PetGaits do
			local mark = signature(gait)
			t.isNil(seen[mark], `{key} moves just as {seen[mark] or "?"} does ({mark})`)
			seen[mark] = key
		end
	end)

	t.test("every clip a gait names is one the pet has", function()
		for key, gait in PetGaits do
			local data = clipsOf(key)
			for _, name in { gait.idleClip, gait.moveClip, gait.fidget } do
				t.notNil(data.clips[name], `{key}: no clip called {name}`)
			end
		end
	end)

	t.test("every pet has a clip of its own to move in", function()
		for key, gait in PetGaits do
			local data = clipsOf(key)
			local has = gait.moveClip ~= nil
			for _, name in { "Follow", "Walk", "Trot", "Waddle", "Hop" } do
				has = has or data.clips[name] ~= nil
			end
			t.isTrue(has, `{key} slides on its idle`)
		end
	end)

	t.test("a stepping pet stands still between its steps and lands at its reach", function()
		local pace: PetGaits.Pace = { kind = "Steps", period = 1, from = 0, to = 0.5, reach = 3 }
		local state = PetGait.new(Vector3.zero, Vector3.new(0, 0, -1))
		local goal = Vector3.new(0, 0, -30)
		for _ = 1, 31 do
			PetGait.advance(state, pace, goal, 1 / 60)
		end
		local landed = state.at
		t.isTrue(math.abs(landed.Magnitude - 3) < 0.05, `landed {landed.Magnitude} studs on`)
		for _ = 1, 25 do
			PetGait.advance(state, pace, goal, 1 / 60)
		end
		t.isTrue((state.at - landed).Magnitude < 1e-3, "it moved in the still part of the beat")
	end)

	t.test("a creeping pet keeps its pace and its leash", function()
		local pace: PetGaits.Pace = { kind = "Creep", speed = 4, leash = 10 }
		local state = PetGait.new(Vector3.zero, Vector3.new(0, 0, -1))
		PetGait.advance(state, pace, Vector3.new(0, 0, -5), 0.5)
		t.isTrue(math.abs(state.at.Magnitude - 2) < 0.01, "goes at its one speed")
		PetGait.advance(state, pace, Vector3.new(0, 0, -30), 1 / 60)
		local behind = (Vector3.new(0, 0, -30) - state.at).Magnitude
		t.isTrue(math.abs(behind - 10) < 0.1, `held {behind} studs behind`)
	end)

	t.test("a pet left in another room appears at its place", function()
		local state = PetGait.new(Vector3.zero, Vector3.new(0, 0, -1))
		PetGait.advance(state, { kind = "Chase", rate = 6 }, Vector3.new(0, 0, -200), 1 / 60)
		t.isTrue(state.at == Vector3.new(0, 0, -200), "snapped to its place")
	end)
end
