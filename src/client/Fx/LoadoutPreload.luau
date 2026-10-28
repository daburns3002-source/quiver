--!strict
--[[
	The things a player equips, fetched before they equip them (owner,
	2026-10-27: "i want everything preloaded wherever possible so there is no
	stutter or lag").

	`Fx/RoomPreload` covers what a room brings — its arena and its enemies —
	and `UI/Cards/CardPreload` the upgrade cards, but nothing covered the
	weapons and pets themselves. Their meshes were fetched the first time one
	was drawn: the first swing of a weapon just bought, the first look at a
	pet in the lobby, the first Mythic that hands over another class's weapon.

	Their animation clips need nothing. `Config/WeaponAnimations` and
	`Config/ModelClips` are CFrame keyframes — data in the place file, not
	assets to fetch — so a clip has never cost a download and none is asked
	for here.

	Lowest priority of all the preloaders, and deliberately so: it starts
	after a delay and fetches weapons before pets, because a weapon is in
	hand in a fight while a pet is first met in the lobby, where a hitch
	costs nothing. On the lowest tier the pets are left out of it entirely —
	a phone that is also holding an arena, its enemies and a class's cards
	has better uses for the bandwidth, and the lobby is where it will see
	them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Device = require(script.Parent.Parent.Device)
local Preload = require(script.Parent.Parent.Preload)

local log = Log.forTag("LoadoutPreload")

local LoadoutPreload = {}

--[[ How long after joining this starts, leaving the room and the cards the
     network to themselves first. ]]
local AFTER = 8

--[[ Every mesh and texture the held weapons draw (`Config/Weapons`), skins
     included: a Mythic can hand over any of them mid-run. ]]
function LoadoutPreload.weaponContent(): { string }
	return Preload.idsIn(Weapons)
end

--[[ Every mesh and texture the pet models draw. One module per pet
     (`Config/PetModels`), each a list of parts, generated from the owner's
     import — walked rather than listed so a newly imported pet is covered
     without touching this file. ]]
function LoadoutPreload.petContent(): { string }
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PetModels")
	if not folder then
		return {}
	end
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, module in folder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end
		--[[ `pcall`, because one pet's module failing to load must not take
		     the other sixteen with it. ]]
		local ok, rows = pcall(require :: any, module)
		if not ok then
			log.warn("%s did not load: %s", module.Name, tostring(rows))
			continue
		end
		for _, id in Preload.idsIn(rows) do
			if not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	return out
end

function LoadoutPreload.start()
	task.delay(AFTER, function()
		local began = os.clock()
		local weapons = Preload.fetch(LoadoutPreload.weaponContent())
		log.info("%d weapon assets in %.2f s", weapons, os.clock() - began)
		if Device.tier().name == "Low" then
			log.info("pets left for the lobby on this tier")
			return
		end
		local pets = Preload.fetch(LoadoutPreload.petContent())
		log.info("%d pet assets by %.2f s", pets, os.clock() - began)
	end)
end

return LoadoutPreload
