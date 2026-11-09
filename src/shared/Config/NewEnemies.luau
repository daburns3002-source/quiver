--!strict
--[[
	The NEW ENEMY! screen (owner, 2026-10-25: "NEW ENEMY! screens for each
	enemy besides bosses. this screen should have a picture and brief
	description of each enemy. also the banner that they appear on should be
	themed to the area they are discovered in"), drawn by `UI/NewEnemyScreen`.

	The first time a player meets a kind of enemy (once per server visit
	until there is a save), its screen comes up and the run holds until GOT
	IT! is pressed (owner's pick, 2026-10-25): `RunSession.meetEnemy`.

	Each area's screen is the owner's approved Codex sheet, 1:1
	(`assets/concepts/blocky/ui/new_enemy/sheet_<area>_a.png`), with its
	picture window, name plate and description box emptied by Codex; the
	banner, the area's plaque and GOT IT! are the sheet's own. The game puts
	the enemy's picture, name and description in, at the boxes below,
	measured in the sheet's pixels (1024 × 1536, { x, y, w, h } from its
	top left). Cut and halved by `assets/ui/new_enemy/cutout.py` (Roblox
	shrinks anything over 1024 px), the sheet's dark ground cut away and an
	ink border drawn round the card (owner: "make sure theres a border on
	the card"), uploaded through Studio's MCP.

	Keyed by the kind's `EnemyConfig.displayName`. The sheet is the stage's
	area's (`Balance.Stages` `area`), or the enemy's own `area` in a stage
	with none. Areas 1-4; Drowned Village's four wait for their enemies.
]]

export type Box = { x: number, y: number, w: number, h: number }

export type Sheet = {
	--[[ The sheet's top and bottom halves, 1024 × 768 each. ]]
	top: string,
	bottom: string,
	--[[ Where the enemy stands: a square whose bottom edge is the window's
	     ground. ]]
	picture: Box,
	name: Box,
	description: Box,
	--[[ The sheet's GOT IT! button, pressed where it is drawn. ]]
	button: Box,
	--[[ The description's colour, as the sheet writes it. ]]
	text: Color3,
}

export type Enemy = {
	name: string,
	description: string,
	picture: string,
	--[[ The area it is from, for a stage without one. ]]
	area: string,
	--[[ Out of the game but kept here, so it shows on neither the loading
	     screen nor the dex. The Drowned Village's three unbuilt
	     enemies are (2026-11-07); the Ember Wilf was, until the owner took
	     it out for good on 2026-11-01. ]]
	benched: boolean?,
}

local WHITE = Color3.fromRGB(248, 248, 240)

local NewEnemies = {
	canvas = Vector2.new(1024, 1536),
	--[[ Share of the screen's height the sheet fills (the end screens' 97%,
	     less, so the room's edge still frames it), and how dark the room is
	     behind it (0 clear, 1 black). ]]
	height = 0.94,
	shade = 0.6,
	--[[ The names' and descriptions' largest letters, in sheet pixels (the
	     sheet's own sizes), and the names' ink outline. ]]
	nameSize = 72,
	descriptionSize = 44,
	ink = Color3.fromRGB(27, 27, 43),
	inkWidth = 7,
	--[[ Seconds: the sheet drops in from above and settles, and on GOT IT!
	     dips and sweeps back up (owner, 2026-10-25: "a smooth animation when
	     the card comes in and when it leaves"). GOT IT! is ignored until it
	     has landed, so a press meant for the fight does not close it unread.
	     `overshoot` is how far it swings past its place (a back ease), `tilt`
	     the degrees it leans while it moves. Only place and lean move, never
	     size (CLAUDE.md, the cards). ]]
	enter = 0.55,
	leave = 0.4,
	ready = 0.55,
	overshoot = 1.1,
	tilt = 4,

	sheets = {
		MossyGlade = {
			top = "rbxassetid://106895139421394",
			bottom = "rbxassetid://90131719754233",
			picture = { x = 262, y = 372, w = 500, h = 500 },
			name = { x = 140, y = 972, w = 744, h = 96 },
			description = { x = 160, y = 1112, w = 704, h = 158 },
			button = { x = 228, y = 1308, w = 568, h = 170 },
			text = WHITE,
		},
		Thornwood = {
			top = "rbxassetid://85607428729038",
			bottom = "rbxassetid://76855273182493",
			picture = { x = 262, y = 372, w = 500, h = 500 },
			name = { x = 195, y = 925, w = 635, h = 88 },
			description = { x = 160, y = 1065, w = 704, h = 170 },
			button = { x = 192, y = 1272, w = 640, h = 176 },
			text = WHITE,
		},
		DrownedVillage = {
			top = "rbxassetid://132497473352231",
			bottom = "rbxassetid://106547135805034",
			picture = { x = 257, y = 418, w = 510, h = 510 },
			name = { x = 165, y = 978, w = 694, h = 96 },
			description = { x = 185, y = 1122, w = 654, h = 156 },
			button = { x = 228, y = 1302, w = 568, h = 186 },
			text = WHITE,
		},
		--[[ Bogheart Caverns (Codex, 2026-11-06, `sheet_bogheart_caverns_a.png`):
		     not yet approved by the owner. ]]
		BogheartCaverns = {
			top = "rbxassetid://115969921487794",
			bottom = "rbxassetid://114438065574510",
			picture = { x = 257, y = 420, w = 510, h = 510 },
			name = { x = 230, y = 975, w = 564, h = 90 },
			description = { x = 130, y = 1110, w = 764, h = 170 },
			button = { x = 200, y = 1320, w = 630, h = 150 },
			text = WHITE,
		},
	} :: { [string]: Sheet },

	enemies = {
		-- Mossy Glade
		Charger = {
			name = "MOSS SLIME",
			description = "Hops straight at you. Keep moving, then shoot when it's close!",
			picture = "rbxassetid://89089795107429",
			area = "MossyGlade",
		},
		Spitter = {
			name = "SPLITTER SPITTER",
			description = "Spits two seeds from across the room. Slip through the gap between them!",
			picture = "rbxassetid://82242476998896",
			area = "MossyGlade",
		},
		BroodSlime = {
			name = "BROOD SLIME",
			description = "Slow and tough. When it falls, four Baby Slimes burst out!",
			picture = "rbxassetid://98349663930658",
			area = "MossyGlade",
		},
		BabySlime = {
			name = "BABY SLIME",
			description = "Small, quick and frail. Two arrows and it's gone!",
			picture = "rbxassetid://102882474449630",
			area = "MossyGlade",
		},
		-- Thornwood
		BrambleBoar = {
			name = "BRAMBLE BOAR",
			description = "Paws the ground, then charges across the room. Step out of its line!",
			picture = "rbxassetid://130240098364290",
			area = "Thornwood",
		},
		BurrThistle = {
			name = "BURR THISTLE",
			description = "Throws three burrs from anywhere in the room. Find the gaps!",
			picture = "rbxassetid://139645328652669",
			area = "Thornwood",
		},
		BrambleLurker = {
			name = "BRAMBLE LURKER",
			description = "Dives underground, then bursts up on a marked spot spraying thorns. Move!",
			picture = "rbxassetid://135528365602715",
			area = "Thornwood",
		},
		BrambleSow = {
			name = "BRAMBLE SOW",
			description = "Big and slow. When it falls, three Boarlets tumble out of its brambles!",
			picture = "rbxassetid://136498803142994",
			area = "Thornwood",
		},
		Boarlet = {
			name = "BOARLET",
			description = "A quick little piglet from a Bramble Sow. Don't let it nip you!",
			picture = "rbxassetid://98945040362699",
			area = "Thornwood",
		},
		--[[ Drowned Village: designed, not built yet; named as they will be,
		     and benched until each is modelled and in a roster (the area
		     opened 2026-11-07 with the Hollow Fisherman alone). ]]
		DrownedZombie = {
			name = "DROWNED ZOMBIE",
			description = "Slow but relentless. Rises again after it falls - unless it burns!",
			picture = "rbxassetid://94789496316745",
			area = "DrownedVillage",
			benched = true,
		},
		DitchEel = {
			name = "DITCH EEL",
			description = "Slides through the flooded ground, under walls, and surfaces to bite!",
			picture = "rbxassetid://103799368773499",
			area = "DrownedVillage",
			benched = true,
		},
		BellRinger = {
			name = "BELL RINGER",
			description = "Rings out a wide cone of sound. Step outside the wave!",
			picture = "rbxassetid://79054509181559",
			area = "DrownedVillage",
			benched = true,
		},
		HollowFisherman = {
			name = "HOLLOW FISHERMAN",
			description = "Casts its hook and reels you in. Dodge the line and keep your distance!",
			picture = "rbxassetid://121382456047030",
			area = "DrownedVillage",
		},
		-- Bogheart Caverns
		SporePuff = {
			name = "SPORE PUFF",
			description = "Rushes right at you and bursts into poison spores. Kill it from range!",
			picture = "rbxassetid://136475916127415",
			area = "BogheartCaverns",
		},
		Glowcap = {
			name = "GLOWCAP",
			description = "Never moves, but sprays spores in a turning spiral. Walk with the gaps!",
			picture = "rbxassetid://121343854223078",
			area = "BogheartCaverns",
		},
		Shellback = {
			name = "SHELLBACK",
			description = "Slow, heavy and tough. A walking wall - shoot past it at the turrets!",
			picture = "rbxassetid://127886942453836",
			area = "BogheartCaverns",
		},
	} :: { [string]: Enemy },
}

return table.freeze(NewEnemies)
