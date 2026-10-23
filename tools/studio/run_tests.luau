--!nocheck
--[[
	Run with execute_luau in the Server datamodel, with the game playing,
	after tools/sync_probe.py has shown Studio is current. Returns the
	summary and every failure. Answer any open card screen first (it
	pauses the run): see CLAUDE.md, "Testing over MCP".
]]
local tests = game:GetService("ServerStorage").Tests
local TestRunner = require(tests.TestRunner)
local result = TestRunner.runAll(tests)
return { TestRunner.summarise(result), result.failures }
