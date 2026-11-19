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
		local result, code = CodeRules.check(LIST, {}, "HELLO", today)
		t.equal(result, "Ok")
		t.isTrue(code ~= nil and code.prize.coins == 100)
		t.equal((CodeRules.check(LIST, { HELLO = true }, "HELLO", today)), "Used")
		t.equal((CodeRules.check(LIST, {}, "NOPE", today)), "Unknown")
		t.equal(
			(CodeRules.check(LIST, {}, "BROKEN", today)),
			"Unknown",
			"a broken entry pays nothing"
		)
		local last = CodeRules.day("2026-11-01") :: number
		t.equal((CodeRules.check(LIST, {}, "OLD", last)), "Ok", "its last day still works")
		t.equal((CodeRules.check(LIST, {}, "OLD", last + 1)), "Expired")
		t.equal(
			(CodeRules.check(LIST, { OLD = true }, "OLD", last + 1)),
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
	end)
end
