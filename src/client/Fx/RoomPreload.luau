--!strict
--[[
	Loads the next room while this one is played (owner, 2026-10-26: "next
	rooms need to preload while playing current room (very important) this
	will help a lot with stuttering and load times").

	The server builds the next room mid-fight and parks it in
	`ReplicatedStorage.NextArena` (`Arena.prepare`), so its parts reach this
	client during the fight and walking through the door only moves them into
	Workspace. Here everything they draw is fetched as they arrive: the
	arena's meshes and textures, and for the enemies the room brings (its
	`Roster` attribute) their meshes, their NEW ENEMY! picture and sheet, a
	boss's banner icon and the boss music. Sounds are all loaded at join
	(`SoundFx.preload`), and enemies animate from data, with no animation
	assets to fetch.

	Content only: nothing is drawn or kept that the next room would not hold
	anyway, so a phone carries no more than that room's own content, a
	little earlier.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Music = require(ReplicatedStorage.Shared.Config.Music)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)

local log = Log.forTag("RoomPreload")

local RoomPreload = {}

--[[ Content already asked for, so a room of the same enemies asks for
     nothing again. ]]
local asked: { [string]: boolean } = {}

local function add(list: { string }, id: any)
	if type(id) == "string" and id ~= "" and not asked[id] then
		asked[id] = true
		table.insert(list, id)
	end
end

local function importedRows(model: string): { any }
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ImportedModels")
	local module = folder and folder:FindFirstChild(model)
	if not module or not module:IsA("ModuleScript") then
		return {}
	end
	local ok, rows = pcall(require :: any, module)
	return if ok and type(rows) == "table" then rows else {}
end

--[[ Every enemy config by its `displayName`, for the bosses' titles. ]]
local function configsByName(): { [string]: Balance.EnemyConfig }
	local out: { [string]: Balance.EnemyConfig } = {}
	for _, config in Balance.Enemies :: any do
		if type(config) == "table" and type(config.displayName) == "string" then
			out[config.displayName] = config
		end
	end
	return out
end

--[[ The content ids an enemy kind draws, by `EnemyConfig.displayName`. ]]
function RoomPreload.enemyContent(
	name: string,
	configs: { [string]: Balance.EnemyConfig }?
): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function put(id: any)
		if type(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end

	local design = (EnemyDesigns :: any)[name]
	if type(design) == "table" then
		for _, spec in design do
			if type(spec) == "table" then
				put(spec.meshId)
				put(spec.textureId)
			end
		end
	end
	local imported = (EnemyDesigns.Imported :: any)[name]
	if type(imported) == "table" and type(imported.model) == "string" then
		for _, row in importedRows(imported.model) do
			put(row.meshId)
			put(row.textureId)
		end
	end

	local met = (NewEnemies.enemies :: any)[name]
	if met then
		put(met.picture)
		local sheet = (NewEnemies.sheets :: any)[met.area]
		if sheet then
			put(sheet.top)
			put(sheet.bottom)
		end
	end

	local config = (configs or configsByName())[name]
	local boss = config and config.boss
	if boss then
		local banner = (BossBanners.bosses :: any)[boss.title]
		put(banner and banner.icon)
		for _, track in Music.playlists.Boss do
			put(track.id)
		end
	end
	return list
end

local function load(arena: Instance)
	local began = os.clock()
	local ids: { string } = {}
	local configs = configsByName()
	local roster = arena:GetAttribute("Roster")
	if type(roster) == "string" then
		for name in string.gmatch(roster, "[^,]+") do
			for _, id in RoomPreload.enemyContent(name, configs) do
				add(ids, id)
			end
		end
	end

	task.spawn(function()
		local ok, problem = pcall(function()
			-- the arena's own meshes and textures, then the enemies'
			ContentProvider:PreloadAsync({ arena })
			if #ids > 0 then
				ContentProvider:PreloadAsync(ids)
			end
		end)
		if not ok then
			log.warn("next room did not preload: %s", tostring(problem))
			return
		end
		log.info("next room loaded in %.2f s (%d enemy assets)", os.clock() - began, #ids)
		arena:SetAttribute("PreloadedIn", os.clock() - began)
	end)
end

function RoomPreload.start()
	local function watch(park: Instance)
		if park.Name ~= "NextArena" then
			return
		end
		for _, child in park:GetChildren() do
			load(child)
		end
		park.ChildAdded:Connect(load)
	end
	for _, child in ReplicatedStorage:GetChildren() do
		watch(child)
	end
	ReplicatedStorage.ChildAdded:Connect(watch)
end

return RoomPreload
