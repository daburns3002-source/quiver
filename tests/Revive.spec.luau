--!strict
--[[
	Saving a run from a lethal hit: no free revive any more (2026-10-25), only
	Second Wind or a pet that revives.

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

	t.test("there is no free revive: a lethal hit kills", function()
		-- owner, 2026-10-25: "take out the automatic revive"
		t.equal(Balance.Revive.perStage, 0)
		local session = fresh()
		RunSession.applyDamage(session, session.maxHealth * 10)
		t.isFalse(session.alive, "the player was revived for free")
	end)

	t.test("Second Wind still saves, at its share of health, untouchable", function()
		local session = fresh()
		session.secondWind = 0.4
		RunSession.applyDamage(session, session.maxHealth * 10)

		t.isTrue(session.alive, "Second Wind did not save the player")
		t.near(session.health, session.maxHealth * 0.4, 1e-6)
		t.isTrue(session.secondWindUsed)
		t.isTrue(RunSession.isInvulnerable(session))
		RunSession.applyDamage(session, 50)
		t.near(session.health, session.maxHealth * 0.4, 1e-6)
	end)

	t.test("the shield outlasts a hit's reaction and the clear reaches past melee", function()
		t.isTrue(Balance.Revive.invulnerable >= 1)
		t.isTrue(Balance.Revive.clearRadius > 4)
	end)
end
