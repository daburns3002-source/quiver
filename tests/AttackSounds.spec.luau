--!strict
--[[
	Every pet and every enemy makes a sound when it attacks (the 2026-11-26
	sweep found areas 2-4's pets and a dozen enemies silent; round 35 filled
	them in): each pet has a cue in `Config/PetSounds`, each enemy a sound in
	`Config/EnemySounds`, and every name there is a sound that exists in
	`Config/Sounds`. A sound whose id is still empty is silent, which is
	fine; a missing one is not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemySounds = require(ReplicatedStorage.Shared.Config.EnemySounds)
local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetSounds = require(ReplicatedStorage.Shared.Config.PetSounds)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local TestRunner = require(script.Parent.TestRunner)

--[[ An enemy by model name, from the roster or the bench. A fallen body is
     its enemy's name with "Fallen" after it. ]]
local function enemy(name: string): Balance.EnemyConfig?
	local base = string.gsub(name, "Fallen$", "")
	return Balance.Enemies[base] or Balance.Benched[base]
end

return function(t: TestRunner.Helper)
	t.test("every pet sounds as it attacks, on a sound that exists", function()
		for key in Pets do
			local cues = (PetSounds :: any)[key]
			t.isTrue(cues ~= nil and #cues > 0, `{key} has no attack sound in Config/PetSounds`)
		end
		for key, cues in PetSounds do
			t.notNil((Pets :: any)[key], `PetSounds names {key}, which is not a pet`)
			for _, cue in cues do
				t.notNil(Sounds[cue.sound], `{key}'s cue plays unknown sound {cue.sound}`)
				t.isTrue(cue.at >= 0 and cue.at < 3, `{key}'s {cue.sound} plays at {cue.at} s`)
			end
		end
	end)

	t.test("each pet's sound plays with its attack's first piece", function()
		for key, cues in PetSounds do
			local shots = (PetAttacks :: any)[key]
			if shots and shots[1] then
				t.near(cues[1].at, shots[1].at, 0.25, `{key}'s sound is far from its first piece`)
			end
		end
	end)

	t.test("every enemy and boss has a sound, and each one exists", function()
		local heard: { [string]: boolean } = {}
		local function check(model: string, sound: string)
			t.notNil(enemy(model), `EnemySounds names {model}, which is not an enemy`)
			t.notNil(Sounds[sound], `{model} plays unknown sound {sound}`)
			heard[string.gsub(model, "Fallen$", "")] = true
		end
		for model, clips in EnemySounds.clips do
			for _, sound in clips do
				check(model, sound)
			end
		end
		for _, list in
			{ EnemySounds.attacks, EnemySounds.shots, EnemySounds.arrive, EnemySounds.dive }
		do
			for model, sound in list do
				check(model, sound)
			end
		end
		for kind, tell in EnemySounds.tells do
			local boss = enemy(tell.boss)
			t.isTrue(
				boss ~= nil and boss.boss ~= nil,
				`the {kind} telegraph's {tell.boss} is not a boss`
			)
			check(tell.boss, tell.sound)
		end
		for name in Balance.Enemies :: { [string]: any } do
			t.isTrue(heard[name] == true, `{name} makes no sound when it attacks`)
		end
		for name in Balance.Benched :: { [string]: any } do
			t.isTrue(heard[name] == true, `benched {name} makes no sound when it attacks`)
		end
	end)

	t.test("the Tollcrab's dash sounds as it starts, not as its lane is drawn", function()
		local lane = EnemySounds.tells.Lane
		local speed = lane.dashSpeed :: number
		local boss = Balance.Enemies.OldTollcrab.boss :: Balance.EnemyBoss
		local scuttle = boss.scuttle :: Balance.BossScuttle
		t.equal(speed, scuttle.speed, "the dash speed is the Tollcrab's own")
		-- a 0.9 s warning, then a dash of a second at his speed
		t.near(EnemySounds.tellDelay(lane, 0.9 + 1, speed), 0.9, 1e-6)
		t.equal(EnemySounds.tellDelay(lane, 0.2, speed * 5), 0)
		t.equal(EnemySounds.tellDelay(EnemySounds.tells.TollRing, 2, 10), 0)
	end)
end
