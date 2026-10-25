--!strict
--[[
	A pet's projectile blow lands as its piece arrives (`Shared/Combat/PetShots`,
	owner 2026-10-25: the Hootmoss's and Babacorn's damage came before their
	shots). `Combat/PetCombat` lands blow n at launch(n) + flight(distance);
	`Fx/PetAttackFx` flies the piece for the same flight.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetShots = require(ReplicatedStorage.Shared.Combat.PetShots)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the Hootmoss and the Babacorn wait for their projectiles", function()
		for _, pet in { "Hootmoss", "Babacorn" } do
			local shot = PetShots.projectile(pet)
			t.notNil(shot, `{pet} throws a projectile`)
			t.notNil(PetCombatConfig.pets[pet].damage, `{pet} does damage with it`)
		end
		t.isNil(PetShots.projectile("FernFrog"), "a tongue lands at once")
		t.isNil(PetShots.projectile("Glimmerhorn"), "a beam lands at once")
	end)

	t.test("a blow lands one flight after its piece leaves", function()
		for pet, shots in PetAttacks do
			local shot = PetShots.projectile(pet)
			if not shot then
				continue
			end
			t.isTrue(shots[1] == shot, `{pet}: the blows ride the first piece`)
			local speed = shot.speed or PetShots.DEFAULT_SPEED
			for _, distance in { 4, 20, 40 } do
				local flight = PetShots.flight(shot, distance)
				t.isTrue(flight >= PetShots.MIN_FLIGHT, `{pet}: never instant`)
				if distance / speed > PetShots.MIN_FLIGHT then
					t.near(flight, distance / speed, 1e-9, `{pet}: flies at its speed`)
				end
			end
			t.isTrue(
				PetShots.flight(shot, 40) > PetShots.flight(shot, 20),
				`{pet}: a farther enemy is hit later`
			)
		end
	end)

	t.test("each blow rides its own piece of the volley, in turn", function()
		for pet in PetAttacks do
			local shot = PetShots.projectile(pet)
			if not shot then
				continue
			end
			local count = shot.count or 1
			t.near(PetShots.launch(shot, 1), shot.at, 1e-9, `{pet}: the first leaves with the clip`)
			for blow = 2, count do
				t.isTrue(
					PetShots.launch(shot, blow) >= PetShots.launch(shot, blow - 1),
					`{pet}: piece {blow} leaves no earlier than the one before`
				)
			end
			t.near(
				PetShots.launch(shot, count + 1),
				PetShots.launch(shot, 1),
				1e-9,
				`{pet}: more blows than pieces start the volley over`
			)
		end
		-- the Babacorn's three blows ride its three pellets, `every` apart
		local acorn = PetShots.projectile("Babacorn") :: PetAttacks.Shot
		local every = acorn.every or 0
		t.isTrue(every > 0, "the pellets leave one after another")
		t.near(PetShots.launch(acorn, 3) - PetShots.launch(acorn, 1), 2 * every, 1e-9)
	end)

	t.test("the server measures from where the pet stands, behind its owner", function()
		local root = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
		local heel = PetShots.heel(root)
		t.isTrue(heel.Z > 0, "behind an owner facing -Z")
		t.near(heel.Y, 0, 1e-9, "level with the owner")
	end)
end
