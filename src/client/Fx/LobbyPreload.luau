--!strict
--[[
	The lobby's pictures and models, fetched as soon as the player is in it
	(owner, 2026-11-08: "preloading as soon as the player gets in the lobby so
	there are no stutters or times where the models are not textured").

	The shop, gear, hatchery and dex pictures, and every pet model those
	screens stand up in a viewport. The eggs' and chests' own meshes and
	textures are `UI/Reveal.preloadModels`, which runs at start.

	Content only, in a task of its own, so nothing here can hold up a frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

--[[ The server builds the pet models one by one: the folder counts as whole
     once it has stopped growing for this long, or after `PETS_LIMIT`. ]]
local PETS_QUIET = 2
local PETS_LIMIT = 40

local LobbyPreload = {}

local function pictures(): { string }
	local enemies: { string } = {}
	for _, enemy in NewEnemies.enemies do
		if enemy.picture and enemy.picture ~= "" then
			table.insert(enemies, enemy.picture)
		end
	end
	local all: { any } = {
		GearAssets,
		ShopAssets,
		GearUiAssets,
		HatchUiAssets,
		OptcAssets,
		Dex,
		LoadingScreen,
		LobbyConfig.portalModels,
		enemies,
	}
	return Preload.idsIn(all, GearAssets.models)
end

local function fetchPets()
	local folder = ReplicatedStorage:WaitForChild("PetPreview", PETS_LIMIT)
	if not folder then
		return
	end
	local deadline = os.clock() + PETS_LIMIT
	local count, changed = -1, os.clock()
	while os.clock() < deadline and os.clock() - changed < PETS_QUIET do
		local now = #folder:GetChildren()
		if now ~= count then
			count, changed = now, os.clock()
		end
		task.wait(0.25)
	end
	Preload.fetchInstances({ folder })
	log.info("%d pet models fetched", count)
end

function LobbyPreload.start()
	task.spawn(function()
		while Workspace:GetAttribute("InLobby") ~= true do
			Workspace:GetAttributeChangedSignal("InLobby"):Wait()
		end
		task.spawn(fetchPets)
		local started = os.clock()
		log.info("%d pictures in %.1f s", Preload.fetch(pictures()), os.clock() - started)
	end)
end

return LobbyPreload
