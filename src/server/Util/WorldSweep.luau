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

return WorldSweep
