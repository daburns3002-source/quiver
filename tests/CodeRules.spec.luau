--!strict
--[[
	The CODES box's rules (`Util/CodeRules`): typed text is read the same
	whatever its case or spaces, a code works once a player and not after
	its last day, the answers say which, and the server's real list
	(`Data/CodeList`) is well formed and never reaches a client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CodeRules = require(ReplicatedStorage.Shared.Util.CodeRules)
local Config = require(ReplicatedStorage.Shared.Config.Codes)

local LIST: { [string]: CodeRules.Code } = {
	HELLO = { prize = { coins = 100 } },
	OLD = { prize = { gems = 5 }, expires = "2026-11-01" },
	BROKEN = { prize = { coins = 0 } } :: any,
}
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("typed text is read whatever its case and spaces", function()
		t.equal(CodeRules.normalise("hello"), "HELLO")
		t.equal(CodeRules.normalise("  He Llo \t"), "HELLO")
		t.equal(CodeRules.normalise(""), nil)
		t.equal(CodeRules.normalise("   "), nil)
		t.equal(CodeRules.normalise("HI!"), nil, "only letters and digits")
		t.equal(CodeRules.normalise("CAFÉ"), nil, "no letters outside A to Z")
		t.equal(CodeRules.normalise(42), nil)
		t.equal(CodeRules.normalise(string.rep("A", Config.maxLength + 1)), nil)
		t.equal(
			CodeRules.normalise(string.rep("A", Config.maxLength)),
			string.rep("A", Config.maxLength)
		)
	end)

	t.test("a date is the day number the rewards count in", function()
		t.equal(CodeRules.day("1970-01-01"), 0)
		t.equal(CodeRules.day("1970-01-02"), 1)
		-- 2026-11-18 00:00 UTC is 1794960000 seconds
		t.equal(CodeRules.day("2026-11-18"), 1794960000 // 86400)
		t.equal(CodeRules.day("2028-02-29"), (CodeRules.day("2028-03-01") :: number) - 1)
		t.equal(CodeRules.day("2027-02-29"), nil, "not a leap year")
		t.equal(CodeRules.day("2026-13-01"), nil)
		t.equal(CodeRules.day("26-11-18"), nil)
		t.equal(CodeRules.day(nil), nil)
	end)

	t.test("a code works once, and not after its last day", function()
		local today = CodeRules.day("2026-11-18") :: number
		local result, code = CodeRules.check(LIST, {}, "HELLO", today, 0)
		t.equal(result, "Ok")
		t.isTrue(code ~= nil and code.prize.coins == 100)
		t.equal((CodeRules.check(LIST, { HELLO = true }, "HELLO", today, 0)), "Used")
		t.equal((CodeRules.check(LIST, {}, "NOPE", today, 0)), "Unknown")
		t.equal(
			(CodeRules.check(LIST, {}, "BROKEN", today, 0)),
			"Unknown",
			"a broken entry pays nothing"
		)
		local last = CodeRules.day("2026-11-01") :: number
		t.equal((CodeRules.check(LIST, {}, "OLD", last, 0)), "Ok", "its last day still works")
		t.equal((CodeRules.check(LIST, {}, "OLD", last + 1, 0)), "Expired")
		t.equal(
			(CodeRules.check(LIST, { OLD = true }, "OLD", last + 1, 0)),
			"Used",
			"used says more than expired"
		)
	end)

	t.test("every answer is its own words, and the prize is said", function()
		local seen: { [string]: boolean } = {}
		for _, result in { "Ok", "Unknown", "Expired", "Used", "Empty", "Slow" } do
			local words = CodeRules.answer(result, { coins = 1 })
			t.isTrue(#words > 0 and not seen[words], result)
			seen[words] = true
		end
		t.equal(
			CodeRules.prizeWords({ coins = 500, gems = 25, eggs = 1 }),
			"500 COINS + 25 GEMS + 1 EGG"
		)
		t.equal(CodeRules.prizeWords({ coins = 1000 }), "1,000 COINS")
		t.isTrue(string.find(CodeRules.answer("Ok", { crates = 2 }), "2 CRATES", 1, true) ~= nil)
	end)

	t.test("the server's list is well formed and stays on the server", function()
		local holder = ServerScriptService:FindFirstChild("Server")
		local data = holder and holder:FindFirstChild("Data")
		local module = data and data:FindFirstChild("CodeList")
		t.isTrue(
			module ~= nil and module:IsA("ModuleScript"),
			"Data/CodeList is in ServerScriptService"
		)
		t.isTrue(
			ReplicatedStorage:FindFirstChild("CodeList", true) == nil,
			"no code list replicates"
		)
		local list = require(module :: ModuleScript) :: { [string]: CodeRules.Code }
		local n = 0
		for word, code in list do
			n += 1
			t.equal(CodeRules.normalise(word), word, `{word} is written as it is typed`)
			t.isTrue(CodeRules.valid(code), `{word} has a prize and a real date`)
		end
		t.isTrue(n > 0, "at least one code")
		-- every like goal is its own number, so the box never has two at once
		local goals: { [number]: string } = {}
		for word, code in list do
			if code.likes then
				t.isTrue(goals[code.likes] == nil, `{word} shares a like goal`)
				goals[code.likes] = word
			end
		end
	end)

	t.test("a like-goal code does not exist until its goal is reached", function()
		local goals: { [string]: CodeRules.Code } = {
			FIRST = { prize = { gems = 1 }, likes = 100 },
			SECOND = { prize = { gems = 2 }, likes = 500 },
			GONE = { prize = { gems = 3 }, likes = 50, expires = "2026-01-01" },
		}
		local today = CodeRules.day("2026-11-20") :: number
		t.equal((CodeRules.check(goals, {}, "FIRST", today, 99)), "Unknown", "not yet: unknown")
		t.equal((CodeRules.check(goals, {}, "FIRST", today, 100)), "Ok")
		t.equal((CodeRules.check(goals, { FIRST = true }, "FIRST", today, 900)), "Used")
		t.isFalse(CodeRules.valid({ prize = { gems = 1 }, likes = 0 }))
		t.isFalse(CodeRules.valid({ prize = { gems = 1 }, likes = 2.5 }))

		local nextGoal, newest = CodeRules.likeGoal(goals, 0, today)
		t.equal(nextGoal, 100, "the expired one is left out")
		t.equal(newest, nil)
		nextGoal, newest = CodeRules.likeGoal(goals, 120, today)
		t.equal(nextGoal, 500)
		t.equal(newest, "FIRST")
		nextGoal, newest = CodeRules.likeGoal(goals, 9000, today)
		t.equal(nextGoal, nil)
		t.equal(newest, "SECOND", "the highest reached is the newest")

		t.equal(CodeRules.commas(10000), "10,000")
		t.equal(CodeRules.commas(250), "250")
		t.equal(CodeRules.likeLine(nil, nil), "")
		t.isTrue(string.find(CodeRules.likeLine(1000, nil), "1,000", 1, true) ~= nil)
		t.isTrue(string.find(CodeRules.likeLine(1000, "FIRST"), "FIRST", 1, true) ~= nil)
		t.isTrue(string.find(CodeRules.likeLine(nil, "SECOND"), "SECOND", 1, true) ~= nil)
	end)
end
