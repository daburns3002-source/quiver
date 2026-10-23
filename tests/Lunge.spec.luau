--!strict
--[[
	Lunging archetypes (`EnemyConfig.lunges`; the Ember Wolf's charge and
	dash), as `EnemyManager` runs them. Relationships, not values: a lunge
	that is slower than walking is not a lunge, one with no wind-up cannot be
	dodged, and an archetype that walks in to a distance none of its lunges
	covers stands next to the player with nothing to do, since it has no
	plain bite.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local TestRunner = require(script.Parent.TestRunner)

local function lungers(): { [string]: Balance.EnemyConfig }
	local out = {}
	for name, config in Balance.Enemies :: any do
		if config.lunges then
			out[name] = config
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("there is a lunging archetype to test", function()
		t.isTrue(next(lungers()) ~= nil, "no archetype lunges")
	end)

	t.test("every lunge is faster than walking and winds up first", function()
		for name, config in lungers() do
			for i, lunge in config.lunges :: { Balance.EnemyLunge } do
				t.isTrue(
					lunge.speed > config.moveSpeed * 2,
					`{name}'s lunge {i} is barely faster than walking`
				)
				t.isTrue(lunge.telegraph >= 0.25, `{name}'s lunge {i} has no wind-up to react to`)
				t.isTrue(
					lunge.distance > 0 and lunge.damageScale > 0,
					`{name}'s lunge {i} goes nowhere or hurts nothing`
				)
				t.isTrue(lunge.maxRange > lunge.minRange, `{name}'s lunge {i} has an empty range`)
			end
		end
	end)

	--[[ It walks in to `attackRange` and stops there; with no plain bite,
	     that has to be inside one of its lunges. ]]
	t.test("where it stops walking, a lunge can start", function()
		for name, config in lungers() do
			local covered = false
			for _, lunge in config.lunges :: { Balance.EnemyLunge } do
				if config.attackRange >= lunge.minRange and config.attackRange < lunge.maxRange then
					covered = true
				end
			end
			t.isTrue(
				covered,
				`{name} stops at {config.attackRange} studs, where none of its lunges starts`
			)
		end
	end)

	t.test("lunge ranges do not overlap", function()
		for name, config in lungers() do
			local lunges = config.lunges :: { Balance.EnemyLunge }
			for i = 1, #lunges do
				for j = i + 1, #lunges do
					local a, b = lunges[i], lunges[j]
					t.isTrue(
						a.maxRange <= b.minRange or b.maxRange <= a.minRange,
						`{name}'s lunges {i} and {j} both claim the same distance`
					)
				end
			end
		end
	end)

	--[[ An `Eyes` tell is the eyes alone turning red (the Ember Wolf's
	     charge, owner 2026-10-23): an enemy with one and no eyes in its
	     design would wind up with no warning at all. ]]
	t.test("every eye-flash wind-up has eyes to flash", function()
		for name, config in Balance.Enemies :: { [string]: Balance.EnemyConfig } do
			local lunges: { Balance.EnemyLunge } = config.lunges or {}
			for _, lunge in lunges do
				if lunge.tell ~= "Eyes" then
					continue
				end
				local design = (EnemyDesigns :: any)[config.displayName]
				local eyes = 0
				for _, spec in design or {} do
					if spec.eye then
						eyes += 1
					end
				end
				t.isTrue(eyes > 0, name .. " flashes its eyes but has none")
			end
		end
	end)
end
