--!strict
--[[
	Chain Lightning's bolt (owner, 2026-11-11: "chain lightning should be like
	the stattik shiv effect"): a bright, jagged, forked bolt that snaps from
	the enemy struck to the next, white-hot inside a coloured glow, re-kinked
	every few hundredths of a second so it crackles, with sparks and a flash
	on each enemy it touches, gone in a fraction of a second.

	Built in code, since it has to reach between two real bodies: its shape is
	`Shared/Util/BoltPath`'s (flat on the ground plane, so the top-down camera
	sees its whole width), drawn as neon boxes. The server sends one arc per
	hop, each a few hundredths of a second after the last
	(`Balance.Projectile.arcSpeed`), so a chain is this played two or three
	times in quick succession.

	Cheap on a phone: every box and spark emitter is pooled, a bolt of one
	length always has the same number of pieces (a re-kink moves them, it
	builds nothing), and the number of bolts, forks and sparks is the
	device's share (`UpgradeFx.budget`).

	Presentation only. The hit, the white flash and the knockback are the
	server's hit, drawn by `Fx/HitFeedback` as for any other.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BoltPath = require(ReplicatedStorage.Shared.Util.BoltPath)
local PetAuras = require(ReplicatedStorage.Shared.Config.PetAuras)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx.bolt

--[[ Spark emitters kept in the world and used in turn: a spark already
     thrown stays where it is when its emitter moves on. ]]
local SPARK_ANCHORS = 6
--[[ A fading bolt thins in this many steps, as the other effects step. ]]
local FADE_STEPS = 3

local LightningFx = {}

type Piece = {
	core: BasePart,
	glow: BasePart,
	--[[ Its sizes at full width, and how far along the bolt it starts (0 to
	     1), which is when the snap reaches it. ]]
	coreSize: Vector3,
	glowSize: Vector3,
	along: number,
}

type Strike = {
	from: Vector3,
	to: Vector3,
	toModel: Model?,
	pieces: { Piece },
	shape: BoltPath.Shape,
	random: Random,
	started: number,
	--[[ Seconds the snap takes to reach the far end, where it lands. ]]
	travel: number,
	landed: boolean,
	kinkedAt: number,
	--[[ What was last drawn, so a frame that changes nothing writes nothing. ]]
	reveal: number,
	thin: number,
}

type Flash = { part: BasePart, started: number, turn: number, at: Vector3 }

local folder: Folder? = nil
local spare: { Piece } = {}
local strikes: { Strike } = {}
local spareFlashes: { BasePart } = {}
local flashes: { Flash } = {}
local sparks: { ParticleEmitter } = {}
local nextSpark = 1
local lastSound = 0
--[[ When each enemy was last touched: one chain's hop lands on an enemy
     and the next leaves it within a frame or two, which is one touch. ]]
local touchedAt: { [Model]: number } = setmetatable({} :: any, { __mode = "k" })

local function neon(name: string, colour: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	return part
end

local function takePiece(): Piece
	local piece = table.remove(spare)
	if piece then
		return piece
	end
	return {
		core = neon("BoltCore", K.coreColour),
		glow = neon("BoltGlow", K.glowColour),
		coreSize = Vector3.one,
		glowSize = Vector3.one,
		along = 0,
	}
end

--[[ Lays one piece from `a` to `b`, `width` of the bolt's own. Each box
     runs a little past its joints so a kink leaves no gap. ]]
local function lay(piece: Piece, a: Vector3, b: Vector3, width: number, along: number)
	local length = (b - a).Magnitude
	if length < 1e-3 then
		b = a + Vector3.new(0, 0, -1e-3)
		length = 1e-3
	end
	local frame = CFrame.lookAt((a + b) / 2, b)
	local core = K.core * width
	local glow = K.glow * width
	piece.core.CFrame = frame
	piece.glow.CFrame = frame
	piece.coreSize = Vector3.new(core, core, length + core)
	-- the glow is a flat band: its width is what the camera above reads
	piece.glowSize = Vector3.new(glow, glow * 0.5, length + glow * 0.5)
	piece.along = along
end

--[[ A new jagged path for the strike, laid over the pieces it already has. ]]
local function kink(strike: Strike)
	local bolt = BoltPath.build(strike.from, strike.to, strike.shape, strike.random)
	local span = strike.to - strike.from
	local reach = math.max(span:Dot(span), 1e-6)
	local index = 0
	local count = #bolt.main - 1
	for i = 1, count do
		index += 1
		lay(strike.pieces[index], bolt.main[i], bolt.main[i + 1], 1, (i - 1) / count)
	end
	for _, fork in bolt.forks do
		local along = math.clamp((fork[1] - strike.from):Dot(span) / reach, 0, 1)
		local segments = #fork - 1
		for s = 1, segments do
			index += 1
			-- a fork tapers away from the bolt
			local width = K.forkWidth * (1 - 0.4 * (s - 1) / segments)
			lay(strike.pieces[index], fork[s], fork[s + 1], width, along)
		end
	end
end

--[[ Draws the strike at its present moment: the pieces the snap has
     reached, at the width its fade has left. ]]
local function draw(strike: Strike, reveal: number, thin: number)
	strike.reveal = reveal
	strike.thin = thin
	local clear = 1 - thin
	for _, piece in strike.pieces do
		if piece.along > reveal then
			piece.core.Transparency = 1
			piece.glow.Transparency = 1
			continue
		end
		local c, g = piece.coreSize, piece.glowSize
		piece.core.Size = Vector3.new(c.X * thin, c.Y * thin, c.Z)
		piece.glow.Size = Vector3.new(g.X * thin, g.Y * thin, g.Z)
		piece.core.Transparency = clear * 0.5
		piece.glow.Transparency = K.glowClear + (1 - K.glowClear) * clear
	end
end

--[[ Sparks and a flash on an enemy the lightning touches. ]]
local function touch(at: Vector3, model: Model?)
	local parent = folder
	if not parent then
		return
	end
	local now = os.clock()
	if model then
		local last = touchedAt[model]
		if last and now - last < K.touchGap then
			return
		end
		touchedAt[model] = now
	end

	local emitter = sparks[nextSpark]
	nextSpark = nextSpark % #sparks + 1
	local anchor = emitter.Parent
	if anchor and anchor:IsA("BasePart") then
		anchor.CFrame = CFrame.new(at)
	end
	emitter:Emit(UpgradeFx.budget(K.sparks, 4))

	local part = table.remove(spareFlashes) or neon("BoltFlash", K.coreColour)
	part.Parent = parent
	table.insert(flashes, { part = part, started = now, turn = math.random() * math.pi, at = at })
end

local function step()
	local now = os.clock()

	for i = #strikes, 1, -1 do
		local strike = strikes[i]
		local t = now - strike.started
		if t >= K.life then
			for _, piece in strike.pieces do
				piece.core.Parent = nil
				piece.glow.Parent = nil
				table.insert(spare, piece)
			end
			table.remove(strikes, i)
			continue
		end

		if not strike.landed and t >= strike.travel then
			strike.landed = true
			touch(strike.to, strike.toModel)
		end

		local reveal = if strike.travel > 0 then math.min(t / strike.travel, 1) else 1
		local fadeFrom = K.life * (1 - K.fade)
		local thin = 1
		if t > fadeFrom then
			local left = 1 - (t - fadeFrom) / (K.life - fadeFrom)
			thin = math.max(1, math.ceil(left * FADE_STEPS)) / FADE_STEPS
		end

		local crackled = now - strike.kinkedAt >= K.crackle
		if crackled then
			strike.kinkedAt = now
			kink(strike)
		end
		if crackled or reveal ~= strike.reveal or thin ~= strike.thin then
			draw(strike, reveal, thin)
		end
	end

	for i = #flashes, 1, -1 do
		local flash = flashes[i]
		local f = (now - flash.started) / K.flashLife
		if f >= 1 then
			flash.part.Parent = nil
			table.insert(spareFlashes, flash.part)
			table.remove(flashes, i)
			continue
		end
		-- snaps out wide and thins to nothing: flat, so it is seen from above
		local size = K.flash * (0.45 + 0.55 * f)
		flash.part.Size = Vector3.new(size, 0.3, size)
		flash.part.CFrame = CFrame.new(flash.at) * CFrame.Angles(0, flash.turn, 0)
		flash.part.Transparency = 0.15 + 0.85 * f
	end
end

--[[ One hop of the lightning, from `from` to `to`, its snap taking `travel`
     seconds to arrive; `fromModel` and `toModel` are the two enemies, when
     this client has them. Not drawn past the device's cap. ]]
function LightningFx.strike(
	from: Vector3,
	to: Vector3,
	travel: number,
	fromModel: Model?,
	toModel: Model?
)
	local parent = folder
	if not parent or #strikes >= UpgradeFx.budget(K.cap, 2) then
		return
	end

	local now = os.clock()
	if now - lastSound >= K.soundGap then
		lastSound = now
		SoundFx.play("fx_chain_lightning")
	end

	local shape: BoltPath.Shape = {
		segmentLength = K.segmentLength,
		minSegments = K.minSegments,
		maxSegments = K.maxSegments,
		kink = K.kink,
		forks = UpgradeFx.budget(K.forks, 1),
		forkShare = K.forkShare,
		forkReach = K.forkReach,
		forkAngle = K.forkAngle,
		forkSegments = K.forkSegments,
	}

	local length = (to - from).Magnitude
	local wanted = BoltPath.segments(length, shape)
		+ BoltPath.forkCount(length, shape) * shape.forkSegments
	local pieces: { Piece } = {}
	for _ = 1, wanted do
		local piece = takePiece()
		piece.core.Transparency = 1
		piece.glow.Transparency = 1
		piece.core.Parent = parent
		piece.glow.Parent = parent
		table.insert(pieces, piece)
	end

	local strike: Strike = {
		from = from,
		to = to,
		toModel = toModel,
		pieces = pieces,
		shape = shape,
		random = Random.new(),
		started = now,
		travel = math.max(travel, 0),
		landed = false,
		kinkedAt = now,
		reveal = -1,
		thin = 1,
	}
	kink(strike)
	draw(strike, 0, 1)
	table.insert(strikes, strike)

	touch(from, fromModel)
end

function LightningFx.start(parent: Instance)
	local made = Instance.new("Folder")
	made.Name = "ChainBolts"
	made.Parent = parent
	folder = made

	for index = 1, SPARK_ANCHORS do
		local anchor = Instance.new("Part")
		anchor.Name = "BoltSparks" .. index
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.CFrame = CFrame.new(0, -200, 0)
		anchor.Parent = made

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sparks"
		emitter.Enabled = false
		emitter.Texture = PetAuras.square
		emitter.Lifetime = NumberRange.new(0.12, 0.26)
		emitter.Speed = NumberRange.new(12, 30)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 6
		emitter.Rotation = NumberRange.new(0, 90)
		emitter.RotSpeed = NumberRange.new(-360, 360)
		emitter.LightEmission = 1
		emitter.ZOffset = 1.5
		emitter.Color = ColorSequence.new(K.coreColour, K.glowColour)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(1, 0.06),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = anchor
		table.insert(sparks, emitter)
	end

	RunService.RenderStepped:Connect(step)
end

return LightningFx
