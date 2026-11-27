--!strict
--[[
	Which classes there are, and which of them a player can choose.

	One list, read off the class select cards (`Config/ClassSelect.cards`), so
	that opening a class is one word there (`locked`) and nothing else has a
	list of its own to forget: the server's CHOOSE and class switch
	(`Data/Shop`), class levels (`Util/ClassLevelRules`), what a player can
	own (`Util/ShopRules`), Gear's CLASSES tab, and the specs that hold every
	open class to the same rules (a Mythic of its own, a full card pool).

	A class is *open* when its card is not locked and `Config/Classes` has
	it. A class that is built but still locked (the Assassin, while it was
	being made) can be played in Studio (`all`, the C key) and by nobody else.
]]

local ClassSelect = require(script.Parent.Parent.Config.ClassSelect)
local Classes = require(script.Parent.Parent.Config.Classes)

local ClassList = {}

--[[ Every class that exists, in the cards' order. ]]
function ClassList.all(): { string }
	local out = {}
	for _, card in ClassSelect.cards do
		if Classes[card.class] then
			table.insert(out, card.class)
		end
	end
	return out
end

--[[ The classes a player can choose, in the cards' order. ]]
function ClassList.open(): { string }
	local out = {}
	for _, card in ClassSelect.cards do
		if Classes[card.class] and not card.locked then
			table.insert(out, card.class)
		end
	end
	return out
end

--[[ Whether `class` is one a player can choose. ]]
function ClassList.isOpen(class: unknown): boolean
	for _, card in ClassSelect.cards do
		if card.class == class then
			return Classes[card.class] ~= nil and not card.locked
		end
	end
	return false
end

return ClassList
