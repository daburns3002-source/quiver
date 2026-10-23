--!strict
--[[
	The Mythics' area attacks (`Combat/AreaStrikes`): a blast lands after
	its warning and not before, a zone ends when it should, and none of the
	time the world stands still behind a card screen counts towards either.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local AreaStrikes = require(ServerScriptService.Server.Combat.AreaStrikes)
local TestRunner = require(script.Parent.TestRunner)

local function owner(): Player
	return Players:GetPlayers()[1] or (Instance.new("Player") :: any)
end

return function(t: TestRunner.Helper)
	t.test("a blast lands after its warning, not before", function()
		AreaStrikes.clear()
		local landed: number? = nil
		AreaStrikes.strike({
			owner = owner(),
			at = Vector3.new(500, 0, 500),
			radius = 1,
			damage = 0,
			delay = 1,
			now = 0,
			impact = "MeteorImpact",
			landed = function()
				landed = 1
			end,
		})
		AreaStrikes.step(0.1)
		AreaStrikes.step(0.2)
		t.isTrue(landed == nil, "landed during its warning")
		for step = 3, 12 do
			AreaStrikes.step(step / 10)
		end
		t.isTrue(landed ~= nil, "never landed")
		AreaStrikes.clear()
	end)

	--[[ A card screen stops the server loop; on resume the meteor in the air
	     must still take the rest of its fall. ]]
	t.test("time behind a card screen does not count", function()
		AreaStrikes.clear()
		local landed = false
		AreaStrikes.strike({
			owner = owner(),
			at = Vector3.new(500, 0, 500),
			radius = 1,
			damage = 0,
			delay = 1,
			now = 0,
			impact = "MeteorImpact",
			landed = function()
				landed = true
			end,
		})
		AreaStrikes.step(0.5)
		-- Ten seconds choosing a card.
		AreaStrikes.step(10.5)
		t.isTrue(not landed, "landed the moment the world resumed")
		for step = 1, 8 do
			AreaStrikes.step(10.5 + step / 10)
		end
		t.isTrue(landed, "never landed after the pause")
		AreaStrikes.clear()
	end)

	t.test("cracked ground ends when it should, pauses aside", function()
		AreaStrikes.clear()
		AreaStrikes.zone(owner(), Vector3.new(500, 0, 500), 1, 0, 0.5, 3, 0, "Cracks")
		AreaStrikes.step(1)
		AreaStrikes.step(20) -- a pause
		local _, zones = AreaStrikes.pending()
		t.equal(zones, 1)
		for step = 1, 25 do
			AreaStrikes.step(20 + step / 10)
		end
		_, zones = AreaStrikes.pending()
		t.equal(zones, 0)
		AreaStrikes.clear()
	end)
end
