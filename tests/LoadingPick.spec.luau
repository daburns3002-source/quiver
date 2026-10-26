--!strict
--[[
	The loading screen shows only what the player has met (`Util/LoadingPick`):
	Mossy Glade's enemies and a new player's weapons from the start,
	Thornwood's enemies only once a boss is beaten, and an owned weapon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

local function has(pool: { LoadingPick.Entry }, name: string): boolean
	for _, entry in pool do
		if entry.name == name then
			return true
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("twenty tips", function()
		t.equal(#LoadingTips, 20)
	end)

	t.test("a new player: Mossy Glade's enemies, not Thornwood's", function()
		local pool = LoadingPick.pool(nil)
		t.isTrue(has(pool, "MOSS SLIME"), "no Moss Slime")
		t.isTrue(not has(pool, "BRAMBLE BOAR"), "Thornwood shown too early")
		for _, entry in pool do
			t.isTrue(entry.picture:find("rbxassetid://") == 1, `{entry.name} has no picture`)
		end
	end)

	t.test("Thornwood's enemies after King Bloblin, and owned weapons", function()
		local profile = SaveSchema.default()
		profile.bossesBeaten.MossyGlade = true
		profile.weapons.EmberFangBow = true
		local pool = LoadingPick.pool(profile)
		t.isTrue(has(pool, "BRAMBLE BOAR"), "no Bramble Boar")
		t.isTrue(has(pool, "EMBER FANG BOW"), "no Ember Fang Bow")
	end)
end
