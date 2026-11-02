--!strict
--[[
	The Dex Hall's three books (owner, 2026-10-25: three codex books --
	Enemy, Weapon, Pet -- "3D books on lecterns in the lobby's Dex Hall, and
	on screen a 2D book with a little page turn frame animation every time
	the page is turned"; entries the player has not found show as black
	silhouettes).

	Each book is Codex's own spread, 1672x941, with its panels left empty:
	a picture window, a name plaque and a description box down the left
	page, and a 3x3 grid of slots on the right.

	Codex drew a sample entry into the middle slot of each spread -- a
	horned enemy, a sword, a fox -- which showed under every page the
	screen drew (owner, 2026-11-01: "the middle square has a constant
	silhouette"). It is painted out of all 21 source images, the cell laid
	back to the page's own paper, and these are the ids of the cleaned
	ones.

	**The three are not the same layout.** They look alike, but Codex drew
	each one separately: the enemy book's slots are 145 wide on a 199 pitch,
	the pet book's 125 on 186, the weapon book's 135 on 193, and the plaques
	and picture windows differ too. One shared set of boxes put the enemy
	grid up to 44 pixels out of its frames, so every book carries its own,
	measured off its own art (`assets/concepts/blocky/ui/codex/`).

	`turn` is the six frames of a page lifting and falling over the right
	page, and `turnWindow` is where they sit.

	**They are crops, not whole books.** Codex's frames are full 1672x941
	pictures and it re-rendered everything in each one: measured against
	the spread, a frame differs by around 450,000 pixels on the left page,
	the spine and the covers alone. Swapping the whole picture six times
	therefore shook the entire book (owner, 2026-11-01: "i dont want to see
	multiple frames of the spine and outer covers ... the only part
	changing should be the tan pages"). Each frame is cut down to the right
	page, and the screen lays that over a spread that never changes, so the
	covers and the spine cannot move. A little of the curl that strayed
	over the spine is lost with the crop, which is the trade.

	Frames 1 and 6 of each book are its resting page -- the page has not
	lifted yet, and has landed -- so a turn begins and ends exactly where
	the book already was. They are kept in the list rather than trimmed,
	because the animation reads as six evenly spaced frames and dropping
	the ends would make it start late and finish early.
]]

export type Box = { x: number, y: number, w: number, h: number }

--[[ The right page's nine slots: the first one's inner paper, and how far
     apart they sit. Nine to a page is what the art draws, not a choice. ]]
export type Grid = {
	x: number,
	y: number,
	w: number,
	h: number,
	stepX: number,
	stepY: number,
	columns: number,
	rows: number,
}

--[[ A book: what its tab says, the spread it is drawn on, its own
     page-turn frames, and where its own panels sit. ]]
export type Book = {
	title: string,
	spread: string,
	--[[ The six page-turn frames, each a crop of `turnWindow` only. ]]
	turn: { string },
	--[[ Where those crops sit on the spread. ]]
	turnWindow: Box,
	picture: Box,
	plaque: Box,
	description: Box,
	grid: Grid,
}

local Dex = {
	--[[ The spread's size in pixels, which every box below is measured
	     against. All three books are drawn at this size. ]]
	canvas = Vector2.new(1672, 941),

	--[[ A slot the player has not found is its own picture painted black,
	     which is how the sheet draws them: the shape reads, nothing else
	     does. ]]
	silhouette = Color3.new(0, 0, 0),
	--[[ What the plaque and the description say for one of those. ]]
	unknownName = "???",
	unknownLine = "NOT YET FOUND.",

	nameText = Color3.fromRGB(248, 243, 222),
	descriptionText = Color3.fromRGB(78, 58, 38),
	--[[ The count under the tabs, e.g. "FOUND 4/21". ]]
	countText = Color3.fromRGB(248, 243, 222),

	--[[ Seconds each page-turn frame holds, so the six run in about a
	     quarter of a second -- quick enough not to be in the way, slow
	     enough to read as paper. ]]
	turnFrame = 0.04,

	--[[ The tabs, in the order they sit over the book. ]]
	order = { "Enemies", "Weapons", "Pets" },

	books = {
		Enemies = {
			title = "ENEMIES",
			spread = "rbxassetid://90876700869692",
			turn = {
				"rbxassetid://109035273954193",
				"rbxassetid://136876704920447",
				"rbxassetid://90178165231095",
				"rbxassetid://92303148268076",
				"rbxassetid://123377439533587",
				"rbxassetid://109035273954193",
			},
			turnWindow = { x = 881, y = 63, w = 641, h = 787 },
			picture = { x = 277, y = 151, w = 343, h = 306 },
			plaque = { x = 228, y = 500, w = 470, h = 74 },
			description = { x = 190, y = 632, w = 532, h = 150 },
			grid = {
				x = 939,
				y = 158,
				w = 145,
				h = 140,
				stepX = 199.5,
				stepY = 217.5,
				columns = 3,
				rows = 3,
			},
		} :: Book,
		Weapons = {
			title = "WEAPONS",
			spread = "rbxassetid://80406021146225",
			turn = {
				"rbxassetid://92252170069851",
				"rbxassetid://114018728635440",
				"rbxassetid://94099856301650",
				"rbxassetid://80789324379036",
				"rbxassetid://135625505946484",
				"rbxassetid://92252170069851",
			},
			turnWindow = { x = 917, y = 55, w = 584, h = 810 },
			picture = { x = 239, y = 162, w = 356, h = 319 },
			plaque = { x = 200, y = 536, w = 442, h = 74 },
			description = { x = 165, y = 636, w = 520, h = 132 },
			grid = {
				x = 972,
				y = 215,
				w = 135,
				h = 105,
				stepX = 193.5,
				stepY = 198.5,
				columns = 3,
				rows = 3,
			},
		} :: Book,
		Pets = {
			title = "PETS",
			spread = "rbxassetid://117809291551852",
			turn = {
				"rbxassetid://120893746870118",
				"rbxassetid://94039092862444",
				"rbxassetid://96653216944445",
				"rbxassetid://75607890190572",
				"rbxassetid://132375454222207",
				"rbxassetid://120893746870118",
			},
			turnWindow = { x = 871, y = 81, w = 669, h = 757 },
			picture = { x = 307, y = 161, w = 328, h = 285 },
			plaque = { x = 250, y = 499, w = 450, h = 72 },
			description = { x = 203, y = 598, w = 542, h = 154 },
			grid = {
				x = 940,
				y = 198,
				w = 125,
				h = 123,
				stepX = 185.5,
				stepY = 186.5,
				columns = 3,
				rows = 3,
			},
		} :: Book,
	},
}

return table.freeze(Dex)
