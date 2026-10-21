--!strict
--[[
	A very small test runner.

	It exists because the four CI gates cannot catch the bugs this project
	actually produces. Selene, StyLua, `rojo build` and `luau-lsp` were all
	green on a charger that deadlocked against a pillar, a burrower that dived
	exactly once, and a telegraph that drew a line its shot did not follow.
	Every one of those was geometry or state, and every one needed the game to
	run before it showed up.

	These tests run *inside* Roblox rather than on a bare Luau runtime, because
	the code under test speaks Vector3 and CFrame and there is no honest way to
	stub those. They are driven over MCP with a single call, which makes the
	edit-verify loop one round trip instead of a playtest.

	Specs live beside this module and return a function taking the `t` helper:

		return function(t)
			t.test("a spread of three keeps one shot on centre", function()
				t.near(specs[2].angleOffset, 0, 1e-6)
			end)
		end

	Deliberately not a framework. No lifecycle hooks, no mocks, no async. If a
	test needs any of that, the thing it is testing is probably not pure enough
	to be worth a unit test yet.
]]

local TestRunner = {}

export type Helper = {
	test: (name: string, body: () -> ()) -> (),
	equal: (actual: any, expected: any, message: string?) -> (),
	near: (actual: number, expected: number, tolerance: number, message: string?) -> (),
	isTrue: (value: any, message: string?) -> (),
	isFalse: (value: any, message: string?) -> (),
	isNil: (value: any, message: string?) -> (),
	notNil: (value: any, message: string?) -> (),
}

export type Result = {
	passed: number,
	failed: number,
	failures: { string },
	names: { string },
}

local function describe(value: any): string
	if typeof(value) == "Vector3" or typeof(value) == "Vector2" then
		return typeof(value) .. "(" .. tostring(value) .. ")"
	end

	return `{typeof(value)}({tostring(value)})`
end

--[[
	Builds the helper handed to one spec.

	Assertions raise, so the first failure in a test ends that test and no
	other. That is the right trade for a suite this size: a cascade of
	follow-on failures from one broken assumption is noise, not information.
]]
local function makeHelper(suite: string, result: Result): Helper
	local currentTest = "?"

	local function fail(message: string, detail: string?)
		local full = `{suite} › {currentTest}: {message}`
		if detail then
			full ..= ` ({detail})`
		end

		error(full, 0)
	end

	local helper: Helper

	helper = {
		test = function(name: string, body: () -> ())
			currentTest = name
			table.insert(result.names, `{suite} › {name}`)

			--[[ Cast because Luau types `pcall` of a void function as
			     returning only the boolean, which loses the error. ]]
			local ok, err = pcall(body :: any)

			if ok then
				result.passed += 1
				return
			end

			result.failed += 1
			table.insert(result.failures, tostring(err))
		end,

		equal = function(actual: any, expected: any, message: string?)
			if actual ~= expected then
				fail(
					message or "values differ",
					`expected {describe(expected)}, got {describe(actual)}`
				)
			end
		end,

		near = function(actual: number, expected: number, tolerance: number, message: string?)
			if typeof(actual) ~= "number" then
				fail(message or "expected a number", describe(actual))
				return
			end

			if math.abs(actual - expected) > tolerance then
				fail(
					message or "value out of tolerance",
					`expected {expected} ± {tolerance}, got {actual}`
				)
			end
		end,

		isTrue = function(value: any, message: string?)
			if value ~= true then
				fail(message or "expected true", describe(value))
			end
		end,

		isFalse = function(value: any, message: string?)
			if value ~= false then
				fail(message or "expected false", describe(value))
			end
		end,

		isNil = function(value: any, message: string?)
			if value ~= nil then
				fail(message or "expected nil", describe(value))
			end
		end,

		notNil = function(value: any, message: string?)
			if value == nil then
				fail(message or "expected a value, got nil")
			end
		end,
	}

	return helper
end

--[[
	Runs every `*.spec` module under `container`.

	A spec that fails to load is a failure like any other rather than an error
	that stops the run, so one broken file cannot hide the state of the rest.
]]
function TestRunner.runAll(container: Instance): Result
	local result: Result = {
		passed = 0,
		failed = 0,
		failures = {},
		names = {},
	}

	local specs: { ModuleScript } = {}

	for _, child in container:GetDescendants() do
		if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") then
			table.insert(specs, child)
		end
	end

	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	for _, spec in specs do
		local suite = string.gsub(spec.Name, "%.spec$", "")

		local loaded, body = pcall(require, spec)

		if not loaded then
			result.failed += 1
			table.insert(result.failures, `{suite}: failed to load — {tostring(body)}`)
			continue
		end

		if typeof(body) ~= "function" then
			result.failed += 1
			table.insert(result.failures, `{suite}: expected the module to return a function`)
			continue
		end

		local ok, err = pcall(body, makeHelper(suite, result))

		if not ok then
			result.failed += 1
			table.insert(result.failures, `{suite}: raised outside a test — {tostring(err)}`)
		end
	end

	return result
end

--[[ A one-line summary, so a run can be read at a glance from a tool result. ]]
function TestRunner.summarise(result: Result): string
	if result.failed == 0 then
		return `PASS — {result.passed} tests`
	end

	return `FAIL — {result.failed} failed, {result.passed} passed`
end

return TestRunner
