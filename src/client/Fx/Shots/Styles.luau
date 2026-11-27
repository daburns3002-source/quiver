--!strict
--[[
	Every bow's and staff's shot drawing, by weapon key, area by area as
	each batch is ported from the Projectile Shots page. A weapon with none
	yet keeps today's shot (`Config/WeaponFx.shots`, `Fx/ProjectileRenderer`).
]]

local Bog = require(script.Parent.Bog)
local Drowned = require(script.Parent.Drowned)
local Glade = require(script.Parent.Glade)
local Golden = require(script.Parent.Golden)
local Kit = require(script.Parent.Kit)
local Sets = require(script.Parent.Sets)

local Styles: { [string]: Kit.Drawer } = {}

for _, area in { Glade, Drowned, Bog, Golden, Sets } do
	for key, drawer in area do
		Styles[key] = drawer
	end
end

return table.freeze(Styles)
