--!strict
--[[
	The launch switch (`Config/Launch.locks`, `Util/LaunchLocks`): off, the
	playtest is as open as the owner asked for; on, every area after the
	first and every egg after the first waits on the boss before it. Both
	states are held here so the switch can be thrown on launch day without
	anything else being written.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Launch = require(ReplicatedStorage.Shared.Config.Launch)
local LaunchLocks = require(ReplicatedStorage.Shared.Util.LaunchLocks)
local Lobby = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

local function built(): { Lobby.Portal }
	local out = {}
	for _, portal in Lobby.portals do
		if portal.levels then
			table.insert(out, portal)
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("the switch is off: the playtest stays open", function()
		t.isFalse(Launch.locks, "locking the game is the owner's call, on launch day")
	end)

	t.test("unlocked, a new player may walk into every built portal", function()
		for _, portal in built() do
			if not portal.requires then
				t.isTrue(
					LaunchLocks.portalOpen(portal, {}, {}, false),
					`{portal.name} is shut in playtest`
				)
				t.equal(LaunchLocks.portalWords(portal, false), "")
			end
		end
		for _, egg in Eggs.list do
			t.equal(LaunchLocks.eggUnlock(egg, false), egg.unlock, `{egg.key} gained a lock`)
		end
	end)

	t.test("locked, only the first area is open to a new player", function()
		local portals = built()
		t.isTrue(#portals >= 2, "there are areas to lock")
		for i, portal in portals do
			local open = LaunchLocks.portalOpen(portal, {}, {}, true)
			if i == 1 then
				t.isTrue(open, "the first area is always open")
			else
				t.isFalse(open, `{portal.name} is open to a brand-new player at launch`)
				t.isTrue(
					LaunchLocks.portalWords(portal, true) ~= "",
					`{portal.name} does not say what opens it`
				)
				t.isFalse(
					LaunchLocks.portalOpen(portal, nil, nil, true),
					`{portal.name} opens with no profile`
				)
			end
		end
	end)

	t.test("locked, each gate opens on exactly what it names", function()
		for _, portal in built() do
			local gate = LaunchLocks.portalGate(portal, true)
			local levels = if gate.requires then { [gate.requires] = true } else {}
			local bosses = if gate.boss then { [gate.boss] = true } else {}
			t.isTrue(
				LaunchLocks.portalOpen(portal, levels, bosses, true),
				`{portal.name} stays shut after its gate is met`
			)
		end
		local thornwood, endless
		for _, portal in built() do
			if portal.name == "Thornwood" then
				thornwood = portal
			elseif portal.name == "Endless" then
				endless = portal
			end
		end
		t.notNil(thornwood, "Thornwood is built")
		t.notNil(endless, "Endless is built")
		if thornwood and endless then
			t.equal(LaunchLocks.portalWords(thornwood, true), "BEAT 1-10")
			t.isFalse(LaunchLocks.portalOpen(thornwood, { ["1-9"] = true }, {}, true))
			t.isFalse(LaunchLocks.portalOpen(endless, {}, { MossyGlade = true }, true))
			t.isTrue(LaunchLocks.portalOpen(endless, { ["1-10"] = true }, {}, true))
		end
	end)

	t.test("a boss gate reads as the area's name", function()
		for _, portal in built() do
			local gate = LaunchLocks.portalGate(portal, true)
			if gate.boss and not gate.requires then
				local words = LaunchLocks.portalWords(portal, true)
				t.isTrue(string.sub(words, 1, 5) == "BEAT ", words)
				t.isNil(string.find(words, "%l"), `{words} is not in capitals`)
			end
		end
	end)

	t.test("locked, every egg after the first waits on a boss", function()
		for i, egg in Eggs.list do
			local unlock = LaunchLocks.eggUnlock(egg, true)
			if i == 1 then
				t.isNil(unlock, "the first egg is always open")
			else
				t.notNil(unlock, `{egg.key} is open to a brand-new player at launch`)
			end
		end
	end)
end
