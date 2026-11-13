--!strict
--[[
	The class select cards' figures (`Config/ClassFigures`): every class a
	player can pick has one, and its weapon's grip is inside the figure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassCards = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassFigures = require(ReplicatedStorage.Shared.Config.ClassFigures)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every class a player can pick has a figure", function()
		for _, card in ClassCards do
			if not card.locked then
				t.notNil(ClassFigures.figures[card.class], `{card.class} has no figure`)
			end
		end
	end)

	t.test("a figure stands on the floor and holds its weapon inside itself", function()
		for class, figure in ClassFigures.figures do
			local size, centre, hand = figure.size, figure.centre, figure.hand
			t.isTrue(size.X > 0 and size.Y > 0 and size.Z > 0, `{class} has no size`)
			-- the body's feet are the floor; a sole may reach a hair below them
			t.isTrue(math.abs(centre.Y - size.Y / 2) < 0.1, `{class} does not stand on the floor`)
			local offset = (hand - centre):Abs()
			t.isTrue(
				offset.X <= size.X / 2 and offset.Y <= size.Y / 2 and offset.Z <= size.Z / 2,
				`{class}'s hand is outside its figure`
			)
			t.isTrue(hand.X > 0, `{class}'s right hand is not on its right (+X, facing -Z)`)
		end
	end)
end
