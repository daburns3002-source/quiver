--!strict
--[[
	Has a weapon's texture ready before the weapon is in a hand (owner,
	2026-11-14: "preload the weapon textures so they dont show up pale").

	A one-mesh weapon carries its colours in a texture (`Config/Weapons`
	`textureId`). The lobby fetched every weapon's in the background and
	dropped them as a run began (`Fx/LobbyPreload`), which is the moment the
	weapon is first held: its mesh was drawn bare for a few seconds (seen in
	Studio on the Golden Staff, 2026-11-14).

	So, with `Preload`:
	- **Kept warm, in the lobby and in a run:** the textures of the weapon
	  each player holds or will hold next: every player's `Weapon` attribute
	  (the server's, `RunSession.applyLoadout`) and this player's saved
	  `equipped`, which changes the moment a weapon is given or chosen, well
	  before the run that holds it. A handful of pictures at most.
	- **Fetched, not kept:** every weapon this player owns, as the profile
	  comes and whenever it changes, so choosing another at Gear has its
	  picture already downloaded.

	Content only: nothing here decides what is held.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local WeaponContent = require(ReplicatedStorage.Shared.Util.WeaponContent)

local Preload = require(script.Parent.Parent.Preload)

local WeaponPreload = {}

local WARM = "Weapons"
local ATTRIBUTE = "Weapon"

--[[ This player's saved weapon (`SaveSchema.equipped`), nil until the
     profile has come or for the class's own. ]]
local saved: string? = nil
--[[ What is warm now, so what is no longer wanted can be let go. ]]
local warm: { string } = {}

local function refresh()
	local names: { string } = {}
	if saved then
		table.insert(names, saved)
	end
	for _, player in Players:GetPlayers() do
		local held = player:GetAttribute(ATTRIBUTE)
		if type(held) == "string" then
			table.insert(names, held)
		end
	end
	local wanted = WeaponContent.texturesOf(names)
	local gone: { string } = {}
	for _, id in warm do
		if not table.find(wanted, id) then
			table.insert(gone, id)
		end
	end
	Preload.cool(WARM, gone)
	Preload.warm(WARM, wanted)
	Preload.fetchAsync(wanted)
	warm = wanted
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh)
	refresh()
end

function WeaponPreload.start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(profile)
		if type(profile) ~= "table" then
			return
		end
		saved = if type(profile.equipped) == "string" then profile.equipped else nil
		refresh()
		if type(profile.weapons) == "table" then
			Preload.fetchAsync(WeaponContent.texturesOf(profile.weapons))
		end
	end)
end

return WeaponPreload
