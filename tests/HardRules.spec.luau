--!strict
--[[
	Hard mode (`Util/HardRules`; owner, 2026-11-18): offered only once an
	area's boss is beaten, its levels open in order over the hard wins, and
	the server refuses a hard level whose area boss stands (`Run/Lobby.hardOpen`).
	It is harder (health and damage up, one elite a fight without a boss),
	pays better (coins added like the other bonuses, gems on each first hard
	clear, an area's frame for its last), stays in its area on NEXT LEVEL, and
	has no stars of its own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EndScreenRules = require(ReplicatedStorage.Shared.Util.EndScreenRules)
local HardRules = require(ReplicatedStorage.Shared.Util.HardRules)
local Lobby = require(ServerScriptService.Server.Run.Lobby)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

local stages = Balance.Stages
local portals = LobbyConfig.portals

--[[ Every area's portal: its place, levels and area. ]]
local function areas(): { { at: number, levels: { number }, area: string } }
	local out = {}
	for at, portal in portals do
		local area = HardRules.areaOf(portal.levels, stages)
		if area and portal.levels then
			table.insert(out, { at = at, levels = portal.levels, area = area })
		end
	end
	return out
end

--[[ Every level of `levels` by name, as won. ]]
local function all(levels: { number }): { [string]: boolean }
	local out = {}
	for _, index in levels do
		local name = stages[index].level
		if name then
			out[name] = true
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("every built area can go hard, Endless never", function()
		t.isTrue(#areas() >= 4, "fewer than four areas with levels")
		for _, portal in portals do
			if portal.name == "Endless" then
				t.isNil(HardRules.areaOf(portal.levels, stages), "Endless has an area")
				t.isFalse(HardRules.offered(portal.levels, stages, { MossyGlade = true }))
			end
		end
	end)

	t.test("hard is offered only once the area's boss is beaten", function()
		for _, a in areas() do
			t.isFalse(HardRules.offered(a.levels, stages, nil), a.area .. " with no profile")
			t.isFalse(HardRules.offered(a.levels, stages, {}), a.area .. " with no boss beaten")
			t.isTrue(HardRules.offered(a.levels, stages, { [a.area] = true }), a.area)
		end
		-- another area's boss opens nothing here
		local glade = areas()[1]
		t.isFalse(HardRules.offered(glade.levels, stages, { Thornwood = true }))
	end)

	t.test("hard levels open in order, over the hard wins", function()
		for _, a in areas() do
			local boss = { [a.area] = true }
			t.isTrue(HardRules.isOpen(a.levels, stages, boss, {}, 1), a.area .. " first")
			t.isFalse(
				HardRules.isOpen(a.levels, stages, boss, {}, 2),
				a.area .. " second, first unwon"
			)
			local first = stages[a.levels[1]].level :: string
			t.isTrue(
				HardRules.isOpen(a.levels, stages, boss, { [first] = true }, 2),
				a.area .. " second"
			)
			-- every hard win in the world opens nothing with the boss standing
			t.isFalse(
				HardRules.isOpen(a.levels, stages, {}, all(a.levels), 1),
				a.area .. " no boss"
			)
			t.isFalse(HardRules.isOpen(a.levels, stages, boss, all(a.levels), #a.levels + 1))
			t.equal(HardRules.suggested(a.levels, stages, { [first] = true }), 2)
		end
	end)

	t.test("the server refuses a hard level whose area boss stands", function()
		for _, a in areas() do
			local beaten = {}
			for _, other in areas() do
				for name in all(other.levels) do
					beaten[name] = true
				end
			end
			local bosses = {
				MossyGlade = true,
				Thornwood = true,
				DrownedVillage = true,
				BogheartCaverns = true,
				WindsweptCliffs = true,
			}
			local without = table.clone(bosses)
			without[a.area] = nil
			t.isNil(
				Lobby.hardOpen(a.at, 1, beaten, without, {}, true),
				a.area .. " with its boss standing"
			)
			t.isNil(Lobby.hardOpen(a.at, 1, beaten, nil, nil, true), a.area .. " with no profile")
			t.equal(
				Lobby.hardOpen(a.at, 1, beaten, bosses, {}, true),
				a.levels[1],
				a.area .. " opened"
			)
			t.isNil(
				Lobby.hardOpen(a.at, 2, beaten, bosses, {}, true),
				a.area .. " 2 before 1 on hard"
			)
			-- the normal start is unchanged by it
			t.equal(Lobby.levelOpen(a.at, 2, beaten, without, true), a.levels[2])
		end
		-- forged asks get nothing
		local bosses = { MossyGlade = true }
		t.isNil(Lobby.hardOpen("1", 1, {}, bosses, {}))
		t.isNil(Lobby.hardOpen(1, "1", {}, bosses, {}))
		t.isNil(Lobby.hardOpen(1, 1.5, {}, bosses, {}))
		t.isNil(Lobby.hardOpen(99, 1, {}, bosses, {}))
	end)

	t.test("hard is harder, and its elite tougher still", function()
		t.isTrue(Balance.Hard.health > 1 and Balance.Hard.damage > 1, "hard is not harder")
		t.isTrue(Balance.Hard.eliteHealth > 1, "the elite is no tougher")
		local off = HardRules.scale(false)
		t.equal(off.health, 1)
		t.equal(off.damage, 1)
		local on = HardRules.scale(true)
		t.equal(on.health, Balance.Hard.health)
		t.equal(on.damage, Balance.Hard.damage)
	end)

	t.test("one elite a fight on hard, none with a boss in it", function()
		for count = 1, 40 do
			local slot = HardRules.eliteSlot(count, false, true)
			t.isTrue(slot >= 1 and slot <= count, `slot {slot} of {count}`)
			t.equal(HardRules.eliteSlot(count, true, true), 0, "a boss fight's elite")
			t.equal(HardRules.eliteSlot(count, false, false), 0, "an elite on normal")
		end
		t.equal(HardRules.eliteSlot(0, false, true), 0)
	end)

	t.test("hard coins add as the other bonuses do: nothing multiplies", function()
		t.isTrue(Rewards.hard.coins > 0, "hard pays no more coins")
		t.equal(RunBonus.hard(false), 0)
		t.equal(RunBonus.hard(nil), 0)
		t.equal(RunBonus.scale(1, 0, 1, true), 1 + Rewards.hard.coins)
		t.near(
			RunBonus.scale(2, 3, 2, true),
			2 + RunBonus.streak(3) + RunBonus.friend(2) + Rewards.hard.coins,
			1e-9
		)
		t.equal(RunBonus.scale(1, 0, 1), 1, "normal is unchanged")
		local said = RunBonus.lines(0, 1, true)
		t.equal(#said, 1)
		t.isTrue(string.find(said[1], "HARD", 1, true) ~= nil, said[1])
		t.equal(#RunBonus.lines(0, 1), 0)
	end)

	t.test(
		"a first hard clear pays gems, more for an area's last, and never the store's price",
		function()
			local total = 0
			for _, a in areas() do
				t.isTrue(HardRules.gems(a.levels, #a.levels) > HardRules.gems(a.levels, 1), a.area)
				t.isTrue(HardRules.gems(a.levels, 1) > 0, a.area .. " pays nothing")
				for position in a.levels do
					total += HardRules.gems(a.levels, position)
				end
			end
			-- once ever, across every hard level: well under a thousand
			t.isTrue(total < 1000, `hard pays {total} gems`)
		end
	)

	t.test("NEXT LEVEL on hard stays in its area", function()
		for _, a in areas() do
			local first, last = a.levels[1], a.levels[#a.levels]
			t.equal(HardRules.nextIndex(portals, first), a.levels[2], a.area)
			t.isNil(HardRules.nextIndex(portals, last), a.area .. " goes on past its last")
			t.isTrue(EndScreenRules.goesOn(first, true), a.area)
			t.isFalse(EndScreenRules.goesOn(last, true), a.area .. " last on hard goes on")
			t.equal(EndScreenRules.levelTab(first, true), `HARD {stages[first].level}`)
			t.equal(EndScreenRules.levelTab(first), `LEVEL {stages[first].level}`)
		end
		-- normal goes on from Mossy Glade's last into Thornwood, hard does not
		local glade = areas()[1].levels
		t.isTrue(EndScreenRules.goesOn(glade[#glade]))
	end)

	t.test("the frame is the furthest area won on hard, in its portal's colour", function()
		t.isNil(HardRules.frame(portals, stages, nil))
		t.isNil(HardRules.frame(portals, stages, {}))
		local list = areas()
		local glade, thorn = list[1], list[2]
		local gladeLast = stages[glade.levels[#glade.levels]].level :: string
		local thornLast = stages[thorn.levels[#thorn.levels]].level :: string
		local gladeFirst = stages[glade.levels[1]].level :: string
		t.isNil(HardRules.frame(portals, stages, { [gladeFirst] = true }), "a frame for one level")
		t.equal(HardRules.frame(portals, stages, { [gladeLast] = true }), glade.area)
		t.equal(
			HardRules.frame(portals, stages, { [gladeLast] = true, [thornLast] = true }),
			thorn.area
		)
		for _, a in list do
			local colour = HardRules.frameColour(portals, stages, a.area)
			t.notNil(colour, a.area .. " has no colour")
			t.equal(colour, portals[a.at].tint)
		end
		t.isNil(HardRules.frameColour(portals, stages, nil))
	end)

	t.test("hard has no stars of its own: a hard win fills the level's", function()
		for _, a in areas() do
			for _, index in a.levels do
				t.equal(HardRules.starLevel(stages[index]), stages[index].level)
			end
		end
		local p = SaveSchema.default() :: any
		t.isNil(p.hardStars, "a save holds hard stars")
		t.notNil(p.hardBeaten)
	end)
end
