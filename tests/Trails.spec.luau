--!strict
--[[
	The trails (`Config/Trails`, `Util/TrailRules`): the roster's shape, the
	glow every Legendary and Mythic must wear (rule 12), one picture each,
	and who earns or may buy which.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local DeviceTiers = require(ReplicatedStorage.Shared.Config.DeviceTiers)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Lobby = require(ReplicatedStorage.Shared.Config.Lobby)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Trails = require(ReplicatedStorage.Shared.Config.Trails)

local function held(over: { [string]: any }?): TrailRules.Held
	local p = SaveSchema.default()
	for key, value in (over or {}) :: { [string]: any } do
		(p :: any)[key] = value
	end
	return p
end

return function(t: TestRunner.Helper)
	t.test("the order lists every trail once, and only trails", function()
		local seen: { [string]: boolean } = {}
		for _, key in Trails.order do
			t.notNil(Trails.trails[key], key .. " is in the order but not a trail")
			t.isNil(seen[key], key .. " is listed twice")
			seen[key] = true
		end
		for key in Trails.trails do
			t.isTrue(seen[key], key .. " is not in the order")
		end
	end)

	t.test("every area has a bought Rare and Epic and its boss's Legendary", function()
		for _, area in Trails.areas do
			t.notNil(Economy.areas[area], area .. " is an economy area")
			local by: { [string]: string } = {}
			for _, trail in Trails.trails do
				if trail.area == area then
					t.isNil(by[trail.rarity], area .. " has two " .. trail.rarity .. "s")
					by[trail.rarity] = trail.earn
				end
			end
			t.equal(by.Rare, "Gems", area)
			t.equal(by.Epic, "Gems", area)
			t.equal(by.Legendary, "Boss", area)
		end
	end)

	t.test("there is one Mythic, and Endless gives it", function()
		local mythics = 0
		for _, trail in Trails.trails do
			if trail.rarity == "Mythic" then
				mythics += 1
				t.equal(trail.earn, "Endless")
			end
		end
		t.equal(mythics, 1)
	end)

	t.test("every Legendary and Mythic glows and carries a light (rule 12)", function()
		for key, trail in Trails.trails do
			if trail.rarity == "Legendary" or trail.rarity == "Mythic" then
				t.isTrue(trail.glow, key .. " glows")
				t.notNil(trail.light, key .. " has a light")
				local neon = false
				for _, column in trail.ribbon.columns do
					neon = neon or column.neon == true
				end
				for _, piece in trail.pieces do
					for _, block in piece.blocks do
						neon = neon or block.neon == true
					end
				end
				t.isTrue(neon, key .. " has something Neon")
			end
		end
	end)

	t.test("every trail has its own picture and something to draw", function()
		local pictures: { [string]: string } = {}
		for key, trail in Trails.trails do
			t.isTrue(string.match(trail.icon, "^rbxassetid://%d+$") ~= nil, key .. " has an icon")
			t.isNil(
				pictures[trail.icon],
				key .. " shares " .. tostring(pictures[trail.icon]) .. "'s icon"
			)
			pictures[trail.icon] = key
			t.isTrue(
				string.match(trail.design, "^https://claude%.ai/design/p/") ~= nil,
				key .. " names its Design build"
			)
			local ribbon = trail.ribbon
			t.isTrue(
				(#ribbon.columns >= 1 or (ribbon.threads ~= nil and #ribbon.threads >= 1))
					and ribbon.fade[2] > ribbon.fade[1],
				key .. " has a ribbon"
			)
			t.isTrue(ribbon.alpha > 0 and ribbon.alpha <= 1, key .. " ribbon shows")
			for _, column in ribbon.columns do
				t.isTrue(column.height > 0 and column.height <= 1.5, key .. " ribbon lies low")
			end
			t.isTrue(#trail.pieces >= 1, key .. " throws pieces")
			for _, piece in trail.pieces do
				t.isTrue(#piece.blocks >= 1 and #piece.colours >= 1, key .. " pieces have blocks")
				t.isTrue(
					piece.rate > 0 and piece.life[1] > 0 and piece.size[1] > 0,
					key .. " pieces show"
				)
				t.isTrue(#piece.blocks <= 6, key .. " pieces stay cheap")
			end
		end
		t.isTrue(Trails.idle > 0 and Trails.idle < 1, "standing still leaves some, not all")
	end)

	t.test("only a dash throws a burst: walking, the exit rush and sprinting never do", function()
		local walk = Balance.Player.moveSpeed
		local fastest = walk * math.max(Balance.Player.exitRush, Lobby.sprint)
		t.isTrue(Trails.burst.speed > fastest * 1.1, "a burst is above every run")
		t.isTrue(Trails.burst.count > 0 and Trails.burst.gap > 0)
		t.isTrue(Trails.pulse.depth > 0 and Trails.pulse.depth < 1, "a pulse never goes dark")
	end)

	t.test("every device draws some of a trail's particles", function()
		for _, name in { "Low", "Medium", "High" } do
			local tier = (DeviceTiers :: any)[name]
			t.isTrue(tier.trailShare > 0 and tier.trailShare <= 1, name)
		end
	end)

	t.test("bought trails have a price that climbs by rarity and area; earned ones none", function()
		for key, trail in Trails.trails do
			if trail.earn == "Gems" then
				t.notNil(TrailRules.price(key), key)
			else
				t.isNil(TrailRules.price(key), key .. " is earned, not sold")
			end
		end
		t.isTrue(
			(TrailRules.price("LeafDrift") :: number) < (TrailRules.price("FireflyWake") :: number),
			"an Epic costs more than its Rare"
		)
		t.isTrue(
			(TrailRules.price("LeafDrift") :: number) < (TrailRules.price("BogSpores") :: number),
			"a later area costs more"
		)
	end)

	t.test("a boss's trail is earned when its boss falls, and is due until held", function()
		t.isFalse(TrailRules.earned("RoyalGoo", held()))
		local beat = held({ bossesBeaten = { MossyGlade = true } })
		t.isTrue(TrailRules.earned("RoyalGoo", beat))
		t.isFalse(TrailRules.earned("BroodSilk", beat), "only that area's")
		t.isFalse(TrailRules.earned("LeafDrift", beat), "a bought one is never earned")
		t.equal(table.concat(TrailRules.due(beat), ","), "RoyalGoo")
		local has = held({ bossesBeaten = { MossyGlade = true }, trails = { RoyalGoo = true } })
		t.equal(#TrailRules.due(has), 0, "held is not due again")
	end)

	t.test("Starfall needs its floor with every class, not one class deep", function()
		local floor = Trails.endless.floor
		for _, class in Trails.endless.classes do
			t.notNil(Classes[class], class .. " is a class")
		end
		local one = held({ endlessClassBest = { Ranger = floor * 3 } })
		t.isFalse(TrailRules.earned("Starfall", one))
		t.equal(TrailRules.endlessClasses(one.endlessClassBest), 1)
		local short: { [string]: number } = {}
		local all: { [string]: number } = {}
		for _, class in Trails.endless.classes do
			short[class] = floor
			all[class] = floor
		end
		short[Trails.endless.classes[1]] = floor - 1
		t.isFalse(TrailRules.earned("Starfall", held({ endlessClassBest = short })))
		t.isTrue(TrailRules.earned("Starfall", held({ endlessClassBest = all })))
		local words = TrailRules.howTo("Starfall", one) :: string
		t.isTrue(string.find(words, tostring(floor), 1, true) ~= nil, "it names the floor")
	end)

	t.test("an area's trails are sold when its crates are", function()
		local locked = held()
		t.isTrue(
			TrailRules.onSale("LeafDrift", locked.bossesBeaten, true),
			"the glade is always open"
		)
		t.isFalse(TrailRules.onSale("BubbleStream", locked.bossesBeaten, true), "shut at launch")
		t.notNil(TrailRules.howTo("BubbleStream", locked, true), "a shut one says what opens it")
		t.isTrue(TrailRules.onSale("BubbleStream", { Thornwood = true }, true))
		t.isTrue(TrailRules.onSale("BubbleStream", locked.bossesBeaten, false), "the switch off")
		t.isFalse(
			TrailRules.onSale("TideBell", { Thornwood = true }, false),
			"a boss's is never sold"
		)
		t.isNil(TrailRules.howTo("LeafDrift", locked, false), "one on sale shows its price instead")
	end)
end
