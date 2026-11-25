--!strict
--[[
	The session lock on a player's record (`Server/Data/SaveLock`): a server
	loads only a record nobody else holds, and writes only over one it
	holds, never over one it has let go (2026-11-25: a run server's late
	autosave took the lock back after the player left, and the lobby sent
	them away).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local SaveLock = require(ServerScriptService.Server.Data.SaveLock)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local now = 1_000_000

	t.test("a record nobody holds can be loaded", function()
		t.isTrue(SaveLock.mayTake(nil, "lobby", now))
	end)

	t.test("a record another live server holds cannot be loaded", function()
		t.isFalse(SaveLock.mayTake({ job = "run", time = now - 5 }, "lobby", now))
	end)

	t.test("a lock gone stale can be taken; this server's own always can", function()
		t.isTrue(SaveLock.mayTake({ job = "run", time = now - SaveLock.STALE }, "lobby", now))
		t.isTrue(SaveLock.mayTake({ job = "lobby", time = now - 5 }, "lobby", now))
	end)

	t.test("a save writes only over a record this server holds", function()
		t.isTrue(SaveLock.mayWrite({ job = "run", time = now }, "run"))
		t.isFalse(SaveLock.mayWrite({ job = "lobby", time = now }, "run"), "another server's")
		t.isFalse(
			SaveLock.mayWrite({ job = "lobby", time = now - SaveLock.STALE * 2 }, "run"),
			"another server's, even stale"
		)
	end)

	t.test("a save that lands after the release does not take the lock back", function()
		-- the run server let go as the player left; its queued autosave lands now
		t.isFalse(SaveLock.mayWrite(nil, "run"))
		-- and the lobby can load straight away
		t.isTrue(SaveLock.mayTake(nil, "lobby", now))
	end)
end
