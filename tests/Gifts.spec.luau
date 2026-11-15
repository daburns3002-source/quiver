--!strict
--[[
	The gift box and the Dex pages' chests (`Util/GiftRules`,
	`Util/PageRules`; owner, 2026-11-14: "there should be more rewards for
	players"): a gift every three levels won, with no clock in it, and a
	chest for each Dex page finished, the pets' and weapons' pages being an
	area's collection sets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local GiftRules = require(ReplicatedStorage.Shared.Util.GiftRules)
local PageRules = require(ReplicatedStorage.Shared.Util.PageRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

--[[ Finishes `page` of `profile`'s Dex the way playing would. ]]
local function finish(profile: SaveSchema.Profile, book: string, area: string)
	for _, entry in DexBook.inArea(DexBook.entries(book, profile), area) do
		if book == "Enemies" then
			profile.enemiesSeen[entry.key] = true
		elseif book == "Weapons" then
			profile.weapons[entry.key] = true
		else
			profile.pets[entry.key] = math.max(profile.pets[entry.key] or 0, 1)
		end
	end
end

return function(t: TestRunner.Helper)
	t.test("three wins fill a gift, an egg first and then a crate", function()
		local gift = SaveSchema.default().gift
		t.equal(GiftRules.ready(gift), 0)
		t.isNil(GiftRules.claim(gift), "nothing won, nothing to open")
		t.isTrue(GiftRules.won(gift))
		t.isTrue(GiftRules.won(gift))
		local have, need = GiftRules.progress(gift)
		t.equal(have, 2)
		t.equal(need, Rewards.gift.wins)
		t.equal(GiftRules.ready(gift), 0)
		GiftRules.won(gift)
		t.equal(GiftRules.ready(gift), 1)
		t.equal((GiftRules.progress(gift)), need, "the bar is full while one waits")
		t.equal(GiftRules.claim(gift), "Egg")
		t.equal(GiftRules.ready(gift), 0)
		t.isNil(GiftRules.claim(gift), "one gift, one opening")
		for _ = 1, 3 do
			GiftRules.won(gift)
		end
		t.equal(GiftRules.claim(gift), "Crate")
		t.equal(GiftRules.kind(gift), "Egg", "turn about")
	end)

	t.test("the box holds a few gifts and counts no win past full", function()
		local gift = SaveSchema.default().gift
		local full = Rewards.gift.wins * Rewards.gift.hold
		for _ = 1, full do
			t.isTrue(GiftRules.won(gift))
		end
		t.equal(GiftRules.ready(gift), Rewards.gift.hold)
		t.isFalse(GiftRules.won(gift), "a full box is opened, not hoarded")
		t.equal(gift.wins, full)
		t.notNil(GiftRules.claim(gift))
		t.equal(GiftRules.ready(gift), Rewards.gift.hold - 1)
		t.isTrue(GiftRules.won(gift))
	end)

	t.test("a stored gift box reads back whole and never over full", function()
		local read = GiftRules.read({ wins = 4.7, opened = 3 })
		t.equal(read.wins, 4)
		t.equal(read.opened, 3)
		t.equal(GiftRules.read(nil).wins, 0)
		t.equal(GiftRules.read("x").opened, 0)
		t.equal(GiftRules.read({ wins = -3, opened = 0 / 0 }).wins, 0)
		t.equal(GiftRules.read({ wins = 1e9 }).wins, Rewards.gift.wins * Rewards.gift.hold)
	end)

	t.test("every area's page of each book has a chest, said in the Dex's words", function()
		local pages = PageRules.pages(SaveSchema.default())
		t.isTrue(#pages >= 9, #pages .. " pages")
		local seen: { [string]: boolean } = {}
		for _, page in pages do
			t.isNil(seen[page.key], page.key .. " is listed twice")
			seen[page.key] = true
			t.equal(page.key, PageRules.key(page.book, page.area))
			t.isTrue(page.total > 0, page.key)
			t.isTrue(#page.words <= 30, page.words .. " reads long")
			t.notNil(Rewards.pages[page.book], page.book)
			t.isFalse(page.claimed)
		end
		t.notNil(seen["Pets:MossyGlade"])
		t.notNil(seen["Weapons:MossyGlade"])
		t.notNil(seen["Enemies:MossyGlade"])
	end)

	t.test("the sets pay the big gifts, and only a little gems", function()
		local gems = 0
		for _, page in PageRules.pages(SaveSchema.default()) do
			gems += page.prize.gems or 0
		end
		t.isTrue(gems <= 800, gems .. " gems for every page there is")
		t.isTrue((Rewards.pages.Pets.eggs or 0) >= 5)
		t.isTrue((Rewards.pages.Weapons.crates or 0) >= 5)
		t.equal(Rewards.pages.Enemies.gems, nil, "a page of enemies pays no gems")
	end)

	t.test("a page's chest opens once it is finished, and once only", function()
		local profile = SaveSchema.default()
		t.equal(PageRules.tally(profile), 0, "a new player has finished nothing")
		t.isNil(PageRules.claim(profile, "Pets:MossyGlade"))
		finish(profile, "Pets", "MossyGlade")
		t.equal(PageRules.tally(profile), 1)
		t.isNil(PageRules.claim(profile, "Pets:Thornwood"), "another page is not finished")
		t.isNil(PageRules.claim(profile, "Pets:Nowhere"))
		t.isNil(PageRules.claim(profile, 7))
		t.isNil(PageRules.claim(profile, nil))
		t.equal(PageRules.claim(profile, "Pets:MossyGlade"), Rewards.pages.Pets)
		t.isNil(PageRules.claim(profile, "Pets:MossyGlade"), "a chest opens once")
		t.equal(PageRules.tally(profile), 0)
		finish(profile, "Enemies", "MossyGlade")
		finish(profile, "Weapons", "MossyGlade")
		t.equal(PageRules.tally(profile), 2)
	end)

	t.test("one pet short is not a set", function()
		local profile = SaveSchema.default()
		finish(profile, "Pets", "MossyGlade")
		local page = DexBook.inArea(DexBook.entries("Pets", profile), "MossyGlade")
		profile.pets[page[#page].key] = nil
		t.equal(PageRules.tally(profile), 0)
		t.isNil(PageRules.claim(profile, "Pets:MossyGlade"))
	end)

	t.test("version 20: an older profile has an empty box and has opened no chest", function()
		local old = SaveSchema.migrate({ version = 19, coins = 3 })
		t.equal(old.gift.wins, 0)
		t.equal(old.gift.opened, 0)
		t.isNil((next(old.dexChests)))
		t.equal(old.coins, 3)
		local p = SaveSchema.migrate({
			version = 20,
			gift = { wins = 5, opened = 2 },
			dexChests = { ["Pets:MossyGlade"] = true, ["Bad"] = "yes" },
		})
		t.equal(p.gift.wins, 5)
		t.equal(p.gift.opened, 2)
		t.isTrue(p.dexChests["Pets:MossyGlade"])
		local again = SaveSchema.migrate(p)
		t.equal(again.gift.wins, 5, "a saved copy reads back the same")
		t.isTrue(again.dexChests["Pets:MossyGlade"])
	end)
end
