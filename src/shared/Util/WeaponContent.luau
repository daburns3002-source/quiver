--!strict
--[[
	Which pictures a weapon is painted with (`Config/Weapons` `textureId`),
	so the client can have them ready before the weapon is put in a hand
	(`Fx/WeaponPreload`; owner, 2026-11-14: "preload the weapon textures so
	they dont show up pale"). A one-mesh Tripo weapon carries its colours in
	one texture; until that is in video memory the mesh is drawn bare, pale.

	Pure, so `tests/WeaponContent.spec` pins it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WeaponContent = {}

--[[ The textures of `weapon`'s parts, each once; none for a weapon coloured
     by its vertices, or a name that is no weapon. ]]
function WeaponContent.textures(weapon: unknown): { string }
	local out: { string } = {}
	local entry = if type(weapon) == "string" then (Weapons :: any)[weapon] else nil
	if type(entry) ~= "table" then
		return out
	end
	for _, part in (entry :: Weapons.Weapon).parts do
		local id = part.textureId
		if id and id ~= "" and not table.find(out, id) then
			table.insert(out, id)
		end
	end
	return out
end

--[[ The textures of every weapon in `weapons` (names as keys or as a list),
     each once, in a steady order. ]]
function WeaponContent.texturesOf(weapons: { [any]: any }): { string }
	local names: { string } = {}
	for key, value in weapons do
		local name = if type(key) == "string" then key else value
		if type(name) == "string" and not table.find(names, name) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	local out: { string } = {}
	for _, name in names do
		for _, id in WeaponContent.textures(name) do
			if not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	return out
end

return WeaponContent
