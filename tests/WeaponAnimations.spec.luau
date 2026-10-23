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
local WeaponTiming = require(ReplicatedStorage.Shared.Combat.WeaponTiming)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

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
			local named: { string } = { weapon.clips.hold }
			for _, optional in { "move", "ready", "aim" } do
				local clip = (weapon.clips :: any)[optional]
				if clip then
					table.insert(named, clip)
				end
			end
			for _, clip in weapon.clips.fire do
				table.insert(named, clip)
			end
			for _, clip in named do
				t.notNil(clips and clips[clip], `{name}'s clip {clip} is missing`)
			end
			t.isTrue(#weapon.clips.fire >= 1, `{name} has no fire clip`)
			t.isTrue(
				(weapon.clips.ready == nil) == (weapon.clips.aim == nil),
				`{name} has a ready clip without an aim, or the other way round`
			)
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

	--[[ The attack leaves at the fire clip's marker; a fire clip without
	     one would never let go of the arrow or land the blow. ]]
	t.test("every fire clip has a marker", function()
		for name, weapon in eachWeapon() do
			for _, clipName in weapon.clips.fire do
				local clip = WeaponAnimations[name][clipName]
				t.isTrue(next(clip.markers) ~= nil, `{name}'s {clipName} has no marker`)
			end
		end
	end)

	--[[ A swing's damage lands on its Hit marker, and its trail shows
	     between TrailOn and TrailOff: in that order, or the blow lands with
	     no blade drawn. ]]
	t.test("a slash's trail is on when its blow lands", function()
		for weapon, clips in WeaponAnimations do
			for name, clip in clips do
				local on, hit, off = clip.markers.TrailOn, clip.markers.Hit, clip.markers.TrailOff
				if hit and on and off then
					t.isTrue(on <= hit and hit <= off, `{weapon} {name} lands outside its trail`)
				end
			end
		end
	end)

	--[[ `hold` plays while moving; a leg in it would freeze the walk. The
	     upper body is its own (the owner's LeafBow kit turns the waist and
	     the head too). ]]
	local UPPER = { "Shoulder", "Elbow", "Wrist", "Waist", "Neck" }
	local ARMS = { "Shoulder", "Elbow", "Wrist" }
	local function isAny(joint: string, names: { string }): boolean
		for _, part in names do
			if string.find(joint, part) then
				return true
			end
		end
		return false
	end

	t.test("every hold clip leaves the legs free", function()
		for name, weapon in eachWeapon() do
			for joint in WeaponAnimations[name][weapon.clips.hold].keys[1].joints do
				t.isTrue(isAny(joint, UPPER), `{name}'s hold moves {joint}`)
			end
		end
	end)

	--[[ A legs layer (`clips.legs`) is under every clip and loops,
	     standing and walking. It may sway the body (the owner's walk swings
	     the waist and neck, 2026-10-23), but every arm it moves must be one
	     the hold drives over it, or the walk would swing the bow out of
	     the hand. ]]
	t.test("a legs layer loops and never moves the weapon's arms", function()
		for name, weapon in eachWeapon() do
			local legs = weapon.clips.legs
			if not legs then
				continue
			end
			t.isTrue(legs.walkSpeed > 0, `{name}'s walk has no speed`)
			local hold = WeaponAnimations[name][weapon.clips.hold]
			for _, clipName in { legs.idle, legs.walk } do
				local clip = WeaponAnimations[name][clipName]
				t.notNil(clip, `{name} has no {clipName}`)
				t.isTrue(clip.loop, `{name}'s {clipName} does not loop`)
				for joint in clip.keys[1].joints do
					if isAny(joint, ARMS) then
						t.isTrue(
							(hold.keys[1].joints :: any)[joint] ~= nil,
							`{name}'s {clipName} moves {joint} under a hold that leaves it`
						)
					end
				end
			end
		end
	end)

	--[[ A combo keeps its place between attacks, however long the wielder
	     moves, and comes round to its first blow after its last. ]]
	t.test("a combo cycles through every blow in order", function()
		for name, weapon in eachWeapon() do
			local count = #weapon.clips.fire
			local index = 0
			for expected = 1, count * 2 do
				index = WeaponTiming.nextInCombo(name, index)
				t.isTrue(index == (expected - 1) % count + 1, `{name}'s combo skipped to {index}`)
			end
		end
	end)
end
