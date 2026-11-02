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
	page. The left page does not move in them, so a turn hides the grid,
	plays the six, and shows the next nine.

	Frames 1 and 6 of each book are its resting spread -- the page has not
	lifted yet, and has landed -- so a turn begins and ends where the book
	already was and only frames 2 to 5 show paper in the air. They are kept
	in the list rather than trimmed, because the animation reads as six
	evenly spaced frames and dropping the ends would make it start late and
	finish early.
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
	turn: { string },
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
				"rbxassetid://140036952821236",
				"rbxassetid://71332474798830",
				"rbxassetid://134293298002938",
				"rbxassetid://84001533560193",
				"rbxassetid://136709529671449",
				"rbxassetid://90876700869692",
			},
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
				"rbxassetid://123626260880925",
				"rbxassetid://75661339663233",
				"rbxassetid://73286053052315",
				"rbxassetid://73080602888875",
				"rbxassetid://122411507598479",
				"rbxassetid://81051730028159",
			},
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
				"rbxassetid://78667437217662",
				"rbxassetid://102593702597549",
				"rbxassetid://134732318913442",
				"rbxassetid://73788556188024",
				"rbxassetid://113240965652523",
				"rbxassetid://119442228805279",
			},
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
