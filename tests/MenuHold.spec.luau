--!strict
--[[
	MENU's hold on the run (`Util/MenuHold`): a player who opens the panel
	now and then is always held, and a client that keeps sending "open"
	cannot hold everyone's run for ever (the audit, 2026-11-13).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuHold = require(ReplicatedStorage.Shared.Util.MenuHold)
local TestRunner = require(script.Parent.TestRunner)

local CAP, REFILL = 60, 0.25

return function(t: TestRunner.Helper)
	t.test("an open panel holds until it shuts", function()
		local state = MenuHold.new(CAP)
		t.isTrue(MenuHold.open(state, 100, CAP, REFILL))
		t.isTrue(MenuHold.holding(state, 110))
		MenuHold.close(state, 110, CAP, REFILL)
		t.isFalse(MenuHold.holding(state, 110))
	end)
	t.test("no hold outlasts the cap", function()
		local state = MenuHold.new(CAP)
		MenuHold.open(state, 0, CAP, REFILL)
		t.isTrue(MenuHold.holding(state, CAP - 0.01))
		t.isFalse(MenuHold.holding(state, CAP + 0.01))
	end)
	t.test("asking again while held does not stretch the hold", function()
		local state = MenuHold.new(CAP)
		MenuHold.open(state, 0, CAP, REFILL)
		for at = 1, 59 do
			MenuHold.open(state, at, CAP, REFILL)
		end
		t.isFalse(MenuHold.holding(state, CAP + 0.01))
	end)
	t.test("a client sending open every second holds a fifth of the time at most", function()
		local state = MenuHold.new(CAP)
		local held = 0
		local step = 0.1
		-- ten minutes, sampled every tenth of a second
		for tick = 0, 6000 do
			local now = tick * step
			if tick % 10 == 0 then
				MenuHold.open(state, now, CAP, REFILL)
			end
			if MenuHold.holding(state, now) then
				held += step
			end
		end
		-- the first full minute, then no more than the refill earns
		t.isTrue(held <= CAP + 600 * REFILL / (1 + REFILL) + 2, tostring(held))
	end)
	t.test("a player's short looks at the menu are always held", function()
		local state = MenuHold.new(CAP)
		-- ten seconds in the menu, then a minute of play, over and over
		for round = 0, 20 do
			local at = round * 70
			t.isTrue(MenuHold.open(state, at, CAP, REFILL), tostring(round))
			t.isTrue(MenuHold.holding(state, at + 9.9), tostring(round))
			MenuHold.close(state, at + 10, CAP, REFILL)
		end
	end)
	t.test("the budget comes back while the run plays, up to the cap", function()
		local state = MenuHold.new(CAP)
		MenuHold.open(state, 0, CAP, REFILL)
		MenuHold.close(state, CAP, CAP, REFILL)
		t.isFalse(MenuHold.open(state, CAP, CAP, REFILL))
		-- long after: a whole cap again, and no more
		t.isTrue(MenuHold.open(state, 10000, CAP, REFILL))
		t.isTrue(MenuHold.holding(state, 10000 + CAP - 0.01))
		t.isFalse(MenuHold.holding(state, 10000 + CAP + 0.01))
	end)
end
