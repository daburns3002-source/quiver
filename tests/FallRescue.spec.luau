--!strict
--[[
	A body under a room's floor (`Server/Run/FallRescue`): one standing on
	the floor or jumping stays where it is; one on the lobby's lawn under
	the arena (2026-11-26, live 1155: only its ring showed) has fallen.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local FallRescue = require(ServerScriptService.Server.Run.FallRescue)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a body standing on the floor has not fallen", function()
		t.isFalse(FallRescue.fallen(3))
		t.isFalse(FallRescue.fallen(0))
	end)

	t.test("a body in the air has not fallen", function()
		t.isFalse(FallRescue.fallen(12))
	end)

	t.test("a body on the lawn under the arena has fallen", function()
		t.isTrue(FallRescue.fallen(-14))
	end)

	t.test("a body still falling has fallen", function()
		t.isTrue(FallRescue.fallen(-480))
	end)
end
