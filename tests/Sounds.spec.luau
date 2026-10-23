--!strict
--[[
	The sound table (`Config/Sounds`) as `Fx/SoundFx` plays it: every entry
	is playable once it has an id, and every weapon's shot names a sound
	that exists. Ids stay empty until the owner uploads the audio, which
	must not fail anything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	t.test("every sound is empty or a Roblox asset, at a sane level", function()
		for name, sound in Sounds do
			t.isTrue(
				sound.id == "" or string.match(sound.id, "^rbxassetid://%d+$") ~= nil,
				`{name}'s id {sound.id} is not an asset id`
			)
			t.isTrue(sound.volume > 0 and sound.volume <= 1, `{name}'s volume is out of 0–1`)
			t.isTrue(sound.pitchJitter >= 0 and sound.pitchJitter < 0.5, `{name}'s jitter is wild`)
			t.isTrue(sound.minGap >= 0, `{name}'s gap is negative`)
			t.isTrue(
				sound.speed == nil or (sound.speed > 0.5 and sound.speed < 2),
				`{name}'s speed is wild`
			)
		end
	end)

	t.test("every weapon's shot plays a sound that exists", function()
		for name, entry in Weapons :: any do
			if type(entry) == "table" and entry.fireSound then
				t.notNil(Sounds[entry.fireSound], `{name} fires unknown sound {entry.fireSound}`)
				for blow, sound in entry.comboSounds or {} do
					t.notNil(Sounds[sound], `{name}'s blow {blow} plays unknown sound {sound}`)
				end
				if entry.comboSounds then
					t.isTrue(
						#entry.comboSounds == #entry.clips.fire,
						`{name} has {#entry.comboSounds} combo sounds for {#entry.clips.fire} blows`
					)
				end
			end
		end
	end)
end
