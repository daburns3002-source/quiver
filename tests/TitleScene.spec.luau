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
			tree.barkColour,
			tree.crownShade,
			Scene.mist.colour,
			Scene.peak.colour,
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

	--[[ The polish pass (owner, 2026-11-14: "a little bit more polished and
	     professional looking"): the logo's light is a smooth falloff, not
	     three bands; the arrow's light is the round glow like every other
	     light here; and none of it is cut off by a screen's edge. ]]
	t.test("the logo's glow falls away smoothly and is never cut by the screen", function()
		local look = Scene.logo
		t.isTrue(#look.glowRings >= 6, "many thin rings, not a few bands")
		local last = 0
		for index, reach in look.glowRings do
			t.isTrue(reach > last, `ring {index} reaches further than the one before`)
			t.isTrue(reach - last <= 3, `ring {index} is a thin step`)
			last = reach
		end
		t.isTrue(look.glowRingClear >= 0.94, "a ring alone is nearly clear")
		local core = 1 - look.glowRingClear ^ #look.glowRings
		t.isTrue(core > 0.2 and core < 0.4, `together they are a soft glow, {core}`)
		-- the arrow's light and the shade behind the words are the round picture
		local streak = look.streak
		t.isTrue(streak.headGlow.across > 1 and streak.headGlow.alpha > 0)
		t.isTrue(streak.soft.tall > 1 and streak.soft.from >= 0 and streak.soft.from < 1)
		t.isTrue(look.backing.wide > 1 and look.backing.tall > 1, "wider than the words")
		t.isTrue(look.backing.alpha > 0 and look.backing.alpha < 1, "soft, never a solid block")
		t.equal(look.backing.colour, Scene.sky[1], "the shade is the night sky's own dark")
		t.equal(#look.widths, #look.words)

		for _, screen in SCREENS do
			local w, h = screen[1], screen[2]
			local name = `{w}x{h}`
			local design = TitleLayout.design(w, h)
			local fit = TitleLayout.fit(design, w, h)
			local logo = TitleLayout.logo(design)
			local reach = (look.outlineThick + look.glowRings[#look.glowRings]) * design.logo.unit
			t.isTrue(logo.wordsWide <= logo.width, `{name}: the words fit the logo's box`)
			local left = fit.x + (design.width / 2 - logo.wordsWide / 2 - reach) * fit.scale
			t.isTrue(left >= 0, `{name}: the glow's side is on screen, {left}`)
			-- Fredoka One's capitals stand 0.37 of their size above the line's middle
			local line = logo.lines[1]
			local top = fit.y + (line.top + line.tall / 2 - 0.371 * line.size - reach) * fit.scale
			t.isTrue(top >= 0, `{name}: the glow's top is on screen, {top}`)
		end
	end)

	t.test(
		"the logo lands on the cut, its arrow shoots in, and a shine crosses now and then",
		function()
			local motion = Scene.logo.motion
			-- it lands: a little large on the cut, never under its size, exactly 1 after
			t.near(TitleLayout.logoPop(0), motion.pop.from, 1e-9)
			t.near(TitleLayout.logoPop(-3), motion.pop.from, 1e-9, "before the cut too")
			t.isTrue(motion.pop.from > 1 and motion.pop.from <= 1.2, "a little large, not a zoom")
			local last = TitleLayout.logoPop(0)
			for step = 1, 40 do
				local now = TitleLayout.logoPop(step * motion.pop.lasts / 40)
				t.isTrue(now <= last + 1e-9 and now >= 1 - 1e-9, `settling at step {step}`)
				last = now
			end
			t.near(TitleLayout.logoPop(motion.pop.lasts), 1, 1e-9)
			t.near(TitleLayout.logoPop(60), 1, 1e-9, "and it stays its size")

			-- the streak: nothing, then out to all of it, and never back
			t.near(TitleLayout.streakGrow(0), 0, 1e-9)
			t.near(TitleLayout.streakGrow(motion.streak.at), 0, 1e-9)
			local out = 0
			for step = 1, 40 do
				local now =
					TitleLayout.streakGrow(motion.streak.at + step * motion.streak.lasts / 40)
				t.isTrue(now >= out - 1e-9 and now <= 1 + 1e-9, `shooting out at step {step}`)
				out = now
			end
			t.near(TitleLayout.streakGrow(motion.streak.at + motion.streak.lasts), 1, 1e-9)
			t.near(TitleLayout.streakGrow(60), 1, 1e-9)

			-- both have finished before BEGIN ADVENTURE rises, so only one thing moves at a time
			local buttonAt = Intro.buttonAt - Intro.revealAt
			t.isTrue(motion.pop.lasts <= buttonAt, "landed before the button")
			t.isTrue(
				motion.streak.at + motion.streak.lasts <= buttonAt,
				"arrow in before the button"
			)

			-- the shine: none at first, a quick crossing, then a long rest
			local shine = motion.shine
			t.isNil(TitleLayout.shine(0))
			t.isNil(TitleLayout.shine(shine.first - 0.01))
			t.isTrue(shine.first >= buttonAt + Intro.buttonIn, "the first one waits for the button")
			t.near(TitleLayout.shine(shine.first) :: number, 0, 1e-9)
			t.near(TitleLayout.shine(shine.first + shine.lasts / 2) :: number, 0.5, 1e-9)
			t.isNil(TitleLayout.shine(shine.first + shine.lasts + 0.01))
			t.near(
				TitleLayout.shine(shine.first + 3 * shine.every + shine.lasts / 4) :: number,
				0.25,
				1e-9
			)
			t.isTrue(shine.every >= 5 * shine.lasts, "mostly at rest")
			t.isTrue(shine.alpha > 0 and shine.alpha < 1 and shine.wide > 0 and shine.wide < 0.5)
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

	--[[ Owner, 2026-11-14: "it needs to be more detailed still". The fourth
	     pass is more small things, and a small thing in the wrong place is a
	     house in the air or a line of light across the hero. ]]
	t.test("the fourth pass of detail stands where it belongs", function()
		local tree = Scene.tree
		-- bark is on the trunk, under the crown, and never across a window
		for index, strip in tree.bark do
			local on = false
			for _, part in tree.trunk do
				on = on
					or (
						strip[1] >= part[1]
						and strip[1] + 2 <= part[1] + part[3]
						and strip[2] >= part[2]
						and strip[2] + strip[3] <= part[2] + part[4]
					)
			end
			t.isTrue(on, `bark {index} is inside a trunk block`)
			t.isTrue(strip[2] >= -200, `bark {index} is below the crown`)
			for _, window in tree.windows do
				local apart = strip[1] + 2 <= window[1] - 1
					or strip[1] >= window[1] + 9
					or strip[2] + strip[3] <= window[2] - 1
					or strip[2] >= window[2] + 13
				t.isTrue(apart, `bark {index} is clear of the windows`)
			end
		end
		-- a sill stays on the trunk; the doorstep is under the door, on the trunk's foot
		for index, window in tree.windows do
			local on = false
			for _, part in tree.trunk do
				on = on
					or (
						window[1] - tree.sill.over >= part[1]
						and window[1] + 8 + tree.sill.over <= part[1] + part[3]
						and window[2] + 10 + tree.sill.tall <= part[2] + part[4]
						and window[2] + 10 >= part[2]
					)
			end
			t.isTrue(on, `window {index}'s sill is on the trunk`)
		end
		local step, frame = tree.doorStep, tree.door.frame
		t.isTrue(
			step[1] <= frame[1] and step[1] + step[3] >= frame[1] + frame[3],
			"a step as wide as the door"
		)
		t.near(step[2] + step[4], 0, 1e-9, "the step is on the ground")

		-- the flecks: the same every time, lit and shaded in turn, each in its own square
		local flecks = TitleLayout.flecks()
		t.equal(#flecks, #tree.crown * tree.flecks.each)
		local again = TitleLayout.flecks()
		local lit = 0
		for index, fleck in flecks do
			local square = tree.crown[(index - 1) // tree.flecks.each + 1]
			t.isTrue(fleck.x == again[index].x and fleck.y == again[index].y, `fleck {index} again`)
			t.isTrue(
				fleck.x >= square[1] and fleck.x + fleck.side <= square[1] + square[3],
				`fleck {index} across`
			)
			t.isTrue(
				fleck.y >= square[2] and fleck.y + fleck.side <= square[2] + square[3],
				`fleck {index} down`
			)
			t.isTrue(fleck.side >= tree.flecks.small and fleck.side <= tree.flecks.large)
			lit += if fleck.lit then 1 else 0
		end
		t.equal(lit * 2, #flecks, "half lit, half shaded")
		t.isTrue(tree.flecks.lit < 0.6 and tree.flecks.dark < 0.8, "flecks, not new squares")

		-- light is drawn only along a top that shows
		local edges = TitleLayout.topEdges({ { 0, 10, 10, 10 }, { 5, 5, 10, 10 } })
		t.equal(#edges, 2)
		t.near(edges[1][1], 0, 1e-9)
		t.near(edges[1][2], 5, 1e-9, "cut where the taller block stands")
		t.near(edges[1][3], 10, 1e-9)
		t.near(edges[2][1], 5, 1e-9)
		t.near(edges[2][2], 15, 1e-9)
		local level = TitleLayout.topEdges({ { 0, 0, 10, 5 }, { 5, 0, 10, 5 } })
		t.equal(#level, 2)
		t.near(level[1][2], 10, 1e-9)
		t.near(level[2][1], 10, 1e-9, "two tops at one height are lit once")
		t.equal(
			#TitleLayout.topEdges({ { 0, 10, 10, 10 }, { -5, 5, 20, 10 } }),
			1,
			"a covered top is not lit"
		)

		for key, design in LAYOUTS do
			-- the ridge's lit edge never crosses the ridge itself
			local steps = {}
			for index, part in design.ridge do
				table.insert(
					steps,
					{ part[1], part[2], part[3], if index == 1 then 400 else part[4] }
				)
			end
			for index, edge in TitleLayout.topEdges(steps) do
				for at, part in steps do
					local inside = edge[3] > part[2]
						and edge[3] < part[2] + part[4]
						and edge[2] > part[1] + 0.01
						and edge[1] < part[1] + part[3] - 0.01
					t.isFalse(inside, `{key} ridge edge {index} crosses step {at}`)
				end
			end
			for index, house in design.houses do
				local on = false
				for _, hill in design.hills do
					on = on
						or (
							house[2] == hill[2]
							and house[1] >= hill[1]
							and house[1] + house[3] <= hill[1] + hill[3]
						)
				end
				t.isTrue(on, `{key} house {index} stands on a hill's top`)
				for at, pine in design.pines do
					local apart = pine[2] ~= house[2]
						or pine[1] + pine[3] * 0.42 <= house[1] - house[3] * 0.1
						or pine[1] - pine[3] * 0.42 >= house[1] + house[3] * 1.1
					t.isTrue(apart, `{key} house {index} is clear of pine {at}`)
				end
			end
			local tower, standing = design.tower, false
			for _, hill in design.farHills do
				standing = standing
					or (
						tower.y == hill[2]
						and tower.x - 1.5 >= hill[1]
						and tower.x + Scene.tower.wide + 1.5 <= hill[1] + hill[3]
					)
			end
			t.isTrue(standing, `{key}: the watchtower stands on a far hill's top`)
			t.isTrue(
				tower.x + Scene.tower.wide + 1.5 <= design.width,
				`{key}: the tower is on the layout`
			)
			for index, band in design.mist do
				t.isTrue(band[2] > design.stars.below, `{key} mist {index} is under the stars`)
				t.isTrue(
					band[2] + 2 * Scene.mist.tall <= design.tree.y - Scene.ground.above,
					`{key} mist {index} is over the ground`
				)
			end
			local function onRidge(what: string, index: number, x: number, foot: number, w: number)
				local on = false
				for _, part in design.ridge do
					on = on or (foot == part[2] and x >= part[1] and x + w <= part[1] + part[3])
				end
				t.isTrue(on, `{key} {what} {index} stands on a ridge step`)
				-- and it is not buried in a higher step
				for at, part in design.ridge do
					local buried = part[2] < foot and x + w > part[1] and x < part[1] + part[3]
					t.isFalse(buried, `{key} {what} {index} is in step {at}`)
				end
				local clear = foot ~= design.hero.y
					or x + w < design.hero.x - 30 * design.hero.unit
					or x > design.pet.x + 24 * design.pet.unit
				t.isTrue(clear, `{key} {what} {index} is clear of the hero and pet`)
			end
			for index, stone in design.stones do
				onRidge("stone", index, stone[1], stone[2], stone[3])
			end
			for index, run in design.fences do
				onRidge("fence", index, run[1], run[2], (run[3] - 1) * Scene.fence.every + 2)
			end

			-- the sparkles are beside the words, never on them, on every screen
			local at = TitleLayout.logo(design)
			for index, spark in TitleLayout.sparkles(design) do
				local reach = spark.size * Scene.cross.long / 2 + 1
				for _, screen in SCREENS do
					if TitleLayout.design(screen[1], screen[2]) == design then
						local fit = TitleLayout.fit(design, screen[1], screen[2])
						t.isTrue(
							spark.x - reach >= fit.left and spark.x + reach <= fit.right,
							`{key} sparkle {index} is on a {screen[1]} x {screen[2]} screen`
						)
						t.isTrue(
							spark.y - reach >= fit.top,
							`{key} sparkle {index} is under the top`
						)
					end
				end
				t.isTrue(
					spark.y >= at.top and spark.y <= at.streakTop,
					`{key} sparkle {index} down`
				)
			end
		end
		t.isTrue(Scene.logo.sparkleAlpha <= 1 and #Scene.logo.sparkles <= 5, "a few, not a field")
		t.isTrue(
			Scene.ridgeRim.alpha < 0.4 and Scene.hillRim.near < 0.5,
			"a line of light, not an outline"
		)
	end)

	--[[ Owner, 2026-11-14, of the fourth pass: "More detail". The fifth is
	     larger things as well as small ones: mountains, leaf round the
	     crown, grass along the ridge, balconies. Each can still go wrong the
	     same way: a mountain whose foot shows, a sprig of leaf in the air. ]]
	t.test("the fifth pass of detail stands where it belongs", function()
		local tree = Scene.tree
		-- sprigs: the same every time, each standing out of its square and touching it
		local sprigs = TitleLayout.sprigs()
		local each = tree.sprigs.top + 3
		t.equal(#sprigs, #tree.crown * each)
		local again = TitleLayout.sprigs()
		for index, sprig in sprigs do
			local square = tree.crown[(index - 1) // each + 1]
			local far, low = square[1] + square[3], square[2] + square[3]
			t.isTrue(sprig.x == again[index].x and sprig.y == again[index].y, `sprig {index} again`)
			t.isTrue(
				sprig.side >= tree.sprigs.small and sprig.side <= tree.sprigs.large,
				`sprig {index}'s size`
			)
			local touches = sprig.x < far
				and sprig.x + sprig.side > square[1]
				and sprig.y < low
				and sprig.y + sprig.side > square[2]
			t.isTrue(touches, `sprig {index} grows from its square`)
			local inside = sprig.x >= square[1]
				and sprig.x + sprig.side <= far
				and sprig.y >= square[2]
				and sprig.y + sprig.side <= low
			t.isFalse(inside, `sprig {index} stands out of its square`)
		end

		-- a balcony or a shelf mushroom is against the trunk's side, clear of the windows
		local function onSide(
			what: string,
			index: number,
			x: number,
			y: number,
			w: number,
			h: number
		)
			local held = false
			for _, part in tree.trunk do
				local level = y >= part[2] and y + h <= part[2] + part[4]
				held = held or (level and (x + w == part[1] or x == part[1] + part[3]))
			end
			t.isTrue(held, `{what} {index} is against the trunk's side`)
			for at, window in tree.windows do
				local apart = x + w <= window[1] or x >= window[1] + 8
				t.isTrue(apart, `{what} {index} is clear of window {at}`)
			end
		end
		for index, at in tree.balconies do
			onSide("balcony", index, at[1], at[2], at[3], tree.balcony.floor)
			for _, vine in tree.vines do
				t.isTrue(
					at[2] - tree.balcony.rail > vine[2] + vine[3],
					`balcony {index} is under the vines`
				)
			end
			local hung = at[2] + tree.balcony.floor + tree.balcony.string + tree.balcony.lantern
			t.isTrue(hung < -44, `balcony {index}'s lantern hangs clear of the trunk's foot`)
		end
		for index, at in tree.shelves do
			onSide("shelf", index, at[1], at[2], at[3], tree.shelf.tall)
		end
		t.isTrue(#tree.balconies <= 3 and #tree.shelves <= 6, "a few, the trunk is not a ladder")

		-- leaf tiers: the same every time, each inside its square, one in each part of its height
		local tiers = TitleLayout.tiers()
		t.equal(#tiers, #tree.crown * tree.tiers.each)
		local same = TitleLayout.tiers()
		for index, tier in tiers do
			local square = tree.crown[(index - 1) // tree.tiers.each + 1]
			t.isTrue(tier.x == same[index].x and tier.y == same[index].y, `tier {index} again`)
			t.isTrue(
				tier.x >= square[1] and tier.x + tier.long <= square[1] + square[3],
				`tier {index} across`
			)
			t.isTrue(
				tier.y >= square[2] and tier.y + 2 * tree.tiers.thick <= square[2] + square[3],
				`tier {index} down`
			)
			if (index - 1) % tree.tiers.each > 0 then
				t.isTrue(tier.y > tiers[index - 1].y, `tier {index} is under the one before`)
			end
		end
		t.isTrue(tree.tiers.long < 0.7 and tree.tiers.lit < 0.6, "edges of leaf, not stripes")

		-- the awning: over the door, wider than it, on the trunk
		local awning, frame = tree.awning, tree.door.frame
		t.isTrue(
			awning[1] < frame[1] and awning[1] + awning[3] > frame[1] + frame[3],
			"wider than the door"
		)
		t.isTrue(awning[2] + awning[4] <= frame[2], "over the door")
		local base = tree.trunk[2]
		t.isTrue(
			awning[1] >= base[1]
				and awning[1] + awning[3] <= base[1] + base[3]
				and awning[2] >= base[2],
			"on the trunk"
		)

		for key, design in LAYOUTS do
			-- a far mountain: under the stars, its foot behind the near hills, its lean slight
			for index, at in design.peaks do
				local mid, foot, w, h = at[1], at[2], at[3], at[4]
				t.isTrue(foot - h >= design.stars.below, `{key} peak {index} is under the stars`)
				for step = 0, 4 do
					local x = math.clamp(mid - w / 2 + w * step / 4, 0, design.width)
					local hidden = false
					for _, hill in design.hills do
						hidden = hidden
							or (x >= hill[1] and x <= hill[1] + hill[3] and hill[2] <= foot)
					end
					t.isTrue(hidden, `{key} peak {index}'s foot is behind a hill at {x}`)
				end
				t.isTrue(math.abs(at[5]) <= 0.2, `{key} peak {index} leans a little`)
			end
			-- a far pine: on a far hill's top, smaller than the near ones, clear of the tower
			local smallest = math.huge
			for _, pine in design.pines do
				smallest = math.min(smallest, pine[3])
			end
			for index, pine in design.farPines do
				local half = pine[3] * 0.42
				local on = false
				for _, hill in design.farHills do
					on = on
						or (
							pine[2] == hill[2]
							and pine[1] - half >= hill[1]
							and pine[1] + half <= hill[1] + hill[3]
						)
				end
				t.isTrue(on, `{key} far pine {index} stands on a far hill's top`)
				t.isTrue(pine[3] <= smallest, `{key} far pine {index} is no larger than a near one`)
				local tower = design.tower
				local apart = pine[1] + half <= tower.x - 1.5
					or pine[1] - half >= tower.x + Scene.tower.wide + 1.5
				t.isTrue(apart, `{key} far pine {index} is clear of the watchtower`)
			end
			-- grass: on a ridge top that shows, wholly on its edge
			local steps = {}
			for index, part in design.ridge do
				table.insert(
					steps,
					{ part[1], part[2], part[3], if index == 1 then 400 else part[4] }
				)
			end
			local edges = TitleLayout.topEdges(steps)
			local blades = TitleLayout.blades(steps)
			t.isTrue(#blades > 20, `{key}: grass all along the ridge`)
			for index, blade in blades do
				local on = false
				for _, edge in edges do
					on = on
						or (
							blade.foot == edge[3]
							and blade.x >= edge[1]
							and blade.x + Scene.fringe.wide <= edge[2]
						)
				end
				t.isTrue(on, `{key} blade {index} is on a ridge top that shows`)
				t.isTrue(blade.tall >= Scene.fringe.short and blade.tall <= Scene.fringe.long)
				t.equal(blade.flower, blade.tall > Scene.flower.over)
			end
			-- star dust: over the sky only, fainter and smaller than a star
			for _, screen in SCREENS do
				if TitleLayout.design(screen[1], screen[2]) == design then
					local fit = TitleLayout.fit(design, screen[1], screen[2])
					local dust = TitleLayout.dust(design, fit)
					t.isTrue(#dust >= 40 and #dust <= Scene.dust.most, `{key}: dust at {screen[1]}`)
					for _, speck in dust do
						t.isTrue(speck.y <= design.stars.below and speck.alpha <= Scene.dust.bright)
					end
				end
			end
		end
		t.isTrue(
			Scene.dust.size < 2 and Scene.dust.bright < Scene.starBright,
			"dust, not more stars"
		)
		t.isTrue(Scene.peak.alpha + Scene.peak.snowAlpha < 0.4, "mountains are far: pale and faint")
		t.isTrue(Scene.fringe.long < 6, "grass, not reeds")
		t.isTrue(
			Scene.flower.over > (Scene.fringe.short + Scene.fringe.long) / 2,
			"a flower on the tallest blades only"
		)
	end)

	--[[ Owner, 2026-11-12: "make the stars perfect crosses like this +". On a
	     screen a cross is perfect only if it is built on whole pixels with an
	     odd length and thickness: one middle pixel, four equal arms. ]]
	t.test("every star is a perfect cross at every size and scale", function()
		for _, scale in { 0.76, 0.92, 1, 1.35, 2, 2.85 } do
			for _, size in { 2, 3, Scene.bigStar.size } do
				for _, at in { { 10, 10 }, { 33.3, 71.7 }, { 251.5, 12.49 } } do
					local bars = TitleLayout.cross(at[1], at[2], size, scale)
					local across, up, down = bars[1], bars[2], bars[3]
					local name = `size {size} at scale {scale}`
					for _, bar in bars do
						for _, value in bar do
							t.equal(value, math.floor(value), `{name}: whole pixels`)
						end
					end
					t.equal(across[3] % 2, 1, `{name}: an odd length`)
					t.equal(across[4] % 2, 1, `{name}: an odd thickness`)
					-- the arms above and below are the same, and as long as the ones to the sides
					t.equal(up[4], down[4], `{name}: up and down arms equal`)
					t.equal(up[4] * 2 + across[4], across[3], `{name}: as tall as it is wide`)
					t.isTrue(up[4] >= 1, `{name}: it has arms`)
					-- the upright shares the bar's middle, and the three pieces meet without overlapping
					t.equal(up[1] * 2 + up[3], across[1] * 2 + across[3], `{name}: centred`)
					t.equal(up[2] + up[4], across[2], `{name}: the top arm meets the bar`)
					t.equal(down[2], across[2] + across[4], `{name}: the bottom arm meets the bar`)
					t.equal(up[3], across[4], `{name}: arms as thick as the bar`)
				end
			end
		end
		-- and no light sits on a square: each glow is the round picture, sized from its light
		t.isNil((Scene.moonHalo :: any).grow, "the moon's glow is round")
		t.isTrue(
			Scene.moonHalo.across > 1 and Scene.tree.lanternGlow > 1 and Scene.mote.haloSize > 1
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
		-- a mushroom's light is the round glow, never a square (owner, 2026-11-12)
		t.isNil((Scene.glowcap :: any).halo, "no square of light round a mushroom")
		t.isTrue(
			Scene.glowcap.glow > 1 and Scene.glowcap.glowAlpha > 0,
			"a soft round light instead"
		)
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
