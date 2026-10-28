--!strict
--[[
	The Egg Hatchery screen's pieces (owner, 2026-10-26: "build them 1:1"),
	cut pixel for pixel from the owner's approved mockup
	(`assets/concepts/blocky/ui/bubbly/hatchery_c.png`, 1920 x 1080) by
	`assets/ui/gear/mockup_cut.py`. Generated: re-run and re-upload instead of
	hand-editing. Each piece: its image and its box {x, y, w, h} on the mockup,
	which is the screen's 1920 x 1080 canvas. `...Blank` pieces have their
	words painted out for words the game writes (`Kit.glyphs`).
]]

export type Box = { x: number, y: number, w: number, h: number }

local HatchUiAssets = {
	pieces = {
		CardMossy = {
			image = "rbxassetid://114988702859408",
			box = { x = 38, y = 205, w = 584, h = 257 },
		},
		CardThornwood = {
			image = "rbxassetid://94529570788452",
			box = { x = 40, y = 472, w = 580, h = 250 },
		},
		EggPlate = {
			image = "rbxassetid://78489599873879",
			box = { x = 652, y = 180, w = 566, h = 102 },
		},
		EggPlateBlank = {
			image = "rbxassetid://107247858148756",
			box = { x = 652, y = 180, w = 566, h = 102 },
		},
		Hatch1 = {
			image = "rbxassetid://130363099173169",
			box = { x = 528, y = 845, w = 350, h = 177 },
		},
		Hatch1Blank = {
			image = "rbxassetid://82399480127165",
			box = { x = 528, y = 845, w = 350, h = 177 },
		},
		Hatch3 = {
			image = "rbxassetid://140313721674838",
			box = { x = 890, y = 845, w = 350, h = 177 },
		},
		Hatch3Blank = {
			image = "rbxassetid://135699735878869",
			box = { x = 890, y = 845, w = 350, h = 177 },
		},
		Inside = {
			image = "rbxassetid://132413183557734",
			box = { x = 1255, y = 175, w = 607, h = 855 },
		},
		PetBabacorn = {
			image = "rbxassetid://123415091803754",
			box = { x = 1472, y = 265, w = 171, h = 167 },
		},
		PetEmberWilfPet = {
			image = "rbxassetid://108171795566896",
			box = { x = 1472, y = 795, w = 171, h = 175 },
		},
		PetFernFrog = {
			image = "rbxassetid://115980808242813",
			box = { x = 1655, y = 265, w = 173, h = 167 },
		},
		PetFireflyBun = {
			image = "rbxassetid://123242247180786",
			box = { x = 1655, y = 443, w = 173, h = 167 },
		},
		PetGladeFox = {
			image = "rbxassetid://126555275634815",
			box = { x = 1472, y = 620, w = 171, h = 167 },
		},
		PetGlimmerhorn = {
			image = "rbxassetid://76617526449292",
			box = { x = 1655, y = 795, w = 173, h = 175 },
		},
		PetHootmoss = {
			image = "rbxassetid://76634149995185",
			box = { x = 1655, y = 620, w = 173, h = 167 },
		},
		PetMossbackSnail = {
			image = "rbxassetid://132626106287776",
			box = { x = 1472, y = 443, w = 171, h = 167 },
		},
		PetMosslet = {
			image = "rbxassetid://101870165059122",
			box = { x = 1290, y = 265, w = 170, h = 167 },
		},
		PetSlimePrince = {
			image = "rbxassetid://89682848319677",
			box = { x = 1290, y = 795, w = 170, h = 175 },
		},
		PetStumpy = {
			image = "rbxassetid://90634308170468",
			box = { x = 1290, y = 620, w = 170, h = 167 },
		},
		PetToadstoolTot = {
			image = "rbxassetid://128484444586494",
			box = { x = 1290, y = 443, w = 170, h = 167 },
		},
		PillCoin = {
			image = "rbxassetid://132439752377289",
			box = { x = 1340, y = 45, w = 255, h = 110 },
		},
		PillGem = {
			image = "rbxassetid://97559600730178",
			box = { x = 1605, y = 45, w = 250, h = 110 },
		},
		Title = {
			image = "rbxassetid://91565858560032",
			box = { x = 590, y = 25, w = 720, h = 130 },
		},
	} :: { [string]: { image: string, box: Box } },
}

return table.freeze(HatchUiAssets)
