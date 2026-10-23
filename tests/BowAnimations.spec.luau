--!strict
--[[
	The Leaf Bow's animations (`Config/BowAnimations`) as `Fx/ArcherPose`
	plays them. Generated from the owner's kit, so these pin what the player
	assumes of any kit: keys from 0 to the clip's end, markers inside it,
	every key moving the same joints, and Hold leaving the legs to walk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowAnimations = require(ReplicatedStorage.Shared.Config.BowAnimations)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the player's four clips exist", function()
		for _, name in { "Hold", "Draw", "Aim", "Fire" } do
			t.notNil(BowAnimations[name], `{name} is missing`)
		end
	end)

	t.test("every clip's keys run in order from 0 to its length", function()
		for name, clip in BowAnimations do
			local keys = clip.keys
			t.isTrue(#keys >= 2, `{name} has fewer than two keys`)
			t.near(keys[1].t, 0, 1e-9)
			t.near(keys[#keys].t, clip.length, 1e-6)
			for i = 2, #keys do
				t.isTrue(keys[i].t > keys[i - 1].t, `{name}'s keys are out of order`)
			end
		end
	end)

	t.test("every key of a clip moves the same joints", function()
		for name, clip in BowAnimations do
			for joint in clip.keys[1].joints do
				for _, key in clip.keys do
					t.notNil(key.joints[joint], `{name} drops {joint} at {key.t}`)
				end
			end
		end
	end)

	t.test("the arrow is nocked in Draw and released in Fire", function()
		local nock = BowAnimations.Draw.markers.Nock
		local release = BowAnimations.Fire.markers.Release
		t.notNil(nock, "Draw has no Nock marker")
		t.notNil(release, "Fire has no Release marker")
		t.isTrue((nock :: number) < BowAnimations.Draw.length, "Nock falls after Draw ends")
		t.isTrue((release :: number) < BowAnimations.Fire.length, "Release falls after Fire ends")
	end)

	--[[ Hold plays while moving; a leg in it would freeze the walk. ]]
	t.test("Hold moves the arms only", function()
		for joint in BowAnimations.Hold.keys[1].joints do
			t.isTrue(
				string.find(joint, "Shoulder") ~= nil
					or string.find(joint, "Elbow") ~= nil
					or string.find(joint, "Wrist") ~= nil,
				`Hold moves {joint}`
			)
		end
	end)
end
