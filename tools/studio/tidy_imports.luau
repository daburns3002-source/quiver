--!nocheck
--[[
	Run with execute_luau in the Edit datamodel to move every Studio import
	out of the Workspace and into ServerStorage.Imports, which is neither
	replicated nor drawn. Returns JSON: how many models moved, how many
	instances that was, and what is left in the Workspace.

	`docs/PIPELINES.md` has said since 2026-10-24 that an import moves there
	as soon as a dump has read it, and that only fresh, not-yet-dumped
	imports belong in the Workspace. Nothing enforced it, so it happened
	twice: 65 models by 2026-10-24 (60 FPS down to 26) and 122 more by
	2026-11-03 (11,314 instances). Hence a command rather than a habit.

	It is safe to run at any time. Nothing the game draws lives in the
	Workspace at rest -- every arena, lobby station, enemy, pet and weapon
	is built from `Config` when a run or the lobby starts -- so a tidy place
	holds only Camera and Terrain. Moving rather than deleting keeps the
	imports dumpable: both dump scripts read ServerStorage.Imports too.

	**Studio does not save itself.** The owner has to save the place
	afterwards, or the move is gone when Studio closes.
]]

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local imports = ServerStorage:FindFirstChild("Imports")
if not imports then
	imports = Instance.new("Folder")
	imports.Name = "Imports"
	imports.Parent = ServerStorage
end

local moved, instances, names = 0, 0, {}
for _, child in workspace:GetChildren() do
	--[[ Camera and Terrain are the Workspace's own and have no business in
	     a folder. Everything else at the top of a resting Workspace is an
	     import somebody left behind. ]]
	if not child:IsA("Camera") and not child:IsA("Terrain") then
		instances += #child:GetDescendants() + 1
		moved += 1
		table.insert(names, child.Name)
		child.Parent = imports
	end
end

local left = {}
for _, child in workspace:GetChildren() do
	table.insert(left, `{child.ClassName} {child.Name}`)
end

return HttpService:JSONEncode({
	moved = moved,
	instancesMoved = instances,
	movedNames = names,
	workspaceNow = left,
	importsNow = #imports:GetChildren(),
	note = "Save the place in Studio or this is lost.",
})
