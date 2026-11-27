--!strict
--[[
	Every blade's cleave drawing, by weapon key (a pair of daggers by the
	key of the dagger it pairs). Area by area, as each batch is ported from
	the Blade Cleaves page; a blade with none yet keeps the old ribbon
	(`Fx/SwingTrail`).
]]

local Bog = require(script.Parent.Bog)
local Canvas = require(script.Parent.Canvas)
local Drowned = require(script.Parent.Drowned)
local Glade = require(script.Parent.Glade)
local Golden = require(script.Parent.Golden)
local Sets = require(script.Parent.Sets)
local Thorn = require(script.Parent.Thorn)

export type Style = (c: Canvas.Ctx, I: Canvas.Inst, t: number, W: Canvas.Look) -> ()

local Styles: { [string]: Style } = {}

for _, area in { Glade :: any, Thorn, Drowned, Bog, Golden, Sets } do
	for key, style in area do
		Styles[key] = style
	end
end

return table.freeze(Styles)
