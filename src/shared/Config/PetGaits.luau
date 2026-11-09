--!strict
--[[
	How each pet moves as that creature (owner, 2026-11-08: "make sure the pet
	animations all feel unique to each other"). `Util/PetGait` plays this and
	`Fx/PetPreview` wears it, on top of the pet's own clips
	(`Config/ModelClips`): the clips move its legs and wings, this moves the
	whole animal and decides how it covers ground.

	`pace`, how it gets to its place behind the player:
	- `Chase`: closes the gap smoothly, `rate` per second.
	- `Creep`: one steady `speed` (studs a second), never hurrying, and never
	  more than `leash` studs behind.
	- `Steps`: stop and go. Each `period` seconds it travels up to `reach`
	  studs in the part of the beat from `from` to `to` (shares of the beat)
	  and stands still for the rest. A hop's window is its clip's time in the
	  air, so the feet leave the floor as the ground starts to pass. Left
	  behind, it steps further and up to twice as often.
	- `Surge`: pulses of speed, `beat` a second, drifting between them.

	`moving` and `idle` are layers added together, each one motion on one axis:
	`Y`, `Side` and `Ahead` in studs (a pet stands 2.4 tall), `Pitch` (nose up
	is positive), `Yaw` and `Roll` in degrees. `rate` is cycles a second, or a
	stud if `stride` is set, so the motion keeps time with the ground passing.
	`wave` is the motion's shape:
	- `Sine`: smooth to and fro. `Wander`: drifts, never repeating.
	- `Bounce`: up off the floor and back. `Saw`: a slow lean and a quick reset.
	- `Snap`: jumps between two held poses. `Pulse`: one quick flick, then rest.
	- `Hold`: stays there while the layer is on. `Turn`: whole turns.

	`float` lifts it off the floor for good; a `Y` `Hold` in `moving` lifts it
	only while it travels (the owl takes off) or sinks it (the mole tunnels).
	`turn` is how quickly it swings round, per second. `about = "Middle"` turns
	it about its centre rather than its feet (the ball that rolls).
	`idleClip` and `moveClip` name a clip other than the one it would pick, and
	`fidget` a clip of its own it plays now and then while standing.

	Two pets may share a number, never a shape: `tests/PetGaits.spec` asks
	that no two pets have the same pace kind, layers and waves, which is what
	stops a new pet being another bob with different numbers.
]]

export type Pace =
	{ kind: "Chase", rate: number }
	| { kind: "Creep", speed: number, leash: number }
	| { kind: "Steps", period: number, from: number, to: number, reach: number }
	| { kind: "Surge", rate: number, beat: number }

export type Layer = {
	axis: "Y" | "Side" | "Ahead" | "Pitch" | "Yaw" | "Roll",
	wave: "Sine" | "Wander" | "Bounce" | "Saw" | "Snap" | "Pulse" | "Hold" | "Turn",
	amount: number,
	rate: number?,
	phase: number?,
	stride: boolean?,
}

export type Gait = {
	pace: Pace,
	turn: number,
	float: number?,
	about: "Middle"?,
	moving: { Layer },
	idle: { Layer },
	idleClip: string?,
	moveClip: string?,
	fidget: string?,
}

local Gaits: { [string]: Gait } = {
	-- Mossy Glade
	Mosslet = { -- a soft blob: plops along, wobbling as it lands
		pace = { kind = "Steps", period = 1.5, from = 0.15, to = 0.6, reach = 3 },
		turn = 8,
		moveClip = "Hop",
		moving = { { axis = "Roll", wave = "Sine", amount = 6, rate = 0.67 } },
		idle = { { axis = "Roll", wave = "Sine", amount = 3, rate = 0.35 } },
	},
	Babacorn = { -- a top-heavy acorn teetering on two short legs
		pace = { kind = "Chase", rate = 5 },
		turn = 9,
		moveClip = "Waddle",
		fidget = "Hop",
		moving = {
			{ axis = "Roll", wave = "Sine", amount = 11, rate = 1.11 },
			{ axis = "Yaw", wave = "Sine", amount = 5, rate = 1.11, phase = 0.25 },
		},
		idle = { { axis = "Pitch", wave = "Pulse", amount = 5, rate = 0.3 } },
	},
	FernFrog = { -- long flat leaps with a sit between
		pace = { kind = "Steps", period = 1.3, from = 0.13, to = 0.52, reach = 4.5 },
		turn = 12,
		moveClip = "Hop",
		moving = { { axis = "Pitch", wave = "Bounce", amount = 6, rate = 0.77 } },
		idle = { { axis = "Y", wave = "Pulse", amount = 0.06, rate = 0.45 } },
	},
	ToadstoolTot = { -- a toddler under a heavy cap, always nearly falling over
		pace = { kind = "Chase", rate = 5 },
		turn = 7,
		moveClip = "Walk",
		fidget = "Spore Puff",
		moving = {
			{ axis = "Yaw", wave = "Sine", amount = 8, rate = 1.9 },
			{ axis = "Pitch", wave = "Wander", amount = 7, rate = 0.8 },
		},
		idle = { { axis = "Roll", wave = "Wander", amount = 3, rate = 0.4 } },
	},
	MossbackSnail = { -- glides at one slow speed, no bob at all; the foot ripples
		pace = { kind = "Creep", speed = 3.5, leash = 12 },
		turn = 1.5,
		moveClip = "Crawl",
		fidget = "Peek",
		moving = { { axis = "Ahead", wave = "Saw", amount = 0.12, rate = 0.36 } },
		idle = {},
	},
	FireflyBun = { -- hangs in the air, then darts, like a firefly
		pace = { kind = "Steps", period = 0.7, from = 0, to = 0.4, reach = 2.6 },
		turn = 16,
		float = 1.8,
		idleClip = "Hover",
		moving = {
			{ axis = "Y", wave = "Snap", amount = 0.3, rate = 1.4 },
			{ axis = "Yaw", wave = "Snap", amount = 12, rate = 1.4 },
		},
		idle = {
			{ axis = "Y", wave = "Sine", amount = 0.12, rate = 0.5 },
			{ axis = "Roll", wave = "Snap", amount = 4, rate = 0.7 },
		},
	},
	Stumpy = { -- a stump that has to throw its weight onto each foot
		pace = { kind = "Steps", period = 0.8, from = 0, to = 0.45, reach = 1.8 },
		turn = 4,
		moveClip = "Walk",
		fidget = "Stomp",
		moving = {
			{ axis = "Roll", wave = "Snap", amount = 7, rate = 0.63 },
			{ axis = "Y", wave = "Bounce", amount = 0.12, rate = 1.25 },
		},
		idle = { { axis = "Yaw", wave = "Sine", amount = 3, rate = 0.15 } },
	},
	GladeFox = { -- quick and sure, nose dipping, cutting a light weave
		pace = { kind = "Chase", rate = 9 },
		turn = 18,
		fidget = "Pounce",
		moving = {
			{ axis = "Pitch", wave = "Bounce", amount = -5, rate = 2.4 },
			{ axis = "Side", wave = "Wander", amount = 0.2, rate = 0.7 },
		},
		idle = { { axis = "Yaw", wave = "Wander", amount = 6, rate = 0.2 } },
	},
	Hootmoss = { -- takes off to travel, lands to stand, and its head snaps round
		pace = { kind = "Chase", rate = 5 },
		turn = 6,
		fidget = "Wings Out",
		moving = {
			{ axis = "Y", wave = "Hold", amount = 2.2 },
			{ axis = "Y", wave = "Sine", amount = 0.25, rate = 0.8 },
			{ axis = "Roll", wave = "Wander", amount = 8, rate = 0.3 },
		},
		idle = { { axis = "Yaw", wave = "Snap", amount = 30, rate = 0.12 } },
	},
	SlimePrince = { -- a stately plop, and a royal sway while standing
		pace = { kind = "Steps", period = 1.4, from = 0.21, to = 0.6, reach = 3.5 },
		turn = 5,
		moveClip = "Hop",
		fidget = "RoyalWave",
		moving = { { axis = "Pitch", wave = "Sine", amount = 4, rate = 0.71 } },
		idle = { { axis = "Roll", wave = "Sine", amount = 2, rate = 0.2 } },
	},
	EmberWilfPet = { -- can't run straight: zigzags at full tilt
		pace = { kind = "Chase", rate = 9 },
		turn = 14,
		fidget = "Zoomies",
		moving = {
			{ axis = "Side", wave = "Sine", amount = 1, rate = 1.2 },
			{ axis = "Yaw", wave = "Sine", amount = 18, rate = 1.2, phase = 0.25 },
			{ axis = "Y", wave = "Bounce", amount = 0.15, rate = 2.4 },
		},
		idle = { { axis = "Roll", wave = "Pulse", amount = 6, rate = 0.4 } },
	},
	Glimmerhorn = { -- a prance on air, each step high and slow
		pace = { kind = "Chase", rate = 7 },
		turn = 8,
		float = 0.8,
		moving = {
			{ axis = "Y", wave = "Bounce", amount = 0.5, rate = 1.6 },
			{ axis = "Pitch", wave = "Sine", amount = 6, rate = 1.6, phase = 0.25 },
		},
		idle = {
			{ axis = "Y", wave = "Sine", amount = 0.2, rate = 0.25 },
			{ axis = "Roll", wave = "Sine", amount = 3, rate = 0.15 },
		},
	},
	-- Thornwood
	BarkHoglet = { -- a piglet that snuffles the ground as it trots
		pace = { kind = "Chase", rate = 6.5 },
		turn = 10,
		fidget = "Snuffle",
		moving = {
			{ axis = "Pitch", wave = "Snap", amount = 6, rate = 3.2 },
			{ axis = "Yaw", wave = "Wander", amount = 6, rate = 0.6 },
		},
		idle = { { axis = "Yaw", wave = "Snap", amount = 10, rate = 0.25 } },
	},
	Burrball = { -- rolled up in its spines, it rolls
		pace = { kind = "Chase", rate = 6 },
		turn = 10,
		about = "Middle",
		moveClip = "Bristle",
		moving = { { axis = "Pitch", wave = "Turn", amount = -360, rate = 0.13, stride = true } },
		idle = { { axis = "Y", wave = "Bounce", amount = 0.05, rate = 0.7 } },
	},
	Budbulb = { -- a bud on a stem: the head circles as it goes
		pace = { kind = "Chase", rate = 5 },
		turn = 7,
		moveClip = "Waddle",
		fidget = "Bud Bloom",
		moving = {
			{ axis = "Pitch", wave = "Sine", amount = 5, rate = 0.625 },
			{ axis = "Roll", wave = "Sine", amount = 5, rate = 0.625, phase = 0.25 },
		},
		idle = { { axis = "Roll", wave = "Wander", amount = 4, rate = 0.3 } },
	},
	BerryMouse = { -- scurries, freezes, sits up to look round
		pace = { kind = "Steps", period = 0.55, from = 0, to = 0.5, reach = 2.4 },
		turn = 20,
		fidget = "Berry Offer",
		moving = { { axis = "Yaw", wave = "Snap", amount = 14, rate = 1.8 } },
		idle = {
			{ axis = "Pitch", wave = "Hold", amount = 7 },
			{ axis = "Yaw", wave = "Snap", amount = 10, rate = 0.33 },
		},
	},
	ThistleMole = { -- tunnels: sinks to its back when it travels and comes up to stand
		pace = { kind = "Chase", rate = 4 },
		turn = 5,
		fidget = "Burrow",
		moving = {
			{ axis = "Y", wave = "Hold", amount = -1.1 },
			{ axis = "Y", wave = "Sine", amount = 0.08, rate = 1.5 },
			{ axis = "Yaw", wave = "Wander", amount = 5, rate = 0.5 },
		},
		idle = { { axis = "Pitch", wave = "Sine", amount = 2, rate = 0.25 } },
	},
	BriarBeetle = { -- rigid, dead level, a tiny shimmy; pivots on the spot
		pace = { kind = "Chase", rate = 6 },
		turn = 30,
		fidget = "Plate Brace",
		moving = { { axis = "Side", wave = "Snap", amount = 0.06, rate = 6 } },
		idle = { { axis = "Yaw", wave = "Snap", amount = 6, rate = 0.2 } },
	},
	BerryBat = { -- high up and never still, banking on every flutter
		pace = { kind = "Chase", rate = 7 },
		turn = 14,
		float = 2.6,
		idleClip = "Hover",
		fidget = "Berry Swing",
		moving = {
			{ axis = "Y", wave = "Wander", amount = 0.6, rate = 0.9 },
			{ axis = "Side", wave = "Wander", amount = 0.5, rate = 0.7 },
			{ axis = "Roll", wave = "Wander", amount = 14, rate = 0.7 },
		},
		idle = {
			{ axis = "Y", wave = "Wander", amount = 0.25, rate = 0.6 },
			{ axis = "Yaw", wave = "Wander", amount = 10, rate = 0.4 },
		},
	},
	BrambleBear = { -- lumbers, the whole weight rolling from shoulder to shoulder
		pace = { kind = "Chase", rate = 3.2 },
		turn = 4,
		fidget = "Fist Thump",
		moving = {
			{ axis = "Roll", wave = "Sine", amount = 9, rate = 1 },
			{ axis = "Y", wave = "Bounce", amount = 0.12, rate = 2 },
			{ axis = "Side", wave = "Sine", amount = 0.15, rate = 1 },
		},
		idle = { { axis = "Pitch", wave = "Sine", amount = 1.5, rate = 0.2 } },
	},
	BriarLynx = { -- stalks: crouched low, nose down, moving in soft pushes
		pace = { kind = "Surge", rate = 6, beat = 0.8 },
		turn = 9,
		fidget = "Pounce Wiggle",
		moving = {
			{ axis = "Y", wave = "Hold", amount = -0.25 },
			{ axis = "Pitch", wave = "Hold", amount = -4 },
			{ axis = "Yaw", wave = "Sine", amount = 3, rate = 0.4 },
		},
		idle = { { axis = "Yaw", wave = "Wander", amount = 4, rate = 0.15 } },
	},
	BrambleWilf = { -- a rocking-horse bound, chest up and over
		pace = { kind = "Chase", rate = 8 },
		turn = 12,
		fidget = "Pounce Play",
		moving = {
			{ axis = "Pitch", wave = "Saw", amount = 5, rate = 1.4 },
			{ axis = "Y", wave = "Bounce", amount = 0.25, rate = 1.4 },
		},
		idle = { { axis = "Pitch", wave = "Pulse", amount = 5, rate = 0.2 } },
	},
	ThornPrincess = { -- spider legs: the body rides level on a fast tremble
		pace = { kind = "Chase", rate = 8 },
		turn = 30,
		fidget = "Princess Wave",
		moving = {
			{ axis = "Y", wave = "Sine", amount = 0.05, rate = 5 },
			{ axis = "Yaw", wave = "Snap", amount = 7, rate = 2 },
		},
		idle = { { axis = "Pitch", wave = "Sine", amount = 2.5, rate = 0.3 } },
	},
	Thornwake = { -- coils in a slow circle round its place
		pace = { kind = "Chase", rate = 4 },
		turn = 6,
		float = 1,
		idleClip = "Hover",
		fidget = "Tail Spin",
		moving = {
			{ axis = "Side", wave = "Sine", amount = 1.4, rate = 0.3 },
			{ axis = "Ahead", wave = "Sine", amount = 1.4, rate = 0.3, phase = 0.25 },
			{ axis = "Yaw", wave = "Sine", amount = 15, rate = 0.3 },
		},
		idle = {
			{ axis = "Side", wave = "Sine", amount = 0.4, rate = 0.15 },
			{ axis = "Ahead", wave = "Sine", amount = 0.4, rate = 0.15, phase = 0.25 },
		},
	},
	-- Drowned Village
	SlateTurtle = { -- plods at its own speed, rolling on its shell
		pace = { kind = "Creep", speed = 6, leash = 13 },
		turn = 2.5,
		moving = { { axis = "Roll", wave = "Sine", amount = 6, rate = 0.55 } },
		idle = { { axis = "Pitch", wave = "Pulse", amount = 3, rate = 0.12 } },
	},
	BuoyPuffer = { -- a cork on a swell, with no hurry in it
		pace = { kind = "Chase", rate = 2.8 },
		turn = 3,
		float = 1,
		moving = {
			{ axis = "Y", wave = "Sine", amount = 0.35, rate = 0.35 },
			{ axis = "Roll", wave = "Sine", amount = 8, rate = 0.35 },
		},
		idle = {
			{ axis = "Y", wave = "Sine", amount = 0.2, rate = 0.3 },
			{ axis = "Pitch", wave = "Sine", amount = 3, rate = 0.3, phase = 0.25 },
		},
	},
	Inkpot = { -- jets: squeezes, shoots forward, coasts
		pace = { kind = "Surge", rate = 9, beat = 0.9 },
		turn = 7,
		moving = {
			{ axis = "Pitch", wave = "Saw", amount = 6, rate = 0.9 },
			{ axis = "Y", wave = "Pulse", amount = 0.25, rate = 0.9 },
		},
		idle = { { axis = "Yaw", wave = "Snap", amount = 8, rate = 0.18 } },
	},
	TideWilf = { -- surfs: rises and dips over long waves as the ground passes
		pace = { kind = "Chase", rate = 7 },
		turn = 10,
		float = 0.2,
		moving = {
			{ axis = "Y", wave = "Sine", amount = 0.3, rate = 0.14, stride = true },
			{ axis = "Pitch", wave = "Sine", amount = 8, rate = 0.14, phase = 0.25, stride = true },
		},
		idle = { { axis = "Y", wave = "Sine", amount = 0.06, rate = 0.2 } },
	},
	AbyssJelly = { -- each squeeze of the bell pushes it on; it drifts between
		pace = { kind = "Surge", rate = 6, beat = 0.71 },
		turn = 2,
		float = 1.6,
		moving = {
			{ axis = "Yaw", wave = "Wander", amount = 8, rate = 0.2 },
			{ axis = "Roll", wave = "Wander", amount = 5, rate = 0.25 },
		},
		idle = { { axis = "Yaw", wave = "Wander", amount = 5, rate = 0.12 } },
	},
	-- Bogheart Caverns
	CaveCricket = { -- long springs, one straight after another
		pace = { kind = "Steps", period = 0.6, from = 0.1, to = 0.88, reach = 5 },
		turn = 24,
		moving = { { axis = "Roll", wave = "Wander", amount = 4, rate = 1.5 } },
		idle = { { axis = "Yaw", wave = "Snap", amount = 14, rate = 0.4 } },
	},
	LichenGecko = { -- darts, freezes, darts; the head flicks when it stops
		pace = { kind = "Steps", period = 0.6, from = 0, to = 0.35, reach = 3 },
		turn = 26,
		moving = { { axis = "Yaw", wave = "Sine", amount = 7, rate = 3.3 } },
		idle = { { axis = "Yaw", wave = "Snap", amount = 18, rate = 0.3 } },
	},
	BogBeaver = { -- low and heavy, swinging from the hips
		pace = { kind = "Chase", rate = 4.5 },
		turn = 5,
		moving = {
			{ axis = "Yaw", wave = "Sine", amount = 6, rate = 0.83 },
			{ axis = "Y", wave = "Hold", amount = -0.1 },
		},
		idle = { { axis = "Pitch", wave = "Pulse", amount = 3, rate = 0.25 } },
	},
	Lanternfin = { -- swims through the air, tail-beat weaving it side to side
		pace = { kind = "Chase", rate = 4 },
		turn = 5,
		moving = {
			{ axis = "Side", wave = "Sine", amount = 0.3, rate = 0.55 },
			{ axis = "Yaw", wave = "Sine", amount = 10, rate = 0.55, phase = 0.25 },
		},
		idle = { { axis = "Y", wave = "Sine", amount = 0.1, rate = 0.3 } },
	},
	Olm = { -- a long pale slither at one steady speed, in slow S-curves
		pace = { kind = "Creep", speed = 7, leash = 14 },
		turn = 4,
		moving = {
			{ axis = "Side", wave = "Sine", amount = 0.45, rate = 0.62 },
			{ axis = "Yaw", wave = "Sine", amount = 14, rate = 0.62, phase = 0.25 },
		},
		idle = { { axis = "Yaw", wave = "Wander", amount = 6, rate = 0.1 } },
	},
	GlowcapWilf = { -- an ambler that wanders off its line, about to sneeze
		pace = { kind = "Chase", rate = 5 },
		turn = 8,
		moving = {
			{ axis = "Yaw", wave = "Wander", amount = 9, rate = 0.45 },
			{ axis = "Y", wave = "Sine", amount = 0.1, rate = 1 },
		},
		idle = { { axis = "Pitch", wave = "Pulse", amount = 5, rate = 0.33 } },
	},
	Gulpling = { -- a baby toad's short quick hops
		pace = { kind = "Steps", period = 0.55, from = 0.1, to = 0.8, reach = 1.8 },
		turn = 12,
		moving = { { axis = "Roll", wave = "Sine", amount = 5, rate = 0.9 } },
		idle = { { axis = "Y", wave = "Pulse", amount = 0.05, rate = 0.5 } },
	},
	PrismLeviathan = { -- a grand serpent's wave, rolling along it as it goes
		pace = { kind = "Chase", rate = 3.5 },
		turn = 3,
		moving = {
			{ axis = "Y", wave = "Sine", amount = 0.4, rate = 0.07, stride = true },
			{
				axis = "Side",
				wave = "Sine",
				amount = 0.9,
				rate = 0.07,
				phase = 0.25,
				stride = true,
			},
			{ axis = "Yaw", wave = "Sine", amount = 14, rate = 0.07, phase = 0.25, stride = true },
		},
		idle = {
			{ axis = "Roll", wave = "Sine", amount = 3, rate = 0.2 },
			{ axis = "Y", wave = "Sine", amount = 0.15, rate = 0.25 },
		},
	},
}

return table.freeze(Gaits)
