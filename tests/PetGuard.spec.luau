--!strict
--[[
	The Mossback Snail's Shell Guard (docs/PETS-FOREST.md, Attacks): once a
	room its shell blocks one hit. Raised as a room begins
	(`PetCombat.newRoom`, by way of `raiseShell`), never by the clock, and
	spent on the first hit, so a second hit in the same room lands.

	Driven on a session of the test's own, as `Revive.spec` is; the player's
	`Pet` attribute is put back afterwards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PetCombat = require(ServerScriptService.Server.Combat.PetCombat)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local RunSession = require(ServerScriptService.Server.Run.RunSession)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the snail guards, and only the snail", function()
		for key, spec in PetCombatConfig.pets do
			t.equal(spec.guard == true, key == "MossbackSnail", `{key}'s guard`)
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
end
