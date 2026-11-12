--!strict
--[[
	The title screen's picture, "The World Tree at night" (`Config/TitleScene`,
	`Util/TitleLayout`, drawn by `UI/TitleScene`; owner, 2026-11-12).

	The picture is built from numbers, so what can go wrong is a number: a
	tree that turns gold, a hero standing in the air, a button over the hero
	on a phone nobody tried. These hold the owner's picked drawing (its two
	phone layouts, its counts and colours) and keep the logo, the hero and
	BEGIN ADVENTURE on screen and apart at every screen shape.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local Scene = require(ReplicatedStorage.Shared.Config.TitleScene)
local TestRunner = require(script.Parent.TestRunner)
local TitleLayout = require(ReplicatedStorage.Shared.Util.TitleLayout)

--[[ Phones upright and on their side, tablets, computers and an
     ultrawide. ]]
local SCREENS = {
	{ 390, 844 },
	{ 360, 800 },
	{ 360, 640 },
	{ 375, 667 },
	{ 414, 896 },
	{ 430, 932 },
	{ 768, 1024 },
	{ 820, 1180 },
	{ 844, 390 },
	{ 800, 360 },
	{ 640, 360 },
	{ 667, 375 },
	{ 932, 430 },
	{ 1024, 768 },
	{ 1180, 820 },
	{ 1366, 768 },
	{ 1920, 1080 },
	{ 1920, 1200 },
	{ 2560, 1080 },
}

local LAYOUTS: { [string]: Scene.Design } =
	{ portrait = Scene.portrait, landscape = Scene.landscape }

local function hue(colour: Color3): number
	local h = colour:ToHSV()
	return h * 360
end

return function(t: TestRunner.Helper)
	t.test("the two layouts are the drawing's phones, and fit them exactly", function()
		t.equal(Scene.portrait.width, 390)
		t.equal(Scene.portrait.height, 844)
		t.equal(Scene.landscape.width, 844)
		t.equal(Scene.landscape.height, 390)
		t.equal(TitleLayout.orientation(390, 844), "portrait")
		t.equal(TitleLayout.orientation(844, 390), "landscape")
		for _, design in LAYOUTS do
			local fit = TitleLayout.fit(design, design.width, design.height)
			t.near(fit.scale, 1, 1e-9)
			t.near(fit.x, 0, 1e-9)
			t.near(fit.y, 0, 1e-9)
			t.isTrue(design.safe.width <= design.width and design.safe.height <= design.height)
		end
	end)

	--[[ The owner's direction is the feeling of two dark fantasy games and
	     nothing of theirs: this tree is teal with mint lanterns, and a
	     glowing golden tree is exactly what it must not be. ]]
	t.test("the tree is teal with mint lanterns, never gold; only its windows are warm", function()
		local tree = Scene.tree
		local cool = {
			tree.trunkColour,
			tree.crownColours[1],
			tree.crownColours[2],
			tree.crownLit,
			tree.lantern,
			tree.lanternHalo,
			Scene.glow.colour,
			Scene.rim,
			Scene.mote.colour,
			Scene.farHill.colour,
			Scene.cloud.colour,
		}
		for index, colour in cool do
			local h = hue(colour)
			t.isTrue(h >= 150 and h <= 200, `colour {index} is teal or mint, hue {h}`)
		end
		local warm = hue(tree.window)
		t.isTrue(warm >= 25 and warm <= 55, `the windows are warm, hue {warm}`)
		t.equal(#tree.crown, 9, "nine crown squares")
		t.equal(#tree.lanterns, 15, "fifteen lanterns")
		t.equal(#tree.windows, 5, "five lit windows")
	end)

	t.test(
		"every window is on the trunk and every lantern hangs within the crown's width",
		function()
			local tree = Scene.tree
			for index, window in tree.windows do
				local on = false
				for _, part in tree.trunk do
					on = on
						or (
							window[1] >= part[1]
							and window[1] + 8 <= part[1] + part[3]
							and window[2] >= part[2]
							and window[2] + 10 <= part[2] + part[4]
						)
				end
				t.isTrue(on, `window {index} is inside a trunk block`)
			end
			local left, right, top = math.huge, -math.huge, math.huge
			for _, square in tree.crown do
				left = math.min(left, square[1])
				right = math.max(right, square[1] + square[3])
				top = math.min(top, square[2])
			end
			for index, lantern in tree.lanterns do
				t.isTrue(
					lantern[1] >= left and lantern[1] + lantern[3] <= right,
					`lantern {index} across`
				)
				t.isTrue(
					lantern[2] > top and lantern[2] < 0,
					`lantern {index} between crown top and ground`
				)
			end
		end
	)

	t.test(
		"the stars are the drawing's own: the same every time, in the sky above the hills",
		function()
			-- the reference page's generator, pinned by its first number from seed 7
			t.near(TitleLayout.random(7)(), 1025555898 / 4294967296, 1e-12)
			for key, design in LAYOUTS do
				local fit = TitleLayout.fit(design, design.width, design.height)
				local stars = TitleLayout.stars(design, fit)
				local again = TitleLayout.stars(design, fit)
				t.equal(#stars, design.stars.count, `{key}: no extra stars on its own screen`)
				for index, star in stars do
					t.isTrue(star.x >= 0 and star.x <= design.width, `{key} star {index} across`)
					t.isTrue(
						star.y >= 0 and star.y <= design.stars.below,
						`{key} star {index} down`
					)
					t.isTrue(star.alpha >= Scene.starFaint and star.alpha <= Scene.starBright)
					t.equal(star.x, again[index].x)
					t.equal(star.y, again[index].y)
				end
				-- above the far hills
				for _, hill in design.hills do
					t.isTrue(design.stars.below < hill[2], `{key}: stars stop above the hills`)
				end
			end
		end
	)

	t.test("a screen with more sky gets more stars, none on top of the drawing's", function()
		-- an upright tablet shows sky to both sides; a 4:3 one on its side, above
		for _, screen in { { 768, 1024 }, { 1024, 768 }, { 2560, 1080 } } do
			local design = TitleLayout.design(screen[1], screen[2])
			local fit = TitleLayout.fit(design, screen[1], screen[2])
			local stars = TitleLayout.stars(design, fit)
			t.isTrue(#stars > design.stars.count, `{screen[1]}x{screen[2]} has extra stars`)
			for index = design.stars.count + 1, #stars do
				local star = stars[index]
				local inside = star.x >= 0 and star.x <= design.width and star.y >= 0
				t.isFalse(inside, `extra star {index} is outside the drawing`)
			end
		end
	end)

	t.test("about a dozen motes start in their box, drift up and fade at both ends", function()
		for key, design in LAYOUTS do
			local motes = TitleLayout.motes(design)
			t.equal(#motes, design.motes.count)
			t.isTrue(#motes >= 10 and #motes <= 16, `{key}: about a dozen`)
			local box = design.motes.box
			for index, mote in motes do
				t.isTrue(
					mote.x >= box[1] and mote.x <= box[1] + box[3],
					`{key} mote {index} across`
				)
				t.isTrue(mote.y >= box[2] and mote.y <= box[2] + box[4], `{key} mote {index} down`)
				t.isTrue(mote.loop >= Scene.mote.loop[1] and mote.loop <= Scene.mote.loop[2])
			end
		end
		t.isTrue(Scene.mote.drift.y < 0, "they rise")
		t.near(TitleLayout.moteAlpha(0), 0, 1e-9)
		t.near(TitleLayout.moteAlpha(1), 0, 1e-9)
		t.near(TitleLayout.moteAlpha(Scene.mote.rise), Scene.mote.peak, 1e-9)
		for share = 0, 1, 0.05 do
			local alpha = TitleLayout.moteAlpha(share)
			t.isTrue(alpha >= 0 and alpha <= Scene.mote.peak + 1e-9, `at {share}`)
		end
	end)

	t.test(
		"the hero stands on the ridge's crest, left of the trunk, the pet at their heel",
		function()
			for key, design in LAYOUTS do
				local hero, pet = design.hero, design.pet
				-- the crest is the ridge's highest step, and it is under both of them
				local crest = design.ridge[1]
				for _, step in design.ridge do
					if step[2] < crest[2] then
						crest = step
					end
				end
				t.equal(hero.y, crest[2], `{key}: the hero's feet are on the crest`)
				t.equal(pet.y, crest[2], `{key}: the pet's are too`)
				t.isTrue(hero.x - 13 * hero.unit >= crest[1], `{key}: the hero is on it`)
				t.isTrue(pet.x + 24 * pet.unit <= crest[1] + crest[3], `{key}: the pet is on it`)
				-- left of the trunk (its roots run on behind the crest), the pet on the tree's side
				local trunk = design.tree.x + Scene.tree.trunk[2][1] * design.tree.unit
				t.isTrue(pet.x + 24 * pet.unit < trunk, `{key}: both stand left of the trunk`)
				t.isTrue(pet.x > hero.x + 13 * hero.unit, `{key}: the pet is beside the hero`)
				t.isTrue(pet.x - hero.x < 40, `{key}: and close`)
				-- tiny against the tree
				local treeTall = 398 * design.tree.unit
				t.isTrue(57 * hero.unit < treeTall / 4, `{key}: the hero is small, the tree huge`)
			end
		end
	)

	t.test("the bow on the hero's back is one curve from shoulder to hip", function()
		local bow = Scene.hero.bow
		local pieces = TitleLayout.curve(bow.from, bow.bend, bow.to, bow.pieces)
		t.equal(#pieces, bow.pieces)
		local function ends(piece: TitleLayout.Piece): (number, number, number, number)
			local dx = math.cos(math.rad(piece.turn)) * piece.long / 2
			local dy = math.sin(math.rad(piece.turn)) * piece.long / 2
			return piece.x - dx, piece.y - dy, piece.x + dx, piece.y + dy
		end
		local x0, y0 = ends(pieces[1])
		t.near(x0, bow.from[1], 1e-6)
		t.near(y0, bow.from[2], 1e-6)
		for index = 2, #pieces do
			local _, _, endX, endY = ends(pieces[index - 1])
			local startX, startY = ends(pieces[index])
			t.near(startX, endX, 1e-6, `piece {index} joins the one before`)
			t.near(startY, endY, 1e-6)
		end
		local _, _, x1, y1 = ends(pieces[#pieces])
		t.near(x1, bow.to[1], 1e-6)
		t.near(y1, bow.to[2], 1e-6)
	end)

	t.test(
		"the logo is ARROW over BORNE with its streak under it, clear of the tree upright",
		function()
			t.equal(Scene.logo.words[1], "ARROW")
			t.equal(Scene.logo.words[2], "BORNE")
			t.isTrue(Scene.logo.sizes[2] > Scene.logo.sizes[1], "BORNE is the larger line")
			for key, design in LAYOUTS do
				local logo = TitleLayout.logo(design)
				t.equal(#logo.lines, 2)
				t.near(logo.lines[2].top, logo.lines[1].top + logo.lines[1].tall, 1e-9)
				t.isTrue(
					logo.streakTop > logo.lines[2].top + logo.lines[2].tall,
					`{key}: streak under`
				)
				t.near(logo.left + logo.width / 2, design.width / 2, 1e-9, `{key}: centred`)
				t.near(logo.streakLeft + logo.streakWide / 2, design.width / 2, 1e-9)
			end
			local upright = Scene.portrait
			local crownTop = math.huge
			for _, square in Scene.tree.crown do
				crownTop = math.min(crownTop, upright.tree.y + square[2] * upright.tree.unit)
			end
			for _, square in Scene.tree.leaves do
				crownTop = math.min(crownTop, upright.tree.y + square[2] * upright.tree.unit)
			end
			t.isTrue(
				TitleLayout.logo(upright).bottom < crownTop,
				"upright, the logo sits above the crown"
			)
		end
	)

	t.test(
		"BEGIN ADVENTURE is the drawing's button: 358 by 84 upright, 380 by 72 sideways",
		function()
			t.equal(Intro.button, "BEGIN ADVENTURE")
			local upright, sideways = Scene.portrait.button, Scene.landscape.button
			t.equal(upright.width, 358)
			t.equal(upright.height, 84)
			t.equal((Scene.portrait.width - upright.width) / 2, 16, "16-point side gutters")
			t.equal(sideways.width, 380)
			t.equal(sideways.height, 72)
			t.equal(upright.words, 29)
			t.equal(sideways.words, 29)
			-- on its own phone it is exactly that size
			for _, design in LAYOUTS do
				local at =
					TitleLayout.button(design, TitleLayout.fit(design, design.width, design.height))
				t.near(at.width, design.button.width, 1e-9)
				t.near(at.height, design.button.height, 1e-9)
				t.near(at.words, 29, 1e-9)
			end
		end
	)

	--[[ The second pass of detail (owner, 2026-11-12: "a little bit more
	     detailed"). Each piece has to stand on what it belongs to, or it reads
	     as a mistake: a pine floating over a hill, grass in the air. ]]
	t.test("the added detail stands where it belongs", function()
		local tree = Scene.tree
		-- the doorway is inside the trunk's lowest step, the light inside its frame
		local foot, frame, glow = tree.trunk[2], tree.door.frame, tree.door.light
		t.isTrue(frame[1] >= foot[1] and frame[1] + frame[3] <= foot[1] + foot[3], "door across")
		t.isTrue(frame[2] >= foot[2] and frame[2] + frame[4] <= 0, "door down")
		t.isTrue(glow[1] >= frame[1] and glow[1] + glow[3] <= frame[1] + frame[3], "light in frame")
		t.isTrue(tree.strings.count <= #tree.lanterns)
		for key, design in LAYOUTS do
			for index, pine in design.pines do
				local on = false
				for _, hill in design.hills do
					on = on
						or (
							pine[2] == hill[2]
							and pine[1] >= hill[1]
							and pine[1] <= hill[1] + hill[3]
						)
				end
				t.isTrue(on, `{key} pine {index} stands on a hill's top`)
			end
			for index, tuft in design.tufts do
				local on = false
				for _, step in design.ridge do
					on = on
						or (
							tuft[2] == step[2]
							and tuft[1] >= step[1]
							and tuft[1] + 8 <= step[1] + step[3]
						)
				end
				t.isTrue(on, `{key} grass {index} grows on a ridge step`)
				-- and not under the hero or the pet
				local clear = tuft[2] ~= design.hero.y
					or tuft[1] + 8 < design.hero.x - 14 * design.hero.unit
					or tuft[1] > design.pet.x + 24 * design.pet.unit
				t.isTrue(clear, `{key} grass {index} is clear of the hero and pet`)
			end
			local post, standing = design.post, false
			for _, step in design.ridge do
				standing = standing
					or (
						post.y == step[2]
						and post.x >= step[1]
						and post.x + Scene.post.arm <= step[1] + step[3]
					)
			end
			t.isTrue(standing, `{key}: the lantern post stands on a ridge step`)
			for index, light in design.village do
				local on = false
				for _, hill in design.hills do
					on = on
						or (
							light[1] >= hill[1]
							and light[1] <= hill[1] + hill[3]
							and light[2] > hill[2]
						)
				end
				t.isTrue(on, `{key} village light {index} is on a hill`)
			end
			-- the farther hills sit under the stars, the clouds above every hill
			for index, hill in design.farHills do
				t.isTrue(hill[2] > design.stars.below, `{key} far hill {index} is below the stars`)
				for _, cloud in design.clouds do
					t.isTrue(cloud[2] + 10 < hill[2], `{key}: clouds are above far hill {index}`)
				end
			end
		end
		t.isTrue(
			Scene.twinkle.depth > 0 and Scene.twinkle.depth < 1,
			"a twinkling star never goes out"
		)
	end)

	--[[ The third pass (owner, 2026-11-12: the hero "should be a little bit
	     more noticeable"). The hero is larger than the first drawing's, still
	     small against the tree, which the test above holds. Their scarf is
	     their own colour, lit along its top, not a colour of its own (owner:
	     "the color of the scarf should match the player still"). ]]
	t.test("the hero is noticeable: larger, a lit scarf, a bow that stands clear", function()
		local look = Scene.hero
		for key, design in LAYOUTS do
			t.isTrue(design.hero.unit >= 1.3, `{key}: larger than the first drawing's hero`)
			t.isTrue(design.pet.unit < design.hero.unit, `{key}: the pet stays the smaller`)
		end
		t.isNil((look.scarf :: any).colour, "the scarf has no colour of its own")
		t.isTrue(look.scarf.rimAlpha > 0.3 and look.scarf.rim > 0, "and a line of light to show it")
		t.isTrue(#look.scarf.pieces >= 2, "long enough to trail")
		-- the bow's ends reach past the tunic's widest step, so they show
		local widest = 0
		for index = 1, 4 do
			widest = math.max(widest, look.body[index][1] + look.body[index][3])
		end
		t.isTrue(look.bow.to[1] > widest and look.bow.from[1] < -widest, "the bow's ends show")
		t.isTrue(
			look.glow.alpha > 0 and look.glow.alpha < 0.4,
			"a faint pool of light, not a spotlight"
		)
		for key, design in LAYOUTS do
			for index, cap in design.glowcaps do
				local on = false
				for _, step in design.ridge do
					on = on
						or (
							cap[2] == step[2]
							and cap[1] >= step[1]
							and cap[1] + cap[3] <= step[1] + step[3]
						)
				end
				t.isTrue(on, `{key} mushroom {index} grows on a ridge step`)
			end
			local sign, standing = design.sign, false
			for _, step in design.ridge do
				standing = standing
					or (
						sign.y == step[2]
						and sign.x - 2 >= step[1]
						and sign.x + 13 <= step[1] + step[3]
					)
			end
			t.isTrue(standing, `{key}: the signpost stands on a ridge step`)
			for index, bird in design.birds do
				for _, hill in design.farHills do
					t.isTrue(bird[2] + 10 < hill[2], `{key} bird {index} is in the sky`)
				end
			end
			local path = design.shooting
			t.isTrue(path.from[2] < design.stars.below and path.to[2] < design.stars.below)
		end
		t.isTrue(Scene.shooting.lasts < Scene.shooting.every, "a shooting star is rare")
	end)

	--[[ The drawing's sizes are the letters'; Roblox's TextSize is the font's
	     whole line. Without this the logo and BEGIN ADVENTURE come out a fifth
	     small (seen in Studio, 2026-11-12). ]]
	t.test("letter sizes are turned into Roblox's line sizes", function()
		t.near(Scene.letterLine, 1.21, 0.02, "Fredoka One's line over its letters' size")
	end)

	t.test("the button pulses gently and comes back to rest", function()
		local look = Scene.button
		t.near(TitleLayout.pulse(0), 1, 1e-9)
		t.near(TitleLayout.pulse(look.pulseEvery / 2), 1 + look.pulse, 1e-9)
		t.near(TitleLayout.pulse(look.pulseEvery), 1, 1e-9)
		t.isTrue(look.pulse > 0 and look.pulse <= 0.08, "gently")
	end)

	--[[ The check a phone would make. Everything is turned into screen points
	     the way `UI/TitleScene` places it, with the button as low as it sits
	     on a phone with no safe-area inset and as high as one with a home bar
	     (34 points) puts it. ]]
	t.test(
		"on every screen shape the logo, the hero and the button are on screen and apart",
		function()
			for _, screen in SCREENS do
				local w, h = screen[1], screen[2]
				local name = `{w}x{h}`
				local design = TitleLayout.design(w, h)
				local fit = TitleLayout.fit(design, w, h)
				local function sx(x: number): number
					return fit.x + x * fit.scale
				end
				local function sy(y: number): number
					return fit.y + y * fit.scale
				end
				-- the safe box fills the screen one way and fits the other
				t.isTrue(design.safe.width * fit.scale <= w + 1e-6, `{name}: safe box across`)
				t.isTrue(design.safe.height * fit.scale <= h + 1e-6, `{name}: safe box down`)

				local logo = TitleLayout.logo(design)
				local head = Scene.logo.streak.head
				t.isTrue(sy(logo.top) >= 0, `{name}: the logo's top is on screen`)
				t.isTrue(sx(logo.streakLeft) >= 0, `{name}: the streak's left end`)
				t.isTrue(
					sx(logo.streakLeft + logo.streakWide + head.overhang) <= w,
					`{name}: its arrowhead`
				)

				local hero, pet = design.hero, design.pet
				-- out to the scarf's end and up to the bow's tip
				local heroLeft, heroTop = sx(hero.x - 30 * hero.unit), sy(hero.y - 61 * hero.unit)
				local petRight, feet = sx(pet.x + 24 * pet.unit), sy(hero.y)
				t.isTrue(heroLeft >= 0 and petRight <= w, `{name}: the hero and pet across`)
				t.isTrue(heroTop >= 0 and feet <= h, `{name}: the hero and pet down`)
				t.isTrue(
					sx(design.moon.x) >= 0 and sx(design.moon.x + Scene.moon.size) <= w,
					`{name}: moon`
				)

				local button = TitleLayout.button(design, fit)
				local left = (w - button.width) / 2
				t.isTrue(left >= 8, `{name}: the button keeps a gutter, {left}`)
				t.isTrue(button.height >= 48, `{name}: tall enough for a finger, {button.height}`)
				for _, inset in { 0, 34 } do
					local top = h - inset - button.gap - button.height
					t.isTrue(top > sy(logo.bottom), `{name}: the button is under the logo`)
					if design == Scene.portrait then
						t.isTrue(top > feet, `{name}: the button is under the hero's feet`)
					else
						t.isTrue(left > petRight, `{name}: the button is right of the pet`)
					end
				end
			end
		end
	)
end
