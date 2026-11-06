--!strict
--[[
	The class select screen's pieces (owner, 2026-10-27: "i like the choose
	your class screen, make sure those are clickable"), cut from the approved
	mockup (`assets/concepts/blocky/ui/classes/class_select4.png`, 1920 x 1080)
	by `assets/ui/gear/classes`' cut. Each: image and box {x, y, w, h} on the
	mockup, the screen's canvas. The male Ranger and both Assassins were
	redrawn inside their sections at full size, and the female Ranger's bow
	fixed (owner, 2026-11-06: "make sure the male ranger and the male and
	female assassin are in their sections", "dont make them smaller", "fix
	the bow in the female rangers hand"):
	`assets/concepts/blocky/ui/classes/class_select_final.png`, built by
	`tools/class_select/compose.py` and cut along the same borders by
	`tools/class_select/recut.py`. `sections` are the eight slanted panels in
	order, each cut along its gold borders (transparent outside, and under
	the title and plates so an enlarged one shows no copy of them); `base` is
	the whole mockup behind them; `choose` / `choosePressed` the CHOOSE
	button (744 x 196 / 756 x 208 art, drawn in the class plates' style).
]]

export type Piece = { image: string, box: { x: number, y: number, w: number, h: number } }

local function piece(image: string, x: number, y: number, w: number, h: number): Piece
	return { image = image, box = { x = x, y = y, w = w, h = h } }
end

local ClassSelectAssets = {
	sections = {
		{
			class = "Ranger",
			look = "male",
			locked = false,
			piece = piece("rbxassetid://107007102886668", 0, 0, 390, 1080),
		},
		{
			class = "Ranger",
			look = "female",
			locked = false,
			piece = piece("rbxassetid://133629687056582", 117, 0, 498, 1080),
		},
		{
			class = "Arcanist",
			look = "male",
			locked = false,
			piece = piece("rbxassetid://118909891670728", 342, 0, 503, 1080),
		},
		{
			class = "Arcanist",
			look = "female",
			locked = false,
			piece = piece("rbxassetid://97111318996892", 572, 0, 498, 1080),
		},
		{
			class = "Warden",
			look = "male",
			locked = false,
			piece = piece("rbxassetid://124730486193657", 797, 0, 501, 1080),
		},
		{
			class = "Warden",
			look = "female",
			locked = false,
			piece = piece("rbxassetid://71028009264548", 1025, 0, 512, 1080),
		},
		{
			class = "Assassin",
			look = "male",
			locked = true,
			piece = piece("rbxassetid://126356383023454", 1264, 0, 499, 1080),
		},
		{
			class = "Assassin",
			look = "female",
			locked = true,
			piece = piece("rbxassetid://129009211539245", 1490, 0, 430, 1080),
		},
	} :: { { class: string, look: string, locked: boolean, piece: Piece } },
	base = piece("rbxassetid://75350427144183", 0, 0, 1920, 1080),
	title = piece("rbxassetid://137676218447234", 466, 26, 988, 136),
	plateRanger = piece("rbxassetid://81409055845751", 28, 908, 456, 122),
	plateArcanist = piece("rbxassetid://85077422603739", 495, 908, 459, 122),
	plateWarden = piece("rbxassetid://123372847397130", 966, 908, 458, 122),
	plateAssassin = piece("rbxassetid://96283032420995", 1434, 908, 460, 122),
	choose = "rbxassetid://77245583423110",
	choosePressed = "rbxassetid://71641839328109",

	--[[ The upright screen, for a phone held portrait (owner, 2026-11-05:
	     "make the character select screen the classes on top of eachother
	     instead of next to eachother horizontally"). One 1080x1920 picture
	     by Codex (`assets/concepts/blocky/ui/portrait/run.sh`): the title,
	     then a band per class top to bottom in `sections`' order, each split
	     at `split` into the male look on the left and the female on the
	     right, and a clear strip at the foot for CHOOSE. Uploaded as `tiles`,
	     `columns` across, each carrying `overlap` pixels past its cut.
	     `bands` are each band's top and bottom, and `choose` the button's
	     centre height, in the picture's pixels. No tiles keeps the landscape
	     screen on every device. ]]
	portrait = {
		size = Vector2.new(1080, 1920),
		tiles = {
			"rbxassetid://87125637360658",
			"rbxassetid://133869984267756",
			"rbxassetid://89867267438923",
			"rbxassetid://90029668117601",
		} :: { string },
		columns = 2,
		overlap = 8,
		split = 540,
		bands = {
			{ top = 196, bottom = 586 },
			{ top = 586, bottom = 961 },
			{ top = 961, bottom = 1315 },
			{ top = 1315, bottom = 1675 },
		},
		choose = 1797,
	},
}

return table.freeze(ClassSelectAssets)
