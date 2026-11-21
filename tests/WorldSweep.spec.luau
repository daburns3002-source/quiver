--!strict
--[[
	A place's saved Workspace leftovers never reach a player
	(`Server/Util/WorldSweep`): everything goes but the Terrain and the
	Camera.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.TestRunner)
local WorldSweep = require(ServerScriptService.Server.Util.WorldSweep)

return function(t: TestRunner.Helper)
	t.test("leftovers go, the Terrain and the Camera stay", function()
		local world = Instance.new("Folder")
		local web = Instance.new("Model")
		web.Name = "fx_pet_crown_shockwave"
		web.Parent = world
		local imports = Instance.new("Folder")
		imports.Name = "TripoImports"
		imports.Parent = world
		local part = Instance.new("Part")
		part.Name = "Stray"
		part.Parent = world
		local camera = Instance.new("Camera")
		camera.Parent = world

		local removed = WorldSweep.sweep(world)

		t.equal(#removed, 3, "three leftovers removed")
		t.isNil(world:FindFirstChild("fx_pet_crown_shockwave"))
		t.isNil(world:FindFirstChild("TripoImports"))
		t.isNil(world:FindFirstChild("Stray"))
		t.equal(camera.Parent, world, "the camera stays")
		world:Destroy()
	end)

	t.test("an empty world has nothing to take", function()
		local world = Instance.new("Folder")
		t.equal(#WorldSweep.sweep(world), 0)
		world:Destroy()
	end)
end
