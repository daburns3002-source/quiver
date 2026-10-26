--!strict
--[[
	The tutorial (`Config/Tutorial`, `Util/TutorialHands`, `Balance` tutorial
	stage), as the owner set it (2026-10-25): five rooms of Moss Slimes and
	Sprout Spitters only, a Ranger; fixed upgrades, the same for everyone; the
	first hand a Common, an Uncommon and a Rare; room 3's level-up Multishot in
	the middle; no Legendary or Mythic otherwise, nor in the pool; and the rooms'
	XP lands level-ups in rooms 1, 2 and 3.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local TestRunner = require(script.Parent.TestRunner)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local TutorialHands = require(ReplicatedStorage.Shared.Util.TutorialHands)

local Loadout = require(ServerScriptService.Server.Run.Loadout)

local c = Tutorial :: any
local stage = Balance.Stages[Balance.tutorialStage]
local stageRooms: { number } = stage.rooms or {}

local function rarity(id: string): string
	return Abilities.byId[id].rarity
end

--[[ Every hand the tutorial can deal. ]]
local function allHands(): { { string } }
	local out = { Tutorial.firstHand }
	for _, hand in Tutorial.roomHands do
		table.insert(out, hand)
	end
	for _, hand in Tutorial.hands do
		table.insert(out, hand)
	end
	return out
end

return function(t: TestRunner.Helper)
	t.test("the tutorial is five rooms of Moss Slimes and Spitters, with no boss", function()
		t.isTrue(stage.tutorial == true)
		t.equal(stage.mode, "Rooms")
		t.equal(#stageRooms, 5)
		for _, index in stageRooms do
			local room = Balance.Rooms[index]
			t.isTrue(room ~= nil)
			for _, enemy in room.roster do
				t.isTrue(
					enemy == Balance.Enemies.MeleeCharger or enemy == Balance.Enemies.SpreadShooter
				)
			end
		end
	end)

	t.test(
		"the player is a Ranger with no rerolls and no Legendary or Mythic in the pool",
		function()
			t.equal(Tutorial.class, "Ranger")
			t.equal(Tutorial.rerolls, 0)
			t.isTrue(table.find(Tutorial.bannedRarities, "Legendary") ~= nil)
			t.isTrue(table.find(Tutorial.bannedRarities, "Mythic") ~= nil)
			local state = Loadout.new()
			state.class = Tutorial.class
			state.banned = table.clone(Tutorial.bannedRarities)
			local random = Random.new(1)
			for _ = 1, 200 do
				for _, id in Loadout.rollOffer(state, false, random) do
					t.isTrue(rarity(id) ~= "Legendary" and rarity(id) ~= "Mythic")
				end
			end
		end
	)

	t.test("the first hand is a Common, an Uncommon and a Rare, left to right", function()
		local hand, kind = TutorialHands.handFor(c, TutorialHands.newProgress(), 1)
		t.equal(kind, "First")
		local h = hand :: { string }
		t.equal(#h, 3)
		t.equal(rarity(h[1]), "Common")
		t.equal(rarity(h[2]), "Uncommon")
		t.equal(rarity(h[3]), "Rare")
	end)

	t.test("room 3's level-up is Multishot, a Legendary, in the middle slot", function()
		local progress = TutorialHands.newProgress()
		TutorialHands.dealt(progress, "First", 1)
		local hand, kind = TutorialHands.handFor(c, progress, 3)
		t.equal(kind, "Room")
		local h = hand :: { string }
		t.equal(h[2], "Multishot")
		t.equal(rarity("Multishot"), "Legendary")
		t.isTrue(TutorialHands.owesLevel(c, progress, 3))
		TutorialHands.dealt(progress, "Room", 3)
		t.isFalse(TutorialHands.owesLevel(c, progress, 3))
		-- a second level-up in room 3 is an ordinary hand
		local _, again = TutorialHands.handFor(c, progress, 3)
		t.equal(again, "Ordinary")
	end)

	t.test(
		"no other hand holds a Legendary or a Mythic; every card is a Ranger's, in rotation",
		function()
			for _, hand in allHands() do
				for _, id in hand do
					local ability = Abilities.byId[id]
					t.isTrue(ability ~= nil)
					-- in rotation: a benched card would be swapped out of its slot
					t.isTrue(not ability.benched)
					local classes = ability.classes
					t.isTrue(classes == nil or table.find(classes, "Ranger") ~= nil)
					if hand ~= Tutorial.roomHands[3] then
						t.isTrue(ability.rarity ~= "Legendary" and ability.rarity ~= "Mythic")
					end
				end
			end
		end
	)

	t.test("a fixed hand keeps its cards in their slots, its Legendary despite the ban", function()
		local state = Loadout.new()
		state.class = Tutorial.class
		state.banned = table.clone(Tutorial.bannedRarities)
		local hand = Loadout.fixedHand(state, Tutorial.roomHands[3], false, Random.new(1))
		t.equal(hand[2], "Multishot")
		t.equal(#hand, 3)
	end)

	t.test("the rooms' XP levels the player up in rooms 1, 2 and 3", function()
		local xp, level, cost = 0, 1, Progression.baseLevelCost
		local levelledIn = {}
		for position, index in stageRooms do
			local room = Balance.Rooms[index]
			for k = 1, room.enemyCount do
				xp += room.roster[(k - 1) % #room.roster + 1].xpReward
			end
			while xp >= cost do
				xp -= cost
				level += 1
				cost = math.floor(
					Progression.baseLevelCost * Progression.levelCostGrowth ^ (level - 1) + 0.5
				)
				levelledIn[position] = true
			end
		end
		t.isTrue(levelledIn[1] == true)
		t.isTrue(levelledIn[2] == true)
		t.isTrue(levelledIn[3] == true)
	end)
end
