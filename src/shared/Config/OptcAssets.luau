--!strict
--[[
	The Blacksmith screen's pieces cut pixel for pixel from the owner's chosen
	mockup (`assets/concepts/blocky/ui/bubbly/option_c.png`; owner, 2026-10-26:
	"I NEED IT TO BE 1 TO 1"), by `assets/ui/gear/optc_cut.py`. Generated: do
	not hand-edit; re-run the script and re-upload instead.

	- `pieces`: each piece's image and its box on the 1920 x 1080 mockup
	  {x, y, w, h}, the same canvas the screen is laid out on. Pieces whose
	  words never change keep them as drawn; `...Blank` ones have them painted
	  out for words the game writes.
	- `glyphs`: the mockup's own lettering as a font (`font/glyphs_raw.png`),
	  each character's cell {x, y, w, h} on `glyphSheet`; 128 px tall cells.
]]

export type Box = { x: number, y: number, w: number, h: number }

local OptcAssets = {
	pieces = {
		NamePlate = {
			image = "rbxassetid://134524520965385",
			box = { x = 578, y = 250, w = 650, h = 102 },
		},
		Title = {
			image = "rbxassetid://98405880106913",
			box = { x = 630, y = 28, w = 660, h = 112 },
		},
		TabStoreGrey = {
			image = "rbxassetid://132871281201273",
			box = { x = 960, y = 143, w = 296, h = 97 },
		},
		TabGreyBlank = {
			image = "rbxassetid://104501121999897",
			box = { x = 960, y = 143, w = 296, h = 97 },
		},
		PillGem = {
			image = "rbxassetid://117222321358582",
			box = { x = 1600, y = 45, w = 256, h = 107 },
		},
		TabGoldBlank = {
			image = "rbxassetid://97565877740816",
			box = { x = 658, y = 143, w = 298, h = 97 },
		},
		TabCratesGold = {
			image = "rbxassetid://132893803809857",
			box = { x = 658, y = 143, w = 298, h = 97 },
		},
		OpenButtonBlank = {
			image = "rbxassetid://133486607155054",
			box = { x = 572, y = 822, w = 576, h = 200 },
		},
		OpenButton = {
			image = "rbxassetid://98605008555078",
			box = { x = 572, y = 822, w = 576, h = 200 },
		},
		Stone = {
			image = "rbxassetid://75754091257232",
			box = { x = 558, y = 690, w = 592, h = 132 },
		},
		PillCoin = {
			image = "rbxassetid://117856521991880",
			box = { x = 1328, y = 45, w = 262, h = 107 },
		},
		Inside = {
			image = "rbxassetid://87012250993651",
			box = { x = 1262, y = 236, w = 536, h = 788 },
		},
		NamePlateBlank = {
			image = "rbxassetid://95853706574870",
			box = { x = 578, y = 250, w = 650, h = 102 },
		},
	} :: { [string]: { image: string, box: Box } },
	glyphSheet = "rbxassetid://75741207023748",
	glyphs = {
		["A"] = { x = 25, y = 0, w = 80, h = 128 },
		["B"] = { x = 152, y = 0, w = 81, h = 128 },
		["C"] = { x = 281, y = 0, w = 79, h = 128 },
		["D"] = { x = 408, y = 0, w = 81, h = 128 },
		["E"] = { x = 536, y = 0, w = 80, h = 128 },
		["F"] = { x = 664, y = 0, w = 80, h = 128 },
		["G"] = { x = 791, y = 0, w = 81, h = 128 },
		["H"] = { x = 919, y = 0, w = 81, h = 128 },
		["I"] = { x = 37, y = 128, w = 56, h = 128 },
		["J"] = { x = 152, y = 128, w = 78, h = 128 },
		["K"] = { x = 277, y = 128, w = 84, h = 128 },
		["L"] = { x = 407, y = 128, w = 83, h = 128 },
		["M"] = { x = 528, y = 128, w = 95, h = 128 },
		["N"] = { x = 660, y = 128, w = 87, h = 128 },
		["O"] = { x = 789, y = 128, w = 85, h = 128 },
		["P"] = { x = 919, y = 128, w = 82, h = 128 },
		["Q"] = { x = 22, y = 256, w = 85, h = 128 },
		["R"] = { x = 152, y = 256, w = 81, h = 128 },
		["S"] = { x = 279, y = 256, w = 82, h = 128 },
		["T"] = { x = 402, y = 256, w = 89, h = 128 },
		["U"] = { x = 534, y = 256, w = 83, h = 128 },
		["V"] = { x = 663, y = 256, w = 82, h = 128 },
		["W"] = { x = 781, y = 256, w = 103, h = 128 },
		["X"] = { x = 913, y = 256, w = 95, h = 128 },
		["Y"] = { x = 21, y = 384, w = 86, h = 128 },
		["Z"] = { x = 151, y = 384, w = 83, h = 128 },
		["0"] = { x = 280, y = 384, w = 81, h = 128 },
		["1"] = { x = 415, y = 384, w = 66, h = 128 },
		["2"] = { x = 534, y = 384, w = 83, h = 128 },
		["3"] = { x = 664, y = 384, w = 79, h = 128 },
		["4"] = { x = 791, y = 384, w = 82, h = 128 },
		["5"] = { x = 919, y = 384, w = 82, h = 128 },
		["6"] = { x = 23, y = 512, w = 84, h = 128 },
		["7"] = { x = 151, y = 512, w = 82, h = 128 },
		["8"] = { x = 279, y = 512, w = 83, h = 128 },
		["9"] = { x = 407, y = 512, w = 82, h = 128 },
		["%"] = { x = 528, y = 512, w = 97, h = 128 },
		["."] = { x = 685, y = 512, w = 38, h = 128 },
		["!"] = { x = 807, y = 512, w = 49, h = 128 },
		["+"] = { x = 919, y = 512, w = 81, h = 128 },
		["-"] = { x = 28, y = 640, w = 72, h = 128 },
		[":"] = { x = 173, y = 640, w = 38, h = 128 },
		["/"] = { x = 278, y = 640, w = 81, h = 128 },
		["'"] = { x = 427, y = 640, w = 42, h = 128 },
		["?"] = { x = 534, y = 640, w = 83, h = 128 },
		[","] = { x = 685, y = 640, w = 40, h = 128 },
		["("] = { x = 803, y = 640, w = 55, h = 128 },
		[")"] = { x = 934, y = 640, w = 55, h = 128 },
	} :: { [string]: Box },
}

return table.freeze(OptcAssets)
