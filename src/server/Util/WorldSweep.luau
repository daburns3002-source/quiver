--!strict
--[[
	Clears whatever was saved into Workspace before the game builds its own
	world (owner, 2026-11-20, after the live game showed "a big web in the
	middle" and "random models in the level": "run it new every time no
	saved instances").

	The game builds everything it shows from code: the lobby, the arena,
	enemies, pets and effects. Nothing it needs is saved in the place's
	Workspace. But a place published from Studio carries whatever was left
	there: import staging (`TripoImports`), render rigs (`Scene`,
	`AuxScene`), weapon and pet-effect previews, Endless gates. They stood
	in the middle of every arena, because the arena is built at the origin
	where they were posed. So the server takes them out first thing, in
	every server and in Studio's Play too, and Studio's Play is then what a
	live player sees. Only the Terrain, the Camera and players' characters
	stay. The saved place itself is untouched: this runs on the server's copy.
]]

local Players = game:GetService("Players")

local WorldSweep = {}

--[[ The classes a place's Workspace always has. ]]
local KEEP: { [string]: boolean } = {
	Terrain = true,
	Camera = true,
}

--[[ Destroys every child of `container` that is not a Terrain, a Camera or
     a player's character (Studio's Play can spawn one before this runs),
     and returns their names, in the order found. ]]
function WorldSweep.sweep(container: Instance): { string }
	local removed = {}
	for _, child in container:GetChildren() do
		if not KEEP[child.ClassName] and not Players:GetPlayerFromCharacter(child) then
			table.insert(removed, child.Name)
			child:Destroy()
		end
	end
	return removed
end

--[[ The scripts Roblox itself puts into a live server's script containers
     before the game's code runs: they are the engine's, not leftovers. The
     first live sweep took `RbxCharacterSounds` out of StarterPlayerScripts,
     and players lost their footsteps, jumps and landings (2026-11-25). The
     rest are the camera and controls (`PlayerModule`, `PlayerScriptsLoader`),
     the character's walk animations and healing (`Animate`, `Health`) and
     the legacy chat (`ChatScript`, `BubbleChat`, `ChatServiceRunner`). ]]
WorldSweep.ROBLOX_OWN = table.freeze({
	RbxCharacterSounds = true,
	PlayerModule = true,
	PlayerScriptsLoader = true,
	Animate = true,
	Health = true,
	ChatScript = true,
	BubbleChat = true,
	ChatServiceRunner = true,
} :: { [string]: boolean })

--[[ Destroys every child of each container that is neither in its `keep`
     set nor one of Roblox's own scripts (`ROBLOX_OWN`), and returns their
     full names. For the script containers of a live server (`Main.server`):
     only the repo's own code and the engine's may run there, never a test
     autopilot or an old script left in Studio when it was published. ]]
function WorldSweep.only(containers: { [Instance]: { [string]: boolean } }): { string }
	local removed = {}
	for container, keep in containers do
		for _, child in container:GetChildren() do
			if not keep[child.Name] and not WorldSweep.ROBLOX_OWN[child.Name] then
				table.insert(removed, container.Name .. "." .. child.Name)
				child:Destroy()
			end
		end
	end
	return removed
end

return WorldSweep
