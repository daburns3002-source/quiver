--!strict
--[[
	The stage's revive.

	Driven on a session of the module's own, which `execute_luau` loads fresh,
	so the live run is not touched. The session is never bound to a character:
	`alive` is set by hand, which is all `applyDamage` reads.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local RunSession = require(ServerScriptService.Server.Run.RunSession)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local player = Players:GetPlayers()[1]
	if not player then
		return
	end

	local function fresh(): RunSession.Session
		local session = RunSession.create(player)
		session.alive = true
		session.health = session.maxHealth
		return session
	end

	t.test("the first lethal hit revives at full health, untouchable", function()
		local session = fresh()
		RunSession.applyDamage(session, session.maxHealth * 10)

		t.isTrue(session.alive, "the revive did not save the player")
		t.equal(session.health, session.maxHealth)
		t.equal(session.revivesLeft, Balance.Revive.perStage - 1)
		t.isTrue(RunSession.isInvulnerable(session))
	end)

	t.test("nothing hurts while invulnerable", function()
		local session = fresh()
		RunSession.applyDamage(session, session.maxHealth * 10)
		RunSession.applyDamage(session, 50)
		t.equal(session.health, session.maxHealth)
	end)

	t.test("with the revives spent, a lethal hit kills", function()
		local session = fresh()
		for _ = 1, Balance.Revive.perStage do
			RunSession.applyDamage(session, session.maxHealth * 10)
			session.invulnerableUntil = 0
		end

		RunSession.applyDamage(session, session.maxHealth * 10)
		t.isFalse(session.alive, "a revive was spent twice")
	end)

	t.test("Second Wind is spent before the revive", function()
		local session = fresh()
		session.secondWind = true
		RunSession.applyDamage(session, session.maxHealth * 10)

		t.equal(session.health, 1)
		t.isTrue(session.secondWindUsed)
		t.equal(session.revivesLeft, Balance.Revive.perStage)
	end)

	t.test("a new stage gives the revives back", function()
		local session = fresh()
		RunSession.applyDamage(session, session.maxHealth * 10)
		RunSession.newStage(session)
		t.equal(session.revivesLeft, Balance.Revive.perStage)
		t.isFalse(RunSession.isInvulnerable(session))
	end)

	t.test("the shield outlasts a hit's reaction and the clear reaches past melee", function()
		t.isTrue(Balance.Revive.invulnerable >= 1)
		t.isTrue(Balance.Revive.clearRadius > 4)
	end)
end
