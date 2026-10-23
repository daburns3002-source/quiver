--!strict
--[[
	Rigged enemies' animation (`Config/EnemyRigs`, `Shared/Util/RigClip`,
	the owner's design_handoff_ember_wilf). What is pinned: every clip
	drives only bones the rig has, at every key; a looping clip meets
	itself, so the run never hitches; and a dash is fitted to its lunge —
	crouched until the server launches it, in the air for exactly the
	bolt, and done after the skid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyRigs = require(ReplicatedStorage.Shared.Config.EnemyRigs)
local RigClip = require(ReplicatedStorage.Shared.Util.RigClip)
local TestRunner = require(script.Parent.TestRunner)

local function angleBetween(a: CFrame, b: CFrame): number
	local _, angle = (a:Inverse() * b):ToAxisAngle()
	return math.abs(angle)
end

return function(t: TestRunner.Helper)
	t.test("every clip drives the rig's own bones at every key", function()
		for rigName, rig in EnemyRigs do
			local names: { [string]: boolean } = {}
			for _, bone in rig.bones do
				names[bone.name] = true
				t.isTrue(
					bone.parent == "" or names[bone.parent] == true,
					rigName .. "'s bone " .. bone.name .. " comes before its parent"
				)
			end
			for clipName, clip in rig.clips do
				t.isTrue(#clip.times >= 2, clipName .. " has no keys")
				for i = 2, #clip.times do
					t.isTrue(
						clip.times[i] > clip.times[i - 1],
						clipName .. "'s keys are out of order"
					)
				end
				for bone, keys in clip.bones do
					t.isTrue(
						names[bone] == true,
						clipName .. " drives a bone the rig lacks: " .. bone
					)
					t.equal(#keys, #clip.times)
				end
			end
		end
	end)

	t.test("a looping clip ends where it starts", function()
		for _, rig in EnemyRigs do
			for clipName, clip in rig.clips do
				if not clip.loop then
					continue
				end
				local first = RigClip.sample(clip, 0, 1)
				local last = RigClip.sample(clip, clip.length - 1e-6, 1)
				for bone, pose in first do
					t.isTrue(
						angleBetween(pose, last[bone]) < 0.05,
						clipName .. " jumps at its seam on " .. bone
					)
				end
			end
		end
	end)

	t.test("a dash crouches until launched, leaps for the bolt, then skids", function()
		local dash = EnemyRigs.Wilf.clips.Dash
		local launch = dash.markers.Launch
		local land = dash.markers.Land
		t.isTrue(launch ~= nil and land ~= nil and launch < land, "the dash lacks its markers")
		local windup, travel = 0.75, 18 / 26
		t.near(RigClip.dashTime(dash, windup, travel, 0, nil), 0, 1e-9)
		-- Held at the launch for as long as the server winds up.
		t.near(RigClip.dashTime(dash, windup, travel, windup * 3, nil), launch, 1e-9)
		t.near(RigClip.dashTime(dash, windup, travel, windup, 0), launch, 1e-9)
		t.near(RigClip.dashTime(dash, windup, travel, windup, travel), land, 1e-9)
		t.near(RigClip.dashTime(dash, windup, travel, windup, travel + 10), dash.length, 1e-9)
		local before = 0
		for i = 0, 100 do
			local since = i / 100 * (travel + 1)
			local time = RigClip.dashTime(dash, windup, travel, windup, since)
			t.isTrue(time >= before, "the dash runs backwards")
			before = time
		end
	end)

	t.test("every rigged body names a rig that exists", function()
		for name, design in EnemyDesigns :: any do
			if type(design) ~= "table" then
				continue
			end
			for _, spec in design do
				if type(spec) == "table" and spec.rig then
					t.isTrue(
						EnemyRigs[spec.rig] ~= nil,
						name .. "'s rig " .. spec.rig .. " is missing"
					)
					t.isTrue(
						EnemyRigs[spec.rig].part == spec.name,
						name .. "'s rig drives the wrong part"
					)
				end
			end
		end
	end)
end
