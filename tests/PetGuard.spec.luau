--!strict
--[[
	Shell Guard (docs/PETS-FOREST.md, Attacks): once a room the shell blocks
	one hit. Raised as a room begins (`PetCombat.newRoom`, by way of
	`raiseShell`), never by the clock, and spent on the first hit, so a
	second hit in the same room lands.

	The Mossback Snail carries it in the Mossy Glade and the Thistle Mole in
	Thornwood: one guard to an egg, so a player always has the option and
	never two of it.

	That was asserted here before it was true. Each egg holds one Uncommon
	(`Config/Pets`) and Thornwood's was the Berry Mouse, so its egg held no
	guard at all and this file failed the moment the suite could run it
	(2026-10-31). The owner answered by putting the Mole in the egg rather
	than by loosening the rule, so the rule is back — and so is a second
	test below, because the way this went wrong was a rule nothing checked
	against the eggs themselves.

	**Since the Bogheart Egg (2026-11-06) the rule is one pet that keeps its
	owner from harm, of whichever kind.** That egg's is the Bog Beaver, and
	its Mud Plaster is a coat that soaks damage (`Util/MudCoat`), kept apart
	from the Snail's shell on purpose (`docs/PETS-BOGHEART.md`: "None
	repeats areas 1-3"). The test below still counted shells only, so it
	failed on main from the day the egg opened ("BogheartEgg holds 0
	guards", seen 2026-11-16). There are three kinds: a shell (`guard`), a
	shelter that takes a share off every hit (`shelter`, the Slate Turtle's)
	and a coat (`coat`). An egg holds exactly one pet with any of them, and
	it is the egg's Uncommon.

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

--[[ Whether a pet's whole job is keeping its owner from harm: a shell, a
     shelter, a coat or a wall. ]]
local function protects(spec: any): boolean
	return spec ~= nil
		and (spec.guard == true or spec.shelter ~= nil or spec.coat ~= nil or spec.wall ~= nil)
end

return function(t: TestRunner.Helper)
	t.test("exactly one pet in each egg keeps its owner from harm", function()
		for _, egg in Eggs.list do
			local keepers = {}
			for _, entry in EggRules.pool(egg.key) do
				if protects(PetCombatConfig.pets[entry.pet]) then
					table.insert(keepers, entry.pet)
					t.equal(entry.rarity, "Uncommon", `{entry.pet} is its egg's keeper`)
				end
			end
			t.equal(
				#keepers,
				1,
				`{egg.key} holds {#keepers} pets that protect: {table.concat(keepers, ", ")}`
			)
		end
	end)

	t.test("a pet protects in one way only", function()
		for key, spec in PetCombatConfig.pets do
			local ways = 0
			for _, has in
				{ spec.guard == true, spec.shelter ~= nil, spec.coat ~= nil, spec.wall ~= nil }
			do
				if has then
					ways += 1
				end
			end
			t.isTrue(ways <= 1, `{key} protects in {ways} ways`)
		end
	end)

	--[[ And every guard in the game is one of those: a guard with a spec, an
	     attack and no egg is dead code, which is what the Thistle Mole was
	     until the owner put it in the egg. ]]
	t.test("every guard that exists can be hatched", function()
		local hatchable: { [string]: boolean } = {}
		for _, egg in Eggs.list do
			for _, entry in EggRules.pool(egg.key) do
				hatchable[entry.pet] = true
			end
		end
		for key, spec in PetCombatConfig.pets do
			if spec.guard then
				t.isTrue(hatchable[key] == true, `{key} guards but is in no egg`)
			end
		end
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
