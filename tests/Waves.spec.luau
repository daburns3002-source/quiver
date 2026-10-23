--!strict
--[[
	The Waves-mode schedule: which waves are fights, Valkyries, Angels and
	bosses, and what each fight contains. Archero 2's numbering — 5th, 9th and
	10th of every block of ten — is the contract, so it is asserted by
	position rather than as a list of wave numbers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)
local Waves = require(ServerScriptService.Server.Run.Waves)

return function(t: TestRunner.Helper)
	t.test("the first wave is a fight", function()
		t.equal(Waves.kind(1), "Fight")
	end)

	t.test("every block of ten has one Valkyrie, one Angel and one boss, in place", function()
		local schedule = Balance.Waves
		for block = 0, 4 do
			local base = block * schedule.blockSize
			t.equal(Waves.kind(base + schedule.valkyrieAt), "Valkyrie")
			t.equal(Waves.kind(base + schedule.angelAt), "Angel")
			t.equal(Waves.kind(base + schedule.bossAt), "Boss")

			local fights = 0
			for position = 1, schedule.blockSize do
				if Waves.kind(base + position) == "Fight" then
					fights += 1
				end
			end
			t.equal(
				fights,
				schedule.blockSize - 3,
				`block {block + 1} has the wrong number of fights`
			)
		end
	end)

	t.test("encounters spawn nothing, fights and bosses spawn something", function()
		for wave = 1, 30 do
			local description = Waves.describe(wave, 30)
			if description.kind == "Valkyrie" or description.kind == "Angel" then
				t.equal(description.count, 0, `wave {wave} is an encounter that spawns enemies`)
			else
				t.isTrue(description.count > 0, `wave {wave} is a fight with nobody in it`)
				t.isTrue(#description.roster > 0, `wave {wave} has no roster`)
			end
		end
	end)

	--[[ The tutorial order the Rooms list encodes carries into Waves: the
	     first wave fights room one, the last fights the last room, and the
	     tier never steps backwards. ]]
	t.test("waves walk the rooms' difficulty in order", function()
		local total = 30
		t.equal(Waves.tier(1, total), 1)
		t.equal(Waves.tier(total, total), Balance.Waves.rooms)

		local previous = 0
		for wave = 1, total do
			local tier = Waves.tier(wave, total)
			t.isTrue(tier >= previous, `wave {wave} is easier than the one before`)
			previous = tier
		end
	end)
end
