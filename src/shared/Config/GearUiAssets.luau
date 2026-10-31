--!strict
--[[
	The Gear screen's pieces (owner, 2026-10-26: "build them 1:1"),
	cut pixel for pixel from the owner's approved mockup
	(`assets/concepts/blocky/ui/bubbly/gear_c.png`, 1920 x 1080) by
	`assets/ui/gear/mockup_cut.py`. Generated: re-run and re-upload instead of
	hand-editing. Each piece: its image and its box {x, y, w, h} on the mockup,
	which is the screen's 1920 x 1080 canvas. `...Blank` pieces have their
	words painted out for words the game writes (`Kit.glyphs`).
]]

export type Box = { x: number, y: number, w: number, h: number }

local GearUiAssets = {
	pieces = {
		Equipped = {
			image = "rbxassetid://70488365822950",
			box = { x = 850, y = 828, w = 216, h = 46 },
		},
		Inventory = {
			image = "rbxassetid://76529173199662",
			box = { x = 30, y = 615, w = 1860, h = 465 },
		},
		PillCoin = {
			image = "rbxassetid://93658475408456",
			box = { x = 1328, y = 45, w = 262, h = 105 },
		},
		PillGem = {
			image = "rbxassetid://111965597890093",
			box = { x = 1600, y = 45, w = 258, h = 105 },
		},
		SlotEmptyInner = {
			image = "rbxassetid://102740265628065",
			box = { x = 1322, y = 410, w = 234, h = 120 },
		},
		SlotPet1 = {
			image = "rbxassetid://132558240548300",
			box = { x = 1302, y = 152, w = 273, h = 203 },
		},
		SlotPet2 = {
			image = "rbxassetid://122432810519952",
			box = { x = 1302, y = 362, w = 273, h = 178 },
		},
		SlotTrail = {
			image = "rbxassetid://121598126683955",
			box = { x = 357, y = 338, w = 265, h = 192 },
		},
		SlotWeapon = {
			image = "rbxassetid://136959688307295",
			box = { x = 357, y = 105, w = 265, h = 225 },
		},
		Sort = {
			image = "rbxassetid://127931948994725",
			box = { x = 1502, y = 632, w = 336, h = 73 },
		},
		StatAtk = {
			image = "rbxassetid://134539097313382",
			box = { x = 528, y = 540, w = 277, h = 72 },
		},
		StatHp = {
			image = "rbxassetid://109102353729248",
			box = { x = 820, y = 540, w = 280, h = 72 },
		},
		StatSpd = {
			image = "rbxassetid://99399464548586",
			box = { x = 1117, y = 540, w = 281, h = 72 },
		},
		TabGoldBlank = {
			image = "rbxassetid://111605130188442",
			box = { x = 542, y = 632, w = 283, h = 73 },
		},
		TabGreyBlank = {
			image = "rbxassetid://117174203845458",
			box = { x = 835, y = 632, w = 267, h = 73 },
		},
		TabPetsGrey = {
			image = "rbxassetid://86810945735872",
			box = { x = 835, y = 632, w = 267, h = 73 },
		},
		TabTrailsGrey = {
			image = "rbxassetid://124692533656906",
			box = { x = 1112, y = 632, w = 280, h = 73 },
		},
		TabWeaponsGold = {
			image = "rbxassetid://91205987983698",
			box = { x = 542, y = 632, w = 283, h = 73 },
		},
		Tick = {
			image = "rbxassetid://103050324847924",
			box = { x = 1010, y = 740, w = 54, h = 46 },
		},
		TileCommon = {
			image = "rbxassetid://82043007561632",
			box = { x = 120, y = 728, w = 223, h = 147 },
		},
		TileEpic = {
			image = "rbxassetid://109112008912858",
			box = { x = 843, y = 885, w = 227, h = 147 },
		},
		TileLegendary = {
			image = "rbxassetid://99731548826335",
			box = { x = 1087, y = 728, w = 225, h = 147 },
		},
		TileLocked = {
			image = "rbxassetid://123867797662258",
			box = { x = 1328, y = 885, w = 227, h = 147 },
		},
		TileMythic = {
			image = "rbxassetid://108915955095640",
			box = { x = 1570, y = 885, w = 228, h = 147 },
		},
		TileRare = {
			image = "rbxassetid://132898167981061",
			box = { x = 600, y = 728, w = 228, h = 147 },
		},
		TileUncommon = {
			image = "rbxassetid://104029376269807",
			box = { x = 360, y = 728, w = 225, h = 147 },
		},
		Title = {
			image = "rbxassetid://77133131158716",
			box = { x = 700, y = 25, w = 522, h = 115 },
		},
	} :: { [string]: { image: string, box: Box } },
}

return table.freeze(GearUiAssets)
