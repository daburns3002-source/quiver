--!strict
--[[
	The Dex Hall's three books (`Util/DexBook`): what each one holds, what a
	player has found of it, and how it falls into pages of nine.

	The point of the dex is that it shows everything and hides what you have
	not found, so the two things worth pinning are that nothing goes missing
	from a book and that nothing is given away before it is found.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

local PER_PAGE = Dex.books[Dex.order[1]].grid.columns * Dex.books[Dex.order[1]].grid.rows

--[[ Whether `key` is in `entries` and found. Missing counts as not found,
     so a test never indexes a nil entry. ]]
local function wasFound(entries: { DexBook.Entry }, key: string): boolean
	for _, entry in entries do
		if entry.key == key then
			return entry.unlocked
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("three books, each with entries", function()
		t.equal(#DexBook.BOOKS, 3)
		for _, book in DexBook.BOOKS do
			local entries = DexBook.entries(book, nil)
			t.isTrue(#entries > 0, `{book} has entries`)
		end
	end)

	--[[ A slot with no picture cannot even be drawn as a silhouette, so a
	     book must never carry one. ]]
	t.test("every entry has a picture and an icon", function()
		for _, book in DexBook.BOOKS do
			for _, entry in DexBook.entries(book, nil) do
				t.isTrue(entry.icon ~= "", `{book}/{entry.key} has an icon`)
				t.isTrue(entry.picture ~= "", `{book}/{entry.key} has a picture`)
				t.isTrue(entry.name ~= "", `{book}/{entry.key} has a name`)
			end
		end
	end)

	--[[ A new player has met no enemy and hatched no pet, but the class
	     weapons are owned from the start (`SaveSchema` STARTERS), so the
	     weapon book opens with those three already found. Anything else
	     would mean the dex was guessing rather than reading the save. ]]
	t.test("a new player has found only their starting weapons", function()
		local profile = SaveSchema.default()
		for _, book in DexBook.BOOKS do
			local entries = DexBook.entries(book, profile)
			local found, total = DexBook.found(entries)
			t.isTrue(total > 0, `{book} has a total`)
			local owned = 0
			for _, entry in entries do
				if book == "Weapons" and profile.weapons[entry.key] then
					owned += 1
				end
			end
			t.equal(found, owned, `{book} found matches the profile`)
		end
		t.equal(DexBook.found(DexBook.entries("Enemies", profile)), 0, "no enemy met")
		t.equal(DexBook.found(DexBook.entries("Pets", profile)), 0, "no pet hatched")
	end)

	--[[ A new player owns their class's starting weapons, so the weapon
	     book is the one place "found nothing" would be wrong if the dex
	     read ownership rather than the profile. It reads the profile. ]]
	t.test("the weapon book follows what the profile owns", function()
		local profile = SaveSchema.default()
		local before = DexBook.found(DexBook.entries("Weapons", profile))
		--[[ One the starters do not already cover, so the count has to
		     move for the test to mean anything. ]]
		local target: string? = nil
		for _, entry in DexBook.entries("Weapons", profile) do
			if not entry.unlocked and target == nil then
				target = entry.key
			end
		end
		t.notNil(target, "some weapon is unowned at the start")
		profile.weapons[target :: string] = true
		local after = DexBook.entries("Weapons", profile)
		t.isTrue(wasFound(after, target :: string), "owning it finds it")
		t.equal(DexBook.found(after), before + 1, "one more, not all of them")
	end)

	--[[ The owner's rule (2026-11-01): "anytime the new enemy card comes up
	     for a player that means it is now unlocked for them in the dex".
	     `RunSession.meetEnemy` writes the dex flag in the same block that
	     fires the card, so the two can only agree if the two *sets* agree:
	     every enemy with a card is in the book, and the book holds nothing
	     that can never show one. A benched enemy has no card and is not in
	     the book, which is the one allowed difference. ]]
	t.test("the enemy book is exactly what can show a NEW ENEMY! card", function()
		local inBook: { [string]: boolean } = {}
		for _, entry in DexBook.entries("Enemies", nil) do
			inBook[entry.key] = true
		end
		for key, enemy in NewEnemies.enemies do
			local carded = not enemy.benched and enemy.picture ~= ""
			t.equal(inBook[key] == true, carded, key)
		end
	end)

	t.test("meeting an enemy finds it, and only it", function()
		local profile = SaveSchema.default()
		--[[ The book's own first entry, not `next()` over the config: the
		     order is pinned above, so this names the same enemy every run. ]]
		local key = DexBook.entries("Enemies", nil)[1].key
		profile.enemiesSeen[key] = true
		local entries = DexBook.entries("Enemies", profile)
		local found = DexBook.found(entries)
		t.equal(found, 1)
		t.isTrue(wasFound(entries, key), "the one met is found")
	end)

	t.test("hatching a pet finds it", function()
		local profile = SaveSchema.default()
		local entries = DexBook.entries("Pets", profile)
		local first = entries[1]
		profile.pets[first.key] = 1
		t.isTrue(wasFound(DexBook.entries("Pets", profile), first.key), "a hatched pet is found")
	end)

	--[[ Zero of a pet is not one: the hatchery writes counts, and a pet
	     released back down to none should go dark again. ]]
	t.test("none of a pet is not found", function()
		local profile = SaveSchema.default()
		local first = DexBook.entries("Pets", profile)[1]
		profile.pets[first.key] = 0
		t.isFalse(wasFound(DexBook.entries("Pets", profile), first.key), "zero is not found")
	end)

	t.test("the order does not depend on how a config iterates", function()
		for _, book in DexBook.BOOKS do
			local once, twice = DexBook.entries(book, nil), DexBook.entries(book, nil)
			for index, entry in once do
				t.equal(twice[index].key, entry.key, `{book} entry {index}`)
			end
		end
	end)

	t.test("pages are nine to a spread and lose nothing", function()
		t.equal(PER_PAGE, 9)
		for _, book in DexBook.BOOKS do
			local entries = DexBook.entries(book, nil)
			local pages = DexBook.pages(entries, PER_PAGE)
			local seen = 0
			for index = 1, pages do
				local page = DexBook.page(entries, index, PER_PAGE)
				t.isTrue(#page <= PER_PAGE, `{book} page {index} fits`)
				t.isTrue(#page > 0, `{book} page {index} is not empty`)
				seen += #page
			end
			t.equal(seen, #entries, `{book} pages hold every entry`)
		end
	end)

	t.test("an empty book is still one page", function()
		t.equal(DexBook.pages({}, PER_PAGE), 1)
		t.equal(#DexBook.page({}, 1, PER_PAGE), 0)
	end)

	--[[ Every book needs its spread and its six turn frames, or the screen
	     draws a blank sheet of paper. ]]
	t.test("every book has its art", function()
		for _, name in Dex.order do
			local book = Dex.books[name]
			t.notNil(book, `{name} is a book`)
			t.isTrue(book.spread ~= "", `{name} has a spread`)
			t.equal(#book.turn, 6, `{name} has six turn frames`)
			for frame, id in book.turn do
				t.isTrue(id ~= "", `{name} turn frame {frame}`)
			end
			--[[ Each book carries its own panels, because the three
			     spreads are drawn differently. All nine slots and the
			     three panels have to be somewhere on the 1672x941 art. ]]
			local panels: { [string]: Dex.Box } =
				{ picture = book.picture, plaque = book.plaque, description = book.description }
			for label, box in panels do
				t.isTrue(box.x >= 0 and box.x + box.w <= Dex.canvas.X, `{name} {label} fits across`)
				t.isTrue(box.y >= 0 and box.y + box.h <= Dex.canvas.Y, `{name} {label} fits down`)
			end
			local grid = book.grid
			t.equal(grid.columns * grid.rows, PER_PAGE, `{name} holds nine`)
			local right = grid.x + (grid.columns - 1) * grid.stepX + grid.w
			local foot = grid.y + (grid.rows - 1) * grid.stepY + grid.h
			t.isTrue(right <= Dex.canvas.X, `{name} grid fits across`)
			t.isTrue(foot <= Dex.canvas.Y, `{name} grid fits down`)
			--[[ The turn frames are crops of the right page, so their
			     window has to sit on the right page and cover the grid --
			     a window that missed the slots would animate blank paper
			     beside them. ]]
			local win = book.turnWindow
			t.isTrue(win.x > Dex.canvas.X / 2, `{name} turn window is on the right page`)
			t.isTrue(win.x + win.w <= Dex.canvas.X, `{name} turn window fits across`)
			t.isTrue(win.y + win.h <= Dex.canvas.Y, `{name} turn window fits down`)
			t.isTrue(win.x <= grid.x, `{name} turn window reaches the first slot`)
			t.isTrue(win.y <= grid.y, `{name} turn window reaches the top row`)
			t.isTrue(win.x + win.w >= right, `{name} turn window covers the last column`)
			t.isTrue(win.y + win.h >= foot, `{name} turn window covers the bottom row`)

			--[[ The grid is on the right-hand page, past the spine. ]]
			t.isTrue(grid.x > Dex.canvas.X / 2, `{name} grid is on the right page`)
			t.isTrue(
				book.picture.x + book.picture.w < Dex.canvas.X / 2,
				`{name} picture is on the left page`
			)
		end
	end)

	--[[ The tabs and the books must be the same three, or a tab opens
	     nothing or a book is unreachable. ]]
	t.test("the tabs and the books match", function()
		t.equal(#Dex.order, #DexBook.BOOKS)
		for _, name in Dex.order do
			t.notNil(Dex.books[name], `{name} has art`)
			local entries = DexBook.entries(name, nil)
			t.isTrue(#entries > 0, `{name} has entries`)
		end
	end)
end
