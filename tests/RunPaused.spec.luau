--!strict
--[[
	The pause flag shared by movement, firing prediction and the dash.

	One flag rather than three copies, because the failure mode of copies is
	that one gets cleared and another does not — a player who can still walk
	behind the card screen, or who can never shoot again after it.

	The wiring into MoveController cannot be exercised over MCP, since
	synthetic input is capability-blocked there. This pins the half that can
	be: that the flag holds, notifies, and does not fire for no change.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local RunPaused = require(StarterPlayer.StarterPlayerScripts.Client.RunPaused)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the flag holds what it was set to", function()
		RunPaused.set(true)
		t.isTrue(RunPaused.get(), "a pause did not stick")

		RunPaused.set(false)
		t.isFalse(RunPaused.get(), "a resume did not stick")
	end)

	t.test("listeners hear every real change", function()
		RunPaused.set(false)

		local heard: { boolean } = {}
		local connection = RunPaused.onChanged(function(value)
			table.insert(heard, value)
		end)

		RunPaused.set(true)
		RunPaused.set(false)
		task.wait()
		connection:Disconnect()

		t.equal(#heard, 2, "a change went unannounced")
		t.equal(heard[1], true)
		t.equal(heard[2], false)
	end)

	--[[ Callers set it from several places — an offer, a grant, a death — so
	     setting it to what it already is must not re-fire, or the settle
	     timer resets on every redundant call. ]]
	t.test("setting the same value twice announces nothing", function()
		RunPaused.set(false)

		local count = 0
		local connection = RunPaused.onChanged(function()
			count += 1
		end)

		RunPaused.set(false)
		RunPaused.set(false)
		task.wait()
		connection:Disconnect()

		t.equal(count, 0, "a no-op set fired listeners")
	end)
end
