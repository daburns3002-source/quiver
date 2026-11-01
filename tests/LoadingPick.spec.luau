--!strict
--[[
	The loading screen shows only what the player has met (`Util/LoadingPick`):
	Mossy Glade's enemies and a new player's weapons from the start,
	Thornwood's enemies only once a boss is beaten, and an owned weapon.

	Of those it draws only the ones Codex made a spotlight for (owner,
	2026-10-31), so the two are pinned together here: a spotlight keyed to
	a name the pool never yields is a screen nobody will ever see.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
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

	--[[ Since 2026-10-31 the screen shows Codex's spotlights and nothing
	     else (`first/Loading`), so a spotlight keyed to a name no entry
	     carries is not a near miss: that screen simply never appears, and
	     nothing else would say so. ]]
	t.test("every spotlight is keyed to something the loading screen can pick", function()
		local names: { [string]: boolean } = {}
		for _, entry in LoadingPick.pool(nil) do
			names[entry.name] = true
		end
		local beaten = SaveSchema.default()
		beaten.bossesBeaten.MossyGlade = true
		for _, entry in LoadingPick.pool(beaten) do
			names[entry.name] = true
		end
		for key in LoadingScreen.spotlights do
			t.isTrue(
				names[key] == true,
				`the "{key}" spotlight matches no entry, so it never shows`
			)
		end
	end)

	--[[ And at least one has to be reachable the moment a player joins, or
	     the first thing they ever see is a black screen with a tip on it. ]]
	t.test("a brand new player can be shown a spotlight", function()
		local shown = 0
		for _, entry in LoadingPick.pool(nil) do
			if LoadingScreen.spotlights[entry.name] then
				shown += 1
			end
		end
		t.isTrue(shown > 0, "a new player meets nothing with a spotlight")
	end)

	t.test("a new player: Mossy Glade's enemies and weapons, not Thornwood's", function()
		local pool = LoadingPick.pool(nil)
		t.isTrue(has(pool, "MOSS SLIME"), "no Moss Slime")
		t.isTrue(has(pool, "EMBER FANG BOW"), "Mossy Glade's weapons missing")
		t.isTrue(not has(pool, "BRAMBLE BOAR"), "Thornwood shown too early")
		for _, entry in pool do
			t.isTrue(entry.picture:find("rbxassetid://") == 1, `{entry.name} has no picture`)
			t.isTrue(#entry.description > 0, `{entry.name} has no description`)
		end
	end)

	t.test("the benched Ember Wilf is never shown", function()
		local profile = SaveSchema.default()
		profile.bossesBeaten.MossyGlade = true
		t.isTrue(not has(LoadingPick.pool(nil), "EMBER WILF"), "Wilf shown")
		t.isTrue(not has(LoadingPick.pool(profile), "EMBER WILF"), "Wilf shown")
	end)

	t.test("Thornwood's enemies once King Bloblin is beaten", function()
		local profile = SaveSchema.default()
		profile.bossesBeaten.MossyGlade = true
		t.isTrue(has(LoadingPick.pool(profile), "BRAMBLE BOAR"), "no Bramble Boar")
	end)

	t.test("a Legendary's description carries its effect", function()
		local line = LoadingPick.describeWeapon("EmberFangBow")
		t.isTrue(line:find("LEGENDARY") ~= nil and line:find("40%%") ~= nil, line)
	end)
end
