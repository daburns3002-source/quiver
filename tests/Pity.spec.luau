--!strict
--[[
	The guaranteed Mythic (`Util/Pity`): the 100th roll since the last Mythic
	is forced, and a Mythic sets the count back to 0.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the 100th roll without a Mythic is forced, not the 99th", function()
		local count = 0
		for roll = 1, 100 do
			t.equal(Pity.forced(count), roll == 100, tostring(roll))
			count = Pity.after(count, false)
		end
	end)
	t.test("a Mythic resets the count", function()
		t.equal(Pity.after(57, true), 0)
		t.equal(Pity.after(57, false), 58)
	end)
	t.test("only a pool's Mythics are picked from", function()
		local pool = {
			{ rarity = "Common", key = "a" },
			{ rarity = "Mythic", key = "b" },
			{ rarity = "Epic", key = "c" },
		}
		local mythics = Pity.mythics(pool)
		t.equal(#mythics, 1)
		t.equal(mythics[1].key, "b")
	end)
end
