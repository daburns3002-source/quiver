--!strict
--[[
	Where a tip or a tutorial prompt stands during a run (`Util/ArenaMargin`;
	owner, 2026-11-19: "the tutorial tips need to be on the outer arena so
	they do not block the arena"). The arena is projected the way the run
	camera shows it (`Util/CameraFit`, `Balance.Camera`) from one end of the
	room to the other, on a computer's screens and on upright phones, and
	the HUD's pieces are the run HUD's own (`Util/RunHudRules.pieces`).
	Studio cannot be a phone over MCP, so this is where a phone is held.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaMargin = require(ReplicatedStorage.Shared.Util.ArenaMargin)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CameraFit = require(ReplicatedStorage.Shared.Util.CameraFit)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local TestRunner = require(script.Parent.TestRunner)
local TipRules = require(ReplicatedStorage.Shared.Util.TipRules)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

type Point = ArenaMargin.Point
type Box = ArenaMargin.Box

local TOP_BAR = 58

--[[ The run camera on a screen `w` x `h`, its focus `z` down the room: a
     world point on the screen (`TopDownCamera`'s offset and lens). ]]
local function offsetFor(w: number, h: number, phone: boolean, fitWidth: number?): Vector3
	local camera = Balance.Camera
	return CameraFit.offset(Vector2.new(w, h), {
		pitch = camera.pitch,
		fieldOfView = camera.fieldOfView,
		fitWidth = fitWidth or (if phone then camera.phone.fitWidth else camera.fitWidth),
		minVisibleDepth = if phone then camera.phone.minVisibleDepth else camera.minVisibleDepth,
	})
end

local function projector(
	w: number,
	h: number,
	phone: boolean,
	z: number,
	fitWidth: number?
): (number, number, number) -> Point
	local camera = Balance.Camera
	local offset = offsetFor(w, h, phone, fitWidth)
	local at = Vector3.new(0, 0, z) + offset
	local look = CFrame.lookAt(at, Vector3.new(0, 0, z))
	local tanV = math.tan(math.rad(camera.fieldOfView) / 2)
	local tanH = tanV * w / h
	return function(x: number, y: number, wz: number): Point
		local v = look:PointToObjectSpace(Vector3.new(x, y, wz))
		local depth = -v.Z
		return {
			x = w / 2 * (1 + v.X / (depth * tanH)),
			y = h / 2 * (1 - v.Y / (depth * tanV)),
		}
	end
end

--[[ Where an upright phone's camera looks with the player at `z`: the view
     is longer than the room, so it centres on it and follows no further
     than `longViewFollow` either way (`TopDownCamera`). ]]
local function phoneFocus(w: number, h: number, z: number, fitWidth: number?): number
	local camera = Balance.Camera
	local offset = offsetFor(w, h, true, fitWidth)
	local pitch = math.atan2(offset.Y, offset.Z)
	local half = math.rad(camera.fieldOfView) / 2
	local near = offset.Z - offset.Y / math.tan(pitch + half)
	local far = offset.Z - offset.Y / math.tan(pitch - half)
	local length = Balance.Arena.size.Z / 2
	local lowest = -(length + camera.gateMargin) - far
	local highest = length + camera.wallMargin - near
	local reach = camera.longViewFollow
	return (lowest + highest) / 2 + math.clamp(z, -reach, reach)
end

--[[ The run's screen with the camera's focus at `z` and the player at
     `playerZ`. ]]
local function scene(
	w: number,
	h: number,
	phone: boolean,
	z: number,
	playerZ: number,
	fitWidth: number?
)
	local project = projector(w, h, phone, z, fitWidth)
	local arena = Balance.Arena
	local quad = ArenaMargin.quad(
		arena.size.X / 2 + arena.wallThickness,
		arena.size.Z / 2 + arena.wallThickness,
		function(x: number, wz: number): Point
			return project(x, 0, wz)
		end
	)
	local screen: ArenaMargin.Screen = {
		w = w,
		h = h,
		top = TOP_BAR + ArenaMargin.GUTTER,
		hud = RunHudRules.pieces(Vector2.new(w, h), phone, TOP_BAR),
		player = project(0, 2.5, playerZ),
		gate = project(0, 0, -arena.size.Z / 2),
	}
	return screen, quad
end

--[[ A room prompt's height at a width (`UI/TutorialPrompts`), from its
     words at about 0.62 of a letter's size each: rules, not pixels. ]]
local function prompt(words: string, w: number, h: number): ArenaMargin.Want
	local short = math.min(w, h)
	return {
		sideMin = 160,
		sideMax = 460,
		bandMax = 520,
		height = function(width: number, form: ArenaMargin.Form): number
			local body = if form == "Right" or form == "Left"
				then math.floor(math.clamp(math.min(short * 0.042, width / 13), 16, 36))
				else math.floor(math.clamp(short * 0.046, 16, 20))
			local pad = math.floor(body * 0.6)
			local perLine =
				math.max(1, math.floor((width - 8 - pad * 2) / (body * 0.62 / 1.21 * 1.21)))
			local lines = math.ceil(#words / perLine)
			return pad * 3 + math.floor(body * 1.9) + lines * body + 8
		end,
	}
end

--[[ First-time tips' cards (`UI/FirstTips`, `TipRules.layout`). ]]
local function card(): ArenaMargin.Want
	local layout = TipRules.layout
	return {
		sideMin = layout.sideMin,
		sideMax = layout.sideMax,
		bandMax = layout.wideWidth,
		height = function(_width: number, form: ArenaMargin.Form): number
			return if form == "Right" or form == "Left"
				then layout.sideHeight
				else layout.wideHeight
		end,
	}
end

local function apart(a: Box, b: Box): boolean
	return a.x + a.w <= b.x + 1e-6
		or b.x + b.w <= a.x + 1e-6
		or a.y + a.h <= b.y + 1e-6
		or b.y + b.h <= a.y + 1e-6
end

local function onScreen(box: Box, screen: ArenaMargin.Screen): boolean
	return box.x >= 0
		and box.y >= screen.top - 1e-6
		and box.x + box.w <= screen.w
		and box.y + box.h <= screen.h
end

local function offHud(box: Box, screen: ArenaMargin.Screen): boolean
	for _, piece in screen.hud do
		if not apart(box, piece) then
			return false
		end
	end
	return true
end

local function on(point: Point?, box: Box): boolean
	return point ~= nil
		and point.x >= box.x
		and point.x <= box.x + box.w
		and point.y >= box.y
		and point.y <= box.y + box.h
end

local COMPUTERS = { { 1920, 1080 }, { 2091, 1113 }, { 1366, 768 }, { 1280, 720 }, { 1024, 768 } }
local PHONES = { { 390, 844 }, { 360, 780 }, { 428, 926 } }

return function(t: TestRunner.Helper)
	t.test(
		"on a computer every prompt and tip stands beside the arena, off the floor and the HUD",
		function()
			local wants: { [string]: (number, number) -> ArenaMargin.Want } = {
				card = function(_w, _h)
					return card()
				end,
			}
			for id, words in Tutorial.prompts do
				local said = words.keyboard
				wants[id] = function(w, h)
					return prompt(said, w, h)
				end
			end
			for _, size in COMPUTERS do
				local w, h = size[1], size[2]
				for name, want in wants do
					local first: Box? = nil
					for z = -16, 16, 4 do
						local screen, quad = scene(w, h, false, z, z)
						local spot = ArenaMargin.place(screen, quad, want(w, h), nil)
						local where = `{w} x {h}, {name}, focus {z}`
						t.isTrue(
							spot.form == "Right" or spot.form == "Left",
							`{where}: {spot.form}, not beside`
						)
						t.equal(
							ArenaMargin.covers(spot.box, quad, true),
							0,
							`{where}: on the floor`
						)
						t.isTrue(offHud(spot.box, screen), `{where}: on the HUD`)
						t.isTrue(onScreen(spot.box, screen), `{where}: off the screen`)
						-- the side walls do not move on the screen, so neither does the card
						local was = first or spot.box
						first = was
						t.isTrue(
							was.x == spot.box.x and was.y == spot.box.y,
							`{where}: moved with the camera`
						)
					end
				end
			end
		end
	)

	t.test("on a computer a prompt takes the right margin, away from MENU", function()
		local screen, quad = scene(1920, 1080, false, 0, 0)
		local spot = ArenaMargin.place(
			screen,
			quad,
			prompt(Tutorial.prompts.shoot.keyboard, 1920, 1080),
			nil
		)
		t.equal(spot.form, "Right")
		t.isTrue(spot.box.x > 1920 / 2, "on the left")
	end)

	t.test("with the right margin taken it uses the left one", function()
		local screen, quad = scene(1920, 1080, false, 0, 0)
		table.insert(screen.hud, { x = 1920 * 0.7, y = 0, w = 1920 * 0.3, h = 1080 })
		local spot =
			ArenaMargin.place(screen, quad, prompt(Tutorial.prompts.move.keyboard, 1920, 1080), nil)
		t.equal(spot.form, "Left")
		t.isTrue(offHud(spot.box, screen), "on MENU or the HUD")
		t.equal(ArenaMargin.covers(spot.box, quad, true), 0, "on the floor")
	end)

	t.test(
		"a card round the arena on an upright phone stays on the screen, off the HUD and the player",
		function()
			for _, size in PHONES do
				local w, h = size[1], size[2]
				for id, words in Tutorial.prompts do
					local last: ArenaMargin.Form? = nil
					-- the player walks the room's length, the camera following
					for playerZ = 26, -26, -2 do
						local screen, quad = scene(w, h, true, phoneFocus(w, h, playerZ), playerZ)
						local spot =
							ArenaMargin.place(screen, quad, prompt(words.touch, w, h), last)
						last = spot.form
						local where = `{w} x {h}, {id}, player at {playerZ}`
						t.isTrue(
							spot.form == "Above" or spot.form == "Below",
							`{where}: {spot.form}`
						)
						t.isTrue(onScreen(spot.box, screen), `{where}: off the screen`)
						t.isTrue(offHud(spot.box, screen), `{where}: on the HUD`)
						t.isFalse(on(screen.player, spot.box), `{where}: on the player`)
					end
				end
			end
		end
	)

	t.test(
		"where the forest above or below holds a card whole it covers none of the floor",
		function()
			local screen: ArenaMargin.Screen = {
				w = 390,
				h = 844,
				top = 74,
				hud = RunHudRules.pieces(Vector2.new(390, 844), true, TOP_BAR),
			}
			-- the room seen from far off: forest above it
			local quad: ArenaMargin.Quad = {
				farLeft = { x = 20, y = 420 },
				farRight = { x = 370, y = 420 },
				nearLeft = { x = -10, y = 560 },
				nearRight = { x = 400, y = 560 },
			}
			local spot = ArenaMargin.place(screen, quad, card(), nil)
			t.equal(spot.form, "Above")
			t.equal(spot.covers, 0)
			t.isTrue(spot.box.y + spot.box.h <= 420, "on the far wall")
			t.isTrue(offHud(spot.box, screen), "on the HUD")
		end
	)

	t.test("with both ends alike a card above or below keeps the end it had", function()
		local screen, quad = scene(390, 844, true, phoneFocus(390, 844, 0), 0)
		screen.player = nil
		screen.gate = nil
		local want = prompt(Tutorial.prompts.shoot.touch, 390, 844)
		local above = ArenaMargin.place(screen, quad, want, "Above")
		local below = ArenaMargin.place(screen, quad, want, "Below")
		if math.abs(above.covers - below.covers) < above.box.w * above.box.h * 0.1 then
			t.equal(above.form, "Above")
			t.equal(below.form, "Below")
		end
		-- and the player under one end sends it to the other
		local player = { x = 195, y = above.box.y + above.box.h / 2 }
		screen.player = player
		t.equal(ArenaMargin.place(screen, quad, want, "Above").form, "Below")
	end)

	t.test("the focus that puts a floor point on a screen row puts it there", function()
		for _, size in PHONES do
			local w, h = size[1], size[2]
			local offset = offsetFor(w, h, true, nil)
			for _, row in { 120, h / 2, h - 150 } do
				for _, z in { -31, 0, 31 } do
					local focus =
						CameraFit.focusPutting(z, row, h, offset, Balance.Camera.fieldOfView)
					local seen = projector(w, h, true, focus)(0, 0, z)
					t.near(seen.y, row, 0.01, `{w} x {h}: z {z} on row {row}`)
				end
			end
		end
	end)

	t.test(
		"on an upright phone the camera pulls back and a prompt stands past the end wall, off the floor",
		function()
			--[[ As `UI/TutorialPrompts` and `TopDownCamera.keepClear` do it: the
		     prompt docked against the HUD at the end the player is nearer
		     (moving end `promptSwitch` past the middle), the camera at
		     `promptFitWidth`, following as it does and then moved by
		     `CameraFit.clearFocus`. Steady state, the easing done. ]]
			local pulled = Balance.Camera.phone.promptFitWidth
			local wall = Balance.Arena.size.Z / 2 + Balance.Arena.wallThickness
			local g = ArenaMargin.GUTTER
			for _, size in PHONES do
				local w, h = size[1], size[2]
				local offset = offsetFor(w, h, true, pulled)
				for id, words in Tutorial.prompts do
					local want = prompt(words.touch, w, h)
					local form: ArenaMargin.Form = "Below"
					local room = Balance.Camera.phone.promptPlayerRoom
					for playerZ = 27, -27, -1 do
						if form == "Below" and playerZ < -Balance.Camera.phone.promptSwitch then
							form = "Above"
						end
						local base = scene(w, h, true, 0, playerZ, pulled)
						local box = ArenaMargin.docked(base, want, form)
						local hudTop, hudBottom = base.top, h
						for _, piece in base.hud do
							if piece.y + piece.h / 2 < h / 2 then
								hudTop = math.max(hudTop, piece.y + piece.h)
							else
								hudBottom = math.min(hudBottom, piece.y)
							end
						end
						local clear: CameraFit.Clear = if form == "Above"
							then {
								side = "Above",
								wallRow = box.y + box.h + g,
								playerTop = box.y + box.h + room,
								playerBottom = hudBottom - room,
							}
							else {
								side = "Below",
								wallRow = box.y - g,
								playerTop = hudTop + room,
								playerBottom = box.y - room,
							}
						local focus = CameraFit.clearFocus(
							phoneFocus(w, h, playerZ, pulled),
							clear,
							if form == "Below" then wall else -wall,
							playerZ,
							h,
							offset,
							Balance.Camera.fieldOfView
						)
						local screen, quad = scene(w, h, true, focus, playerZ, pulled)
						local where = `{w} x {h}, {id}, player at {playerZ}, {form}`
						t.equal(ArenaMargin.covers(box, quad), 0, `{where}: on the floor`)
						t.isTrue(offHud(box, screen), `{where}: on the HUD`)
						t.isTrue(onScreen(box, screen), `{where}: off the screen`)
						-- where the player stands, as the camera bounds them
						local player = projector(w, h, true, focus, pulled)(0, 0, playerZ)
						t.isTrue(
							player.y >= clear.playerTop - 1 and player.y <= clear.playerBottom + 1,
							`{where}: player at {player.y}`
						)
					end
				end
			end
		end
	)

	t.test(
		"the floor covered is measured between the end walls, or the side walls alone",
		function()
			local quad: ArenaMargin.Quad = {
				farLeft = { x = 400, y = 100 },
				farRight = { x = 600, y = 100 },
				nearLeft = { x = 300, y = 500 },
				nearRight = { x = 700, y = 500 },
			}
			t.equal(
				ArenaMargin.covers({ x = 720, y = 120, w = 100, h = 300 }, quad),
				0,
				"beside it"
			)
			t.equal(
				ArenaMargin.covers({ x = 450, y = 0, w = 100, h = 90 }, quad),
				0,
				"past the far wall"
			)
			t.isTrue(
				ArenaMargin.covers({ x = 450, y = 0, w = 100, h = 90 }, quad, true) > 0,
				"the side walls run on"
			)
			t.near(
				ArenaMargin.covers({ x = 450, y = 200, w = 100, h = 100 }, quad),
				100 * 100,
				1e-6
			)
		end
	)
end
