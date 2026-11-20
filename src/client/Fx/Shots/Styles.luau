--!strict
--[[
	Every bow's and staff's shot drawing, by weapon key, area by area as
	each batch is ported from the Projectile Shots page. A weapon with none
	yet keeps today's shot (`Config/WeaponFx.shots`, `Fx/ProjectileRenderer`).
]]

local Drowned = require(script.Parent.Drowned)
local Glade = require(script.Parent.Glade)
local Kit = require(script.Parent.Kit)

local Styles: { [string]: Kit.Drawer } = {}

for _, area in { Glade, Drowned } do
	for key, drawer in area do
		Styles[key] = drawer
	end
end

return table.freeze(Styles)
