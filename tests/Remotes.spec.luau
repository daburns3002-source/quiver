--!strict
--[[
	Remote names.

	Remotes are looked up by string, so a typo is not a type error — it is a
	`WaitForChild` that hangs for ten seconds and then an assert, at runtime,
	on one side only. The module exists to turn that into a missing key; these
	tests make sure the keys themselves stay honest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TestRunner = require(script.Parent.TestRunner)

--[[ The functions on the module, which are not remote names. ]]
local NOT_NAMES = {
	event = true,
}

return function(t: TestRunner.Helper)
	local names: { [string]: string } = {}

	for key, value in Remotes :: any do
		if typeof(value) == "string" and not NOT_NAMES[key] then
			names[key] = value
		end
	end

	t.test("there are remotes declared at all", function()
		local count = 0
		for _ in names do
			count += 1
		end

		t.isTrue(count > 0, "no remote names found")
	end)

	--[[
		Every remote is declared as `Remotes.Foo = "Foo"`. Keeping the key and
		the value identical means the name in code and the instance name in
		ReplicatedStorage can never drift apart, and a search for either finds
		both.
	]]
	t.test("each remote's key matches its value", function()
		for key, value in names do
			t.equal(value, key, `Remotes.{key} is named "{value}"`)
		end
	end)

	t.test("no two remotes share a name", function()
		local seen: { [string]: string } = {}

		for key, value in names do
			local previous = seen[value]
			t.isNil(previous, `{key} and {tostring(previous)} share the name "{value}"`)
			seen[value] = key
		end
	end)

	t.test("every name is a usable instance name", function()
		for key, value in names do
			t.isTrue(#value > 0, `{key} has an empty name`)
			t.isTrue(
				string.match(value, "^[%a_][%w_]*$") ~= nil,
				`{key} has a name that is awkward to look up: "{value}"`
			)
		end
	end)
end
