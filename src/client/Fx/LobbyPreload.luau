--!strict
--[[
	The lobby's pictures and models, ready as soon as the player is in it
	(owner, 2026-11-08: "preloading as soon as the player gets in the lobby so
	there are no stutters or times where the models are not textured").

	Three steps, because a download alone still leaves a screen blank the first
	time it opens (`Preload`, fetching and warming):
	- every shop, gear, hatchery and dex picture is fetched;
	- the most important of them are kept drawn while in the lobby, as many as
	  the device affords (`DeviceTiers.warmLobbyImages`), and dropped for a run;
	- every pet and weapon the screens stand up in a viewport is fetched, then
	  drawn once out of sight.

	The eggs' and chests' own meshes are `UI/Reveal.preloadModels`, which runs at
	start. Content only, in tasks of their own, so nothing here can hold up a
	frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Device)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local GearUiAssets = require(ReplicatedStorage.Shared.Config.GearUiAssets)
local HatchUiAssets = require(ReplicatedStorage.Shared.Config.HatchUiAssets)
local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local OptcAssets = require(ReplicatedStorage.Shared.Config.OptcAssets)
local Preload = require(script.Parent.Parent.Preload)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local log = Log.forTag("LobbyPreload")

--[[ The server builds the previews one by one: a folder counts as whole once it
     has stopped growing for this long, or after `FOLDER_LIMIT`. ]]
local FOLDER_QUIET = 2
local FOLDER_LIMIT = 40
local WARM = "Lobby"

local LobbyPreload = {}

--[[ Everything to fetch, most important first: the order the warm budget is
     spent in. Mesh ids are left out: fetched as a picture, one only errors. ]]
local function pictures(): { string }
	local models: { string } = {}
	for _, spec in GearAssets.models.eggs do
		table.insert(models, spec.texture)
	end
	for _, spec in GearAssets.models.chests do
		local parts = spec.parts
		if parts then
			table.insert(models, parts.base.texture)
			table.insert(models, parts.lid.texture)
		end
	end
	local enemies: { string } = {}
	for _, enemy in NewEnemies.enemies do
		if enemy.picture and enemy.picture ~= "" then
			table.insert(enemies, enemy.picture)
		end
	end
	local portals: { string } = {}
	for _, spec in LobbyConfig.portalModels do
		table.insert(portals, spec.texture)
		table.insert(portals, spec.vortex)
	end
	local all: { any } = {
		models,
		GearUiAssets,
		HatchUiAssets,
		OptcAssets,
		ShopAssets,
		GearAssets,
		Dex,
		enemies,
		LoadingScreen,
		portals,
	}
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, group in all do
		for _, id in Preload.idsIn(group, GearAssets.models) do
			if not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	return out
end

--[[ A preview folder once the server has finished filling it. ]]
local function settled(name: string): Instance?
	local folder = ReplicatedStorage:WaitForChild(name, FOLDER_LIMIT)
	if not folder then
		return nil
	end
	local deadline = os.clock() + FOLDER_LIMIT
	local count, changed = -1, os.clock()
	while os.clock() < deadline and os.clock() - changed < FOLDER_QUIET do
		local now = #folder:GetChildren()
		if now ~= count then
			count, changed = now, os.clock()
		end
		task.wait(0.25)
	end
	return folder
end

function LobbyPreload.start()
	local wanted = pictures()
	local function inLobby(): boolean
		return Workspace:GetAttribute("InLobby") == true
	end
	local function warm()
		local room = math.min(Device.tier().warmLobbyImages, #wanted)
		Preload.warm(WARM, table.move(wanted, 1, room, 1, {}) :: { string })
	end
	local function previews()
		local folders: { Instance } = {}
		local models: { Model } = {}
		local textures: { [string]: boolean } = {}
		for _, name in { "PetPreview", "WeaponPreview" } do
			local folder = settled(name)
			if folder then
				table.insert(folders, folder)
				for _, child in folder:GetChildren() do
					if child:IsA("Model") then
						table.insert(models, child)
					end
				end
				for _, part in folder:GetDescendants() do
					if part:IsA("MeshPart") and part.TextureID ~= "" then
						textures[part.TextureID] = true
					end
				end
			end
		end
		Preload.fetchInstances(folders)
		for id in textures do
			table.insert(wanted, id)
		end
		if inLobby() then
			warm()
		end
		Preload.drawModels(models)
		log.info("%d preview models fetched and drawn", #models)
	end
	local started = false
	local function refresh()
		if not inLobby() then
			Preload.coolAll(WARM)
			return
		end
		warm()
		if not started then
			started = true
			task.spawn(previews)
			task.spawn(function()
				local began = os.clock()
				log.info("%d pictures in %.1f s", Preload.fetch(wanted), os.clock() - began)
			end)
		end
	end
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(refresh)
	refresh()
end

return LobbyPreload
