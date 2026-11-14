--!strict
--[[
	The token bucket under every client-to-server remote (`Util/Throttle`,
	`Net/Inbound`): a burst at once, then a steady rate, never more.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.TestRunner)
local Throttle = require(ReplicatedStorage.Shared.Util.Throttle)

return function(t: TestRunner.Helper)
	t.test("a burst goes through at once, and the next ask does not", function()
		local bucket = Throttle.new(5, 0)
		for ask = 1, 5 do
			t.isTrue(Throttle.take(bucket, 0, 2, 5), tostring(ask))
		end
		t.isFalse(Throttle.take(bucket, 0, 2, 5))
	end)
	t.test("a script firing every frame gets the rate, not the frame rate", function()
		local rate, burst = 4, 10
		local bucket = Throttle.new(burst, 0)
		local through = 0
		for frame = 1, 600 do
			if Throttle.take(bucket, frame / 60, rate, burst) then
				through += 1
			end
		end
		-- ten seconds of asking: the burst and the rate's worth, give or take one
		t.isTrue(through <= burst + rate * 10 + 1, tostring(through))
		t.isTrue(through >= rate * 10, tostring(through))
	end)
	t.test("a person's pace never empties it", function()
		local bucket = Throttle.new(10, 0)
		for press = 1, 200 do
			t.isTrue(Throttle.take(bucket, press * 0.5, 5, 10), tostring(press))
		end
	end)
	t.test("waiting refills it no further than the burst", function()
		local bucket = Throttle.new(3, 0)
		for _ = 1, 3 do
			Throttle.take(bucket, 0, 1, 3)
		end
		local through = 0
		for _ = 1, 10 do
			if Throttle.take(bucket, 1000, 1, 3) then
				through += 1
			end
		end
		t.equal(through, 3)
	end)
	t.test("a clock that goes back gives nothing", function()
		local bucket = Throttle.new(1, 10)
		t.isTrue(Throttle.take(bucket, 10, 1, 1))
		t.isFalse(Throttle.take(bucket, 5, 1, 1))
	end)
end
