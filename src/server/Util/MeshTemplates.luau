--!strict
--[[
	Loads uploaded meshes into MeshPart templates, all at once.

	CreateMeshPartAsync yields while it fetches. Asked for one mesh at a time,
	the server spent about 10 seconds at boot on Level 1's 47 meshes before it
	built the first room (owner, 2026-10-22: "why when i start the playtest
	it takes like 10 seconds to load everything"). Every request is started
	together and waited on together, so boot takes about as long as the
	slowest single mesh.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("MeshTemplates")

local MeshTemplates = {}

--[[ A template for every id in `ids`, keyed by id. A mesh that fails to
     load is warned about and left out; callers fall back without it. ]]
function MeshTemplates.load(ids: { string }): { [string]: MeshPart }
	local templates: { [string]: MeshPart } = {}
	local wanted: { [string]: boolean } = {}
	for _, id in ids do
		wanted[id] = true
	end

	local pending = 0
	local current = coroutine.running()
	local waiting = false

	for id in wanted do
		pending += 1
		task.spawn(function()
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(id, {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
			end)
			if ok and result then
				templates[id] = result
			else
				log.warn("mesh %s did not load: %s", id, tostring(result))
			end

			pending -= 1
			if pending == 0 and waiting then
				task.spawn(current)
			end
		end)
	end

	if pending > 0 then
		waiting = true
		coroutine.yield()
	end

	return templates
end

return MeshTemplates
