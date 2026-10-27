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

	--[[ A stage that brings its own fights (Mossy Glade's wave levels):
	     its fights spread in order, its elite on the boss positions, and its
	     finale on the last wave whatever the schedule puts there. ]]
	t.test("a stage's own fights, elite and finale", function()
		local a = { enemyCount = 3, roster = { Balance.Enemies.MeleeCharger } }
		local b = { enemyCount = 5, roster = { Balance.Enemies.BroodSlime } }
		local elite = { enemyCount = 6, roster = { Balance.Enemies.SpreadShooter } }
		local finale = { enemyCount = 1, roster = { Balance.Enemies.SlimeKing } }
		local stage: Balance.StageConfig = {
			name = "Test",
			mode = "Waves",
			arena = 1,
			waves = 25,
			fights = { a, b },
			elite = elite,
			finale = finale,
		}
		t.equal(Waves.describe(1, 25, stage).count, 3)
		t.equal(Waves.describe(24, 25, stage).count, 5)
		local ten = Waves.describe(10, 25, stage)
		t.equal(ten.kind, "Elite")
		t.equal(ten.count, 6)
		-- the 25th would be a Valkyrie; the finale takes it
		t.equal(Waves.kind(25), "Valkyrie")
		local last = Waves.describe(25, 25, stage)
		t.equal(last.kind, "Boss")
		t.isTrue(last.roster[1] == Balance.Enemies.SlimeKing)
		-- without a finale, the schedule stands
		stage.finale = nil
		t.equal(Waves.describe(25, 25, stage).kind, "Valkyrie")
		local previous = 0
		for wave = 1, 25 do
			local index = Waves.fightIndex(wave, 25, 2)
			t.isTrue(index >= previous, `wave {wave} steps back`)
			previous = index
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
