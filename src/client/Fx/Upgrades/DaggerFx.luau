--!strict
--[[
	What the themed sets' seven daggers' own effects look like (owner,
	2026-11-18; the server's side is `Combat/AssassinUpgrades`), each in its
	set's two glow colours (`assets/models/weapons/blocky/themed_sets/sets.py`)
	and built from voxel cubes like every card's (`Fx/Upgrades/Voxel`). The
	client only draws.

	- **Wishing Star** (Twinkle, `WishingStar`): a gold star falls on the
	  enemy with a sparkle tail and bursts in a ring of gold and pink.
	- **Spur Rowel** (Spur, `SpurRowel`): a turquoise-and-gold spiked wheel
	  rolls from enemy to enemy, as the server's hops land, a puff of dust
	  at each, then bounces up and is gone.
	- **Splash Wave** (Squirt, `SplashWave`): a ring of water and droplets
	  thrown out; an enemy with `SoakedUntil` (server time) ahead of now
	  drips.
	- **Combo Counter** (Token, `ComboCount` on the player): red arcade
	  pixel digits over the Assassin's head, "x" and the count, popping at
	  each strike and gold when full; a hit taken shatters them.
	- **Comet Crash** (Comet, `CometCrash`): a violet comet glints high over
	  the enemy, then crashes down on it with a pink tail.
	- **Bell Chime** (Bellchime, `BellChime`): a gold bell swings over the
	  Assassin, a ring of light runs out, and a ring of gold turns round
	  the feet of each enemy held.
	- **Lava Burst** (Embershard, `LavaBurst`): lava bursts out of the floor
	  one after another along the line, as the server's lane reaches them.

	Sounds: silent hooks (`Config/Sounds` `fx_wishing_star` and the rest)
	until they are picked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local Voxel = require(script.Parent.Voxel)

local DaggerFx = {}

--[[ Each set's two glow colours, as `sets.py` has them. ]]
local STAR_GOLD = Color3.fromRGB(255, 214, 92)
local STAR_PINK = Color3.fromRGB(255, 140, 200)
local SPUR_TEAL = Color3.fromRGB(64, 224, 208)
local SPUR_BRASS = Color3.fromRGB(240, 190, 80)
local DUST = Color3.fromRGB(196, 160, 112)
local WATER = Color3.fromRGB(80, 220, 255)
local FOAM = Color3.fromRGB(226, 248, 255)
local ARCADE_RED = Color3.fromRGB(255, 70, 70)
local ARCADE_BLUE = Color3.fromRGB(70, 130, 255)
local ARCADE_GOLD = Color3.fromRGB(255, 220, 60)
local COMET_VIOLET = Color3.fromRGB(180, 110, 255)
local COMET_PINK = Color3.fromRGB(255, 140, 230)
local COMET_WHITE = Color3.fromRGB(246, 238, 255)
local BELL_GOLD = Color3.fromRGB(255, 190, 90)
local BELL_PINK = Color3.fromRGB(255, 150, 190)
local BELL_CORD = Color3.fromRGB(176, 36, 48)
local LAVA = Color3.fromRGB(255, 120, 30)
local LAVA_HOT = Color3.fromRGB(255, 200, 60)
local ROCK = Color3.fromRGB(44, 36, 34)

--[[ Studs above the floor an enemy's middle is drawn at, as the Assassin's
     own effects draw it. ]]
local HEIGHT = 2.2

local function flat(v: Vector3, y: number?): Vector3
	return Vector3.new(v.X, y or 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

--[[ Where `model` stands now, or `fallback` once it is gone. ]]
local function standing(model: Instance?, fallback: Vector3): Vector3
	if model and model:IsA("Model") and model.Parent then
		return flat(model:GetPivot().Position)
	end
	return fallback
end

--[[ A piece made of cubes posed as one: each cube with its offset. ]]
type Piece = { parts: { { part: Part, offset: CFrame } } }

local function piece(): Piece
	return { parts = {} }
end

local function add(
	into: Piece,
	size: Vector3 | number,
	colour: Color3,
	offset: CFrame,
	neon: boolean?
)
	table.insert(into.parts, { part = Voxel.cube(size, colour, neon), offset = offset })
end

local function pose(it: Piece, frame: CFrame, transparency: number?)
	for _, bit in it.parts do
		bit.part.CFrame = frame * bit.offset
		if transparency then
			bit.part.Transparency = transparency
		end
	end
end

local function destroy(it: Piece)
	for _, bit in it.parts do
		bit.part:Destroy()
	end
	table.clear(it.parts)
end

--[[ A cube left behind at `at` that shrinks and fades: a tail's spark. ]]
local function spark(at: Vector3, size: number, colour: Color3, life: number)
	local bit = Voxel.cube(size, colour, true)
	bit.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	Voxel.run(life, function(t)
		bit.Size = Vector3.one * size * (1 - t * 0.8)
		bit.Transparency = 0.1 + 0.9 * t
		return nil
	end, function()
		bit:Destroy()
	end)
end

--[[ Wishing Star ]]

--[[ A five-pointed star of cubes, upright, facing down its own -Z. ]]
local function buildStar(scale: number): Piece
	local star = piece()
	add(star, Vector3.new(1.1, 1.1, 0.6) * scale, STAR_GOLD, CFrame.identity, true)
	for arm = 0, 4 do
		local angle = arm / 5 * math.pi * 2
		local out = CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.95 * scale, 0)
		add(star, Vector3.new(0.6, 0.9, 0.5) * scale, STAR_GOLD, out, true)
		add(
			star,
			Vector3.new(0.3, 0.45, 0.4) * scale,
			FOAM,
			out * CFrame.new(0, 0.6 * scale, 0),
			true
		)
	end
	Voxel.light(star.parts[1].part, STAR_GOLD, 12, 3)
	return star
end

local function onWishingStar(model: Instance?, at: Vector3, delay: number, radius: number)
	SoundFx.play("fx_wishing_star")
	local star = buildStar(1.2)
	local drift = Vector3.new(-5, 14, -3)
	local lastSpark = 0
	Voxel.run(math.max(delay, 0.05), function(t)
		local target = standing(model, at)
		local fall = t * t
		local position = flat(target, HEIGHT) + drift * (1 - fall)
		pose(star, CFrame.new(position) * CFrame.Angles(0, 0, t * 9))
		if t - lastSpark > 0.08 then
			lastSpark = t
			spark(position, 0.45, if math.random() < 0.5 then STAR_PINK else FOAM, 0.35)
		end
		return nil
	end, function()
		destroy(star)
		local landed = standing(model, at)
		local over = flat(landed, HEIGHT)
		Voxel.flash(over, 4, STAR_GOLD, 0.3)
		Voxel.ring(landed, radius, { STAR_GOLD, STAR_PINK }, 0.45)
		Voxel.burst(over, 10, { STAR_GOLD, STAR_PINK, FOAM }, 10, 0.5, 0.5, 6)
	end)
end

--[[ Spur Rowel ]]

--[[ A rowel of cubes: a brass hub and eight teal spikes round it, standing
     on its edge, its axle along its own X. ]]
local function buildRowel(): Piece
	local rowel = piece()
	add(rowel, Vector3.new(0.5, 0.8, 0.8), SPUR_BRASS, CFrame.identity, true)
	for spike = 0, 7 do
		local angle = spike / 8 * math.pi * 2
		local out = CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0.9, 0)
		add(rowel, Vector3.new(0.3, 0.75, 0.3), SPUR_TEAL, out, true)
	end
	Voxel.light(rowel.parts[1].part, SPUR_TEAL, 8, 2)
	return rowel
end

local function onSpurRowel(start: Vector3, points: { Vector3 }, times: { number })
	SoundFx.play("fx_spur_rowel")
	local height = 1.4
	local route = { flat(start, height) }
	for _, point in points do
		if typeof(point) == "Vector3" then
			table.insert(route, flat(point, height))
		end
	end
	local arrivals = { 0 }
	for _, at in times do
		if type(at) == "number" then
			table.insert(arrivals, at)
		end
	end
	if #route < 2 or #arrivals ~= #route then
		return
	end
	local rowel = buildRowel()
	local reached = 1
	local started = os.clock()
	local BOUNCE = 0.35
	Voxel.run(math.huge, function()
		local elapsed = os.clock() - started
		local roll = CFrame.Angles(-elapsed * 24, 0, 0)
		while reached < #route and elapsed >= arrivals[reached + 1] do
			reached += 1
			Voxel.flash(route[reached], 1.6, SPUR_TEAL, 0.15)
			Voxel.burst(flat(route[reached], 0.4), 6, { DUST, SPUR_BRASS }, 5, 0.4, 0.45, 3)
		end
		if reached < #route then
			local a, b = route[reached], route[reached + 1]
			local span = math.max(arrivals[reached + 1] - arrivals[reached], 1e-3)
			local t = math.clamp((elapsed - arrivals[reached]) / span, 0, 1)
			local heading = CFrame.lookAt(a, b)
			pose(
				rowel,
				CFrame.new(a:Lerp(b, t))
					* heading.Rotation
					* CFrame.Angles(0, math.pi / 2, 0)
					* roll
			)
			return nil
		end
		--[[ The last one struck: it bounces up off it and is gone. ]]
		local t = (elapsed - arrivals[#arrivals]) / BOUNCE
		if t >= 1 then
			return false
		end
		local last = route[#route]
		pose(rowel, CFrame.new(last + Vector3.new(0, math.sin(t * math.pi) * 2.2, 0)) * roll, t * t)
		return nil
	end, function()
		destroy(rowel)
	end)
end

--[[ Splash Wave ]]

local function onSplashWave(at: Vector3, radius: number, soaked: { Vector3 })
	SoundFx.play("fx_splash_wave")
	Voxel.flash(flat(at, HEIGHT), 3, WATER, 0.25)
	Voxel.ring(at, radius, { WATER, FOAM }, 0.4)
	Voxel.burst(flat(at, 1.2), 12, { WATER, FOAM }, 9, 0.55, 0.45, 8)
	for index, point in soaked do
		if index > Voxel.share(6) then
			break
		end
		if typeof(point) == "Vector3" then
			Voxel.burst(flat(point, HEIGHT), 3, { WATER, FOAM }, 4, 0.35, 0.3, 4)
		end
	end
end

--[[ Soaked enemies drip until they dry (`SoakedUntil`, polled as
     `ThornwoodFx` polls its webs). ]]
local nextDrip: { [Model]: number } = {}

local function dripStep(now: number)
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		table.clear(nextDrip)
		return
	end
	local clock = Workspace:GetServerTimeNow()
	for _, model in enemies:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local soaked = model:GetAttribute("SoakedUntil")
		if type(soaked) ~= "number" or soaked <= clock then
			nextDrip[model] = nil
			continue
		end
		if now < (nextDrip[model] or 0) then
			continue
		end
		nextDrip[model] = now + 0.12 + math.random() * 0.1
		local size = model:GetExtentsSize()
		local top = model:GetPivot().Position
		local from = Vector3.new(
			top.X + (math.random() - 0.5) * size.X * 0.6,
			top.Y + size.Y * 0.3,
			top.Z + (math.random() - 0.5) * size.Z * 0.6
		)
		local drop = Voxel.cube(0.28, WATER, true)
		local fall = math.max(0.5, from.Y - 0.2)
		Voxel.run(0.35, function(t)
			drop.CFrame = CFrame.new(from - Vector3.new(0, fall * t * t, 0))
			drop.Transparency = t * 0.6
			return nil
		end, function()
			drop:Destroy()
		end)
	end
	for model in nextDrip do
		if not model.Parent then
			nextDrip[model] = nil
		end
	end
end

--[[ Combo Counter ]]

--[[ The digits, and the x, as 3 by 5 pixels, row by row. ]]
local GLYPHS: { [string]: { string } } = {
	["0"] = { "###", "#.#", "#.#", "#.#", "###" },
	["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
	["2"] = { "###", "..#", "###", "#..", "###" },
	["3"] = { "###", "..#", ".##", "..#", "###" },
	["4"] = { "#.#", "#.#", "###", "..#", "..#" },
	["5"] = { "###", "#..", "###", "..#", "###" },
	["6"] = { "###", "#..", "###", "#.#", "###" },
	["7"] = { "###", "..#", ".#.", ".#.", ".#." },
	["8"] = { "###", "#.#", "###", "#.#", "###" },
	["9"] = { "###", "#.#", "###", "..#", "###" },
	x = { "...", "#.#", ".#.", "#.#", "..." },
}
--[[ One pixel's side on screen, and the gap between glyphs, in pixels. ]]
local PIXEL = 7
local GAP = 3

type Counter = {
	gui: BillboardGui,
	scale: UIScale,
	pixels: { Frame },
	shown: number,
	poppedAt: number,
}
local counters: { [Player]: Counter } = {}
local comboFull = AssassinRules.comboFull(
	Balance.Player.daggers.combo.step,
	Abilities.byId.ComboCounter.levels[1]
)

--[[ Draws `text` in pixels into `gui`, red with a blue shadow (gold when
     the count is full). ]]
local function drawCount(counter: Counter, text: string, full: boolean)
	for _, pixel in counter.pixels do
		pixel:Destroy()
	end
	table.clear(counter.pixels)
	local x = 0
	for index = 1, #text do
		local glyph = GLYPHS[string.sub(text, index, index)]
		if not glyph then
			continue
		end
		for row, line in glyph do
			for column = 1, 3 do
				if string.sub(line, column, column) == "#" then
					--[[ The blue shadow a little down and right, the face over it. ]]
					local face = if full then ARCADE_GOLD else ARCADE_RED
					for _, layer in
						{
							{ shift = 2, colour = ARCADE_BLUE, z = 1 },
							{ shift = 0, colour = face, z = 2 },
						}
					do
						local pixel = Instance.new("Frame")
						pixel.BorderSizePixel = 0
						pixel.BackgroundColor3 = layer.colour
						pixel.Size = UDim2.fromOffset(PIXEL, PIXEL)
						pixel.Position = UDim2.fromOffset(
							x + (column - 1) * PIXEL + layer.shift,
							(row - 1) * PIXEL + layer.shift
						)
						pixel.ZIndex = layer.z
						pixel.Parent = counter.gui
						table.insert(counter.pixels, pixel)
					end
				end
			end
		end
		x += 3 * PIXEL + GAP
	end
	counter.gui.Size = UDim2.fromOffset(math.max(x - GAP + 2, 1), 5 * PIXEL + 2)
end

local function dropCounter(player: Player, shatter: boolean)
	local counter = counters[player]
	if not counter then
		return
	end
	counters[player] = nil
	local adornee = counter.gui.Adornee
	if shatter and adornee and adornee:IsA("BasePart") and adornee.Parent then
		local over = adornee.Position + Vector3.new(0, 3.2, 0)
		Voxel.burst(over, 10, { ARCADE_RED, ARCADE_BLUE }, 7, 0.5, 0.35, 5)
		SoundFx.play("fx_combo_break")
	end
	counter.gui:Destroy()
end

local function countersStep(now: number)
	local lobby = Workspace:GetAttribute("InLobby") == true
	for _, player in Players:GetPlayers() do
		local raw = player:GetAttribute("ComboCount")
		local count = if type(raw) == "number" and not lobby then math.floor(raw) else 0
		local root = rootOf(player)
		local counter = counters[player]
		if count <= 0 or not root then
			if counter then
				dropCounter(player, counter.shown > 0 and not lobby and root ~= nil)
			end
			continue
		end
		if not counter then
			local gui = Instance.new("BillboardGui")
			gui.Name = "ComboCounter"
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
			gui.Adornee = root
			gui.Parent = Voxel.folder()
			local scale = Instance.new("UIScale")
			scale.Parent = gui
			counter = { gui = gui, scale = scale, pixels = {}, shown = 0, poppedAt = -math.huge }
			counters[player] = counter
		end
		local held = counter :: Counter
		if held.gui.Adornee ~= root then
			held.gui.Adornee = root
		end
		if held.shown ~= count then
			held.shown = count
			held.poppedAt = now
			drawCount(held, "x" .. tostring(count), count >= comboFull)
			SoundFx.play("fx_combo_counter")
		end
		--[[ Popping big as it counts, and settling. ]]
		local since = now - held.poppedAt
		held.scale.Scale = 1 + 0.35 * math.max(0, 1 - since / 0.18)
	end
	for player in counters do
		if not player.Parent then
			dropCounter(player, false)
		end
	end
end

--[[ Comet Crash ]]

local function onCometCrash(model: Instance?, at: Vector3, delay: number, radius: number)
	SoundFx.play("fx_comet_crash")
	local core = Voxel.cube(1.3, COMET_WHITE, true)
	local shell = Voxel.cube(1.9, COMET_VIOLET, true)
	shell.Transparency = 0.35
	Voxel.light(core, COMET_VIOLET, 14, 3)
	local high = Vector3.new(4, 17, 3)
	--[[ It glints high over the enemy for most of the wait, then falls. ]]
	local HOLD = 0.68
	local lastSpark = 0
	Voxel.run(math.max(delay, 0.05), function(t)
		local target = flat(standing(model, at), HEIGHT)
		local position
		if t < HOLD then
			local grow = t / HOLD
			position = target + high
			local pulse = 1 + math.sin(t * 40) * 0.12
			core.Size = Vector3.one * (0.5 + 0.8 * grow) * pulse
			shell.Size = Vector3.one * (0.8 + 1.1 * grow) * pulse
		else
			local fall = (t - HOLD) / (1 - HOLD)
			position = target + high * (1 - fall * fall)
			if t - lastSpark > 0.025 then
				lastSpark = t
				spark(position, 0.6, if math.random() < 0.5 then COMET_PINK else COMET_VIOLET, 0.4)
			end
		end
		core.CFrame = CFrame.new(position) * CFrame.Angles(t * 6, t * 4, 0)
		shell.CFrame = CFrame.new(position) * CFrame.Angles(-t * 5, t * 7, 0)
		return nil
	end, function()
		core:Destroy()
		shell:Destroy()
		local landed = standing(model, at)
		Voxel.flash(flat(landed, 1.5), 4.5, COMET_VIOLET, 0.3)
		Voxel.ring(landed, radius, { COMET_VIOLET, COMET_PINK }, 0.45)
		Voxel.burst(
			flat(landed, 1),
			12,
			{ COMET_VIOLET, COMET_PINK, COMET_WHITE },
			10,
			0.55,
			0.5,
			9
		)
	end)
end

--[[ Bell Chime ]]

--[[ A bell of cubes hanging from its own origin: a red cord on top, the
     bell widening downward, a clapper under its lip. ]]
local function buildBell(): Piece
	local bell = piece()
	add(bell, Vector3.new(0.5, 0.5, 0.5), BELL_CORD, CFrame.new(0, -0.1, 0), true)
	add(bell, Vector3.new(0.8, 0.4, 0.8), BELL_GOLD, CFrame.new(0, -0.5, 0), true)
	add(bell, Vector3.new(1.3, 0.6, 1.3), BELL_GOLD, CFrame.new(0, -0.95, 0), true)
	add(bell, Vector3.new(1.8, 0.6, 1.8), BELL_GOLD, CFrame.new(0, -1.5, 0), true)
	add(bell, Vector3.new(2.2, 0.3, 2.2), BELL_PINK, CFrame.new(0, -1.9, 0), true)
	add(bell, Vector3.new(0.45, 0.45, 0.45), BELL_CORD, CFrame.new(0, -2.25, 0), true)
	Voxel.light(bell.parts[3].part, BELL_GOLD, 14, 3)
	return bell
end

local function onBellChime(
	owner: Player,
	at: Vector3,
	radius: number,
	hold: number,
	held: { Vector3 }
)
	SoundFx.play("fx_bell_chime")
	local bell = buildBell()
	local root = rootOf(owner)
	local LIFE = 0.75
	Voxel.run(LIFE, function(t)
		local base = if root and root.Parent then root.Position else flat(at, 2)
		local swing = math.sin(t * math.pi * 4) * math.rad(28) * (1 - t)
		pose(
			bell,
			CFrame.new(base + Vector3.new(0, 6.2, 0)) * CFrame.Angles(0, 0, swing),
			math.clamp((t - 0.7) / 0.3, 0, 1)
		)
		return nil
	end, function()
		destroy(bell)
	end)
	Voxel.ring(at, radius, { BELL_GOLD, BELL_PINK }, 0.5, 0.6)
	task.delay(0.08, function()
		Voxel.ring(at, radius, { BELL_GOLD }, 0.5, 1.4)
	end)
	--[[ A ring of gold turning round each held enemy's feet. ]]
	for index, point in held do
		if index > Voxel.share(10) or typeof(point) ~= "Vector3" then
			continue
		end
		local bits: { Part } = {}
		for _ = 1, 6 do
			table.insert(bits, Voxel.cube(0.35, BELL_GOLD, true))
		end
		Voxel.run(math.max(hold, 0.1), function(t)
			for n, bit in bits do
				local angle = n / #bits * math.pi * 2 + t * 6
				bit.CFrame = CFrame.new(
					point.X + math.cos(angle) * 1.6,
					0.5,
					point.Z + math.sin(angle) * 1.6
				)
				bit.Transparency = math.clamp((t - 0.75) / 0.25, 0, 1)
			end
			return nil
		end, function()
			for _, bit in bits do
				bit:Destroy()
			end
		end)
	end
end

--[[ Lava Burst ]]

--[[ Studs between the bursts along the lane. ]]
local LAVA_STEP = 1.7

local function eruption(at: Vector3, size: number)
	local crack = Voxel.cube(Vector3.new(size * 1.6, 0.2, size * 1.6), LAVA, true)
	crack.CFrame = CFrame.new(flat(at, 0.15)) * CFrame.Angles(0, math.random() * 3, 0)
	Voxel.run(0.6, function(t)
		crack.Color = LAVA_HOT:Lerp(ROCK, t)
		crack.Transparency = math.clamp((t - 0.5) / 0.5, 0, 1)
		return nil
	end, function()
		crack:Destroy()
	end)
	Voxel.flash(flat(at, 0.8), 1.6 * size, LAVA, 0.22)
	Voxel.burst(flat(at, 0.4), 5, { LAVA, LAVA_HOT, ROCK }, 3.5, 0.5, 0.45 * size, 11)
end

local function onLavaBurst(start: Vector3, forward: Vector3, length: number, speed: number)
	SoundFx.play("fx_lava_burst")
	local direction = flat(forward)
	if direction.Magnitude < 1e-3 or speed <= 0 then
		return
	end
	direction = direction.Unit
	local count = math.max(1, math.floor(length / LAVA_STEP))
	for index = 0, count do
		local along = math.min(index * LAVA_STEP, length)
		task.delay(along / speed, function()
			eruption(start + direction * along, 1 - 0.3 * index / count)
		end)
	end
end

function DaggerFx.start()
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, owner: Player, ...)
			local a, b, c, d = ...
			if kind == "WishingStar" then
				if typeof(b) == "Vector3" and type(c) == "number" and type(d) == "number" then
					onWishingStar(if typeof(a) == "Instance" then a else nil, b, c, d)
				end
			elseif kind == "SpurRowel" then
				if typeof(a) == "Vector3" and type(b) == "table" and type(c) == "table" then
					onSpurRowel(a, b, c)
				end
			elseif kind == "SplashWave" then
				if typeof(a) == "Vector3" and type(b) == "number" and type(c) == "table" then
					onSplashWave(a, b, c)
				end
			elseif kind == "CometCrash" then
				if typeof(b) == "Vector3" and type(c) == "number" and type(d) == "number" then
					onCometCrash(if typeof(a) == "Instance" then a else nil, b, c, d)
				end
			elseif kind == "BellChime" then
				if
					typeof(owner) == "Instance"
					and owner:IsA("Player")
					and typeof(a) == "Vector3"
					and type(b) == "number"
					and type(c) == "number"
					and type(d) == "table"
				then
					onBellChime(owner, a, b, c, d)
				end
			elseif kind == "LavaBurst" then
				if
					typeof(a) == "Vector3"
					and typeof(b) == "Vector3"
					and type(c) == "number"
					and type(d) == "number"
				then
					onLavaBurst(a, b, c, d)
				end
			end
		end)
	local sinceLastDrip = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		sinceLastDrip += deltaTime
		if sinceLastDrip >= 0.05 then
			sinceLastDrip = 0
			dripStep(now)
		end
		countersStep(now)
	end)
end

return DaggerFx
