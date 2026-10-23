--!strict
--[[
	The weapons' animations (`Config/WeaponAnimations`) as `Fx/WeaponPose`
	plays them. Generated from the owner's kits, so these pin what the player
	assumes of any kit: every clip a weapon names exists, keys run from 0 to
	the clip's end, every key moves the same joints, markers fall inside
	their clip, and `hold` leaves the legs to walk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.TestRunner)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ROLES = { "hold", "ready", "aim", "fire" }

local function eachWeapon(): { [string]: Weapons.Weapon }
	local out = {}
	for name, entry in Weapons :: any do
		if type(entry) == "table" and entry.clips then
			out[name] = entry
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("every weapon's clips exist", function()
		for name, weapon in eachWeapon() do
			local clips = WeaponAnimations[name]
			t.notNil(clips, `{name} has no animations`)
			for _, role in ROLES do
				local clip = (weapon.clips :: any)[role]
				t.notNil(clips and clips[clip], `{name}'s {role} clip {clip} is missing`)
			end
		end
	end)

	t.test("every clip's keys run in order from 0 to its length", function()
		for weapon, clips in WeaponAnimations do
			for name, clip in clips do
				local keys = clip.keys
				t.isTrue(#keys >= 2, `{weapon} {name} has fewer than two keys`)
				t.near(keys[1].t, 0, 1e-9)
				t.near(keys[#keys].t, clip.length, 1e-6)
				for i = 2, #keys do
					t.isTrue(keys[i].t > keys[i - 1].t, `{weapon} {name}'s keys are out of order`)
				end
				for marker, at in clip.markers do
					t.isTrue(at < clip.length, `{weapon} {name}'s {marker} falls after it ends`)
				end
			end
		end
	end)

	t.test("every key of a clip moves the same joints", function()
		for weapon, clips in WeaponAnimations do
			for name, clip in clips do
				for joint in clip.keys[1].joints do
					for _, key in clip.keys do
						t.notNil(key.joints[joint], `{weapon} {name} drops {joint} at {key.t}`)
					end
				end
			end
		end
	end)

	--[[ The shot leaves at the fire marker; a fire clip without one would
	     never let go of the arrow. ]]
	t.test("every fire clip has a marker", function()
		for name, weapon in eachWeapon() do
			local clip = WeaponAnimations[name][weapon.clips.fire]
			t.isTrue(next(clip.markers) ~= nil, `{name}'s fire clip has no marker`)
		end
	end)

	--[[ `hold` plays while moving; a leg in it would freeze the walk. ]]
	t.test("every hold clip moves the arms only", function()
		for name, weapon in eachWeapon() do
			for joint in WeaponAnimations[name][weapon.clips.hold].keys[1].joints do
				t.isTrue(
					string.find(joint, "Shoulder") ~= nil
						or string.find(joint, "Elbow") ~= nil
						or string.find(joint, "Wrist") ~= nil,
					`{name}'s hold moves {joint}`
				)
			end
		end
	end)
end
