--!strict
--[[
	Shell Guard (docs/PETS-FOREST.md, Attacks): once a room the shell blocks
	one hit. Raised as a room begins (`PetCombat.newRoom`, by way of
	`raiseShell`), never by the clock, and spent on the first hit, so a
	second hit in the same room lands.

	Two pets carry it, the Mossback Snail and the Thistle Mole, but only the
	Snail is hatchable: each egg holds one Uncommon (`Config/Pets`), and
	Thornwood's is the Berry Mouse. So the rule is that no egg holds two
	guards — never that every egg holds one. An earlier version of this file
	asserted the latter and was wrong; it reached main unverified on
	2026-10-31 because the suite could not be run, and this is the
	correction. Whether Thornwood's Uncommon should be the guard instead of
	the healer is the owner's call and is open in docs/TRACKER.md.

	Driven on a session of the test's own, as `Revive.spec` is; the player's
	`Pet` attribute is put back afterwards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PetCombat = require(ServerScriptService.Server.Combat.PetCombat)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local RunSession = require(ServerScriptService.Server.Run.RunSession)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("no egg holds two guards", function()
		for _, egg in Eggs.list do
			local guards = {}
			for _, entry in EggRules.pool(egg.key) do
				local spec = PetCombatConfig.pets[entry.pet]
				if spec and spec.guard then
					table.insert(guards, entry.pet)
				end
			end
			t.isTrue(#guards <= 1, `{egg.key} holds {#guards} guards: {table.concat(guards, ", ")}`)
		end
	end)

	--[[ A guard a player cannot hatch is dead code, and two of them would
	     mean one egg had been given the other's. Pinned as a count so the
	     day Thornwood's Uncommon changes, this says so. ]]
	t.test("one guard is hatchable, and it is the Snail", function()
		local hatchable = {}
		for _, egg in Eggs.list do
			for _, entry in EggRules.pool(egg.key) do
				local spec = PetCombatConfig.pets[entry.pet]
				if spec and spec.guard then
					table.insert(hatchable, `{entry.pet} ({egg.key})`)
				end
			end
		end
		t.equal(#hatchable, 1, `guards a player can hatch: {table.concat(hatchable, ", ")}`)
		t.isTrue(
			string.find(hatchable[1] or "", "MossbackSnail", 1, true) ~= nil,
			`the hatchable guard is {hatchable[1]}`
		)
	end)

	t.test("a guard does nothing else: no damage, no clock", function()
		for key, spec in PetCombatConfig.pets do
			if spec.guard then
				t.isNil(spec.damage, `{key} guards and hits`)
				t.equal(spec.every, 0, `{key}'s guard is not on a clock`)
			end
		end
	end)

	--[[ Thorn Shell (owner, 2026-10-31): the Thistle Mole's block answers.
	     A reflect without a guard would never fire, since the burst hangs
	     off the block. ]]
	t.test("thorns off a shell belong to a pet that has one", function()
		for key, spec in PetCombatConfig.pets do
			local reflect = spec.reflect
			if not reflect then
				continue
			end
			t.isTrue(spec.guard == true, `{key} bursts thorns but blocks nothing`)
			t.isTrue(reflect.damage > 0, `{key}: thorns that do something`)
			t.isTrue(reflect.radius > 0, `{key}: thorns that reach something`)
		end
	end)

	local player = Players:GetPlayers()[1]
	if not player then
		return
	end

	local function withPet(pet: string?, body: (RunSession.Session) -> ())
		local before = player:GetAttribute("Pet")
		player:SetAttribute("Pet", pet)
		local session = RunSession.create(player)
		session.alive = true
		session.health = session.maxHealth
		local ok, err = pcall(function()
			body(session)
		end)
		player:SetAttribute("Pet", before)
		if not ok then
			error(err, 0)
		end
	end

	t.test("a raised shell blocks one hit, then the next lands", function()
		withPet("MossbackSnail", function(session)
			PetCombat.raiseShell(session)
			t.isTrue(session.petGuard, "the shell is up as the room begins")
			RunSession.applyDamage(session, 50)
			t.equal(session.health, session.maxHealth)
			t.isFalse(session.petGuard, "the shell is spent")
			RunSession.applyDamage(session, 50)
			t.isTrue(session.health < session.maxHealth, "a second hit in the room lands")
		end)
	end)

	t.test("the next room raises it again", function()
		withPet("MossbackSnail", function(session)
			PetCombat.raiseShell(session)
			RunSession.applyDamage(session, 50)
			PetCombat.raiseShell(session)
			RunSession.applyDamage(session, 50)
			t.equal(session.health, session.maxHealth)
		end)
	end)

	t.test("a pet that does not guard raises no shell", function()
		withPet("Mosslet", function(session)
			PetCombat.raiseShell(session)
			t.isFalse(session.petGuard)
		end)
	end)

	--[[ The burst itself needs enemies to hit, which a test has none of; what
	     is pinned here is that blocking reaches for it at all and that a
	     shell with nothing to answer with is harmless. ]]
	t.test("blocking with the Thistle Mole answers, and blocking without one does not", function()
		withPet("ThistleMole", function(session)
			local answered: { string } = {}
			local before = RunSession.onShellBlock
			RunSession.onShellBlock = function(_s, pet: string)
				table.insert(answered, pet)
			end
			PetCombat.raiseShell(session)
			RunSession.applyDamage(session, 50)
			RunSession.onShellBlock = before
			t.equal(#answered, 1, "the block was answered once")
			t.equal(answered[1], "ThistleMole")
			t.equal(session.health, session.maxHealth, "and it still blocked the hit")
		end)
	end)

	t.test("the Snail's shell blocks without bursting", function()
		withPet("MossbackSnail", function(session)
			PetCombat.raiseShell(session)
			-- it has no `reflect`, so the burst finds nothing to do
			PetCombat.shellBlocked(session, "MossbackSnail")
			t.equal(session.health, session.maxHealth)
		end)
	end)
end
