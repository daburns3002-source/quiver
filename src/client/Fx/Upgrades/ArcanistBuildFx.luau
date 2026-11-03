--!strict
--[[
	The Arcanist's class upgrades of 2026-10-27, drawn big
	(`Combat/ClassUpgrades` decides every hit):

	- Black Hole (Mythic): a black orb ringed in violet flies to the target;
	  there a hole opens, a black core under a spinning spiral disc of cubes
	  in the rainbow (rule 12) drawn inwards, its dark well on the floor as
	  wide as its pull, cubes sucked in from the edge; then it implodes: the
	  core snaps shut, a white-violet flash, a ring and a burst, a shake.
	- Elemental Orbs (Epic): the orb this player casts takes the colour of
	  its element (`OrbElement` on the player, the server's next cast) and
	  its dress: flame cubes behind fire, ice shards round ice, sparks
	  crackling round lightning; and its own burst where it lands.
	- Arcane Turret (Legendary): while a player's `TurretUntil` is ahead, a
	  tall crystal of blue cubes hovers beside them over a turning ring of
	  runes, glowing gold at its heart; each orb it casts flashes at its tip;
	  it rises in a burst and shatters when its time is up.

	Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local TopDownCamera = require(script.Parent.Parent.Parent.Camera.TopDownCamera)
local UpgradeFx = require(script.Parent.UpgradeFx)
local Voxel = require(script.Parent.Voxel)

local ArcanistBuildFx = {}

local VIOLET = Color3.fromRGB(150, 70, 255)
local MAGENTA = Color3.fromRGB(230, 70, 220)
local VOID = Color3.fromRGB(8, 4, 14)
local CRYSTAL =
	{ Color3.fromRGB(90, 200, 255), Color3.fromRGB(160, 235, 255), Color3.fromRGB(60, 140, 255) }
local RUNE = Color3.fromRGB(140, 80, 230)
local GOLD = Color3.fromRGB(255, 205, 70)

local ELEMENT_COLOUR: { [string]: { Color3 } } = {
	Fire = {
		Color3.fromRGB(255, 110, 30),
		Color3.fromRGB(255, 190, 50),
		Color3.fromRGB(255, 70, 30),
	},
	Ice = {
		Color3.fromRGB(160, 235, 255),
		Color3.fromRGB(230, 250, 255),
		Color3.fromRGB(110, 190, 255),
	},
	Lightning = {
		Color3.fromRGB(255, 240, 80),
		Color3.fromRGB(255, 255, 200),
		Color3.fromRGB(255, 210, 40),
	},
}

--[[ Black Hole ]]

type Hole = { at: Vector3, close: (() -> ())? }
local holes: { Hole } = {}

local function openHole(at: Vector3, duration: number, radius: number)
	SoundFx.play("fx_black_hole")
	local hole: Hole = { at = at }
	table.insert(holes, hole)
	local centre = Vector3.new(at.X, 1.6, at.Z)

	local core = Voxel.cube(0.1, VOID, false)
	core.Shape = Enum.PartType.Ball
	local rim = Voxel.cube(0.1, VIOLET, true)
	rim.Shape = Enum.PartType.Ball
	rim.Transparency = 0.6
	Voxel.light(rim, VIOLET, radius * 1.5, 3)
	local well = Voxel.cube(Vector3.new(0.05, radius * 2, radius * 2), Color3.fromRGB(30, 10, 50))
	well.Shape = Enum.PartType.Cylinder
	well.CFrame = CFrame.new(at.X, 0.08, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
	well.Transparency = 1

	-- the spiral disc: cubes on two arms, drawn in and round
	local n = Voxel.share(26)
	local disc: { { part: Part, phase: number } } = {}
	for index = 1, n do
		local part = Voxel.cube(0.55, if index % 2 == 0 then VIOLET else MAGENTA, true)
		table.insert(disc, { part = part, phase = index / n })
	end
	local elapsed = 0
	local closing = false
	local function finish()
		core:Destroy()
		rim:Destroy()
		well:Destroy()
		for _, piece in disc do
			piece.part:Destroy()
		end
		local found = table.find(holes, hole)
		if found then
			table.remove(holes, found)
		end
	end
	hole.close = function()
		closing = true
	end
	-- a little past its time, in case the implosion never arrives
	Voxel.run(duration + 0.6, function(_t, dt)
		elapsed += dt
		if closing then
			return false
		end
		local open = math.min(1, elapsed / 0.25)
		core.Size = Vector3.one * 2.6 * open
		core.CFrame = CFrame.new(centre)
		rim.Size = Vector3.one * (3.2 + math.sin(elapsed * 12) * 0.2) * open
		rim.CFrame = CFrame.new(centre)
		well.Transparency = 1 - 0.55 * open
		for index, piece in disc do
			-- each cube falls inward along its arm and starts again at the edge
			local fall = (piece.phase + elapsed * 0.6) % 1
			local r = (radius * 0.95) * (1 - fall) + 1.4
			local arm = if index % 2 == 0 then 0 else math.pi
			local angle = arm + fall * math.pi * 2.2 + elapsed * 3
			piece.part.CFrame = CFrame.new(
				centre.X + math.cos(angle) * r,
				centre.Y - 0.9 + fall * 0.9,
				centre.Z + math.sin(angle) * r
			) * CFrame.Angles(elapsed * 4, angle, 0)
			piece.part.Size = Vector3.one * (0.3 + 0.5 * (1 - fall)) * open
			piece.part.Color = Voxel.rainbow(elapsed, piece.phase * 0.5)
		end
		return nil
	end, finish)
end

local function flyToHole(
	origin: Vector3,
	at: Vector3,
	flight: number,
	duration: number,
	radius: number
)
	local orb = Voxel.cube(1.3, VOID, false)
	orb.Shape = Enum.PartType.Ball
	local glow = Voxel.cube(1.9, VIOLET, true)
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.55
	Voxel.light(glow, VIOLET, 10, 3)
	local to = Vector3.new(at.X, origin.Y, at.Z)
	Voxel.run(math.max(flight, 0.05), function(t)
		local position = origin:Lerp(to, t)
		orb.CFrame = CFrame.new(position)
		glow.CFrame = CFrame.new(position)
		glow.Size = Vector3.one * (1.9 + math.sin(t * 30) * 0.2)
		return nil
	end, function()
		orb:Destroy()
		glow:Destroy()
		Voxel.flash(Vector3.new(at.X, 1.6, at.Z), 4, VIOLET, 0.25)
		openHole(at, duration, radius)
	end)
end

local function implode(at: Vector3, radius: number)
	SoundFx.play("fx_black_hole_implode")
	local nearest: Hole? = nil
	local best = 3
	for _, hole in holes do
		local away = (hole.at - at).Magnitude
		if away < best then
			nearest = hole
			best = away
		end
	end
	local close = nearest and nearest.close
	if close then
		close()
	end
	local centre = Vector3.new(at.X, 1.6, at.Z)
	Voxel.flash(centre, radius * 2, Color3.fromRGB(235, 210, 255), 0.35)
	Voxel.ring(at, radius * 1.3, { VIOLET, MAGENTA, Color3.new(1, 1, 1) }, 0.45)
	Voxel.burst(centre, 24, { VIOLET, MAGENTA, Color3.new(1, 1, 1) }, 18, 0.8, 0.6, 10)
	TopDownCamera.shake(0.6, 0.35)
end

--[[ Elemental Orbs ]]

type Tinted = { part: BasePart, element: string }
local tinted: { Tinted } = {}

local function elementNow(): string?
	if UpgradeFx.level("ElementalOrbs") <= 0 then
		return nil
	end
	local element = Players.LocalPlayer:GetAttribute("OrbElement")
	return if type(element) == "string" and ELEMENT_COLOUR[element] then element else nil
end

local function dressOrb(part: BasePart, element: string)
	local colours = ELEMENT_COLOUR[element]
	part.Color = colours[1]
	local light = part:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Color = colours[1]
	end
	local entry: Tinted = { part = part, element = element }
	table.insert(tinted, entry)
	local count = Voxel.share(4)
	local bits: { Part } = {}
	for index = 1, count do
		table.insert(bits, Voxel.cube(0.35, colours[(index % #colours) + 1], true))
	end
	local elapsed = 0
	Voxel.run(math.huge, function(_t, dt)
		elapsed += dt
		if not part.Parent then
			return false
		end
		local frame = part.CFrame
		for index, bit in bits do
			local offset: CFrame
			if element == "Fire" then
				-- flames streaming behind, flickering up
				local back = ((elapsed * 4 + index / count) % 1)
				offset = CFrame.new((index - count / 2) * 0.2, back * 0.8, 0.6 + back * 1.8)
				bit.Transparency = back
			elseif element == "Ice" then
				-- shards circling the orb
				local angle = elapsed * 9 + index / count * math.pi * 2
				offset = CFrame.new(math.cos(angle) * 0.9, math.sin(angle) * 0.9, 0)
					* CFrame.Angles(0, 0, math.rad(45))
				bit.Transparency = 0
			else
				-- sparks jumping round it
				local jump = math.floor(elapsed * 20 + index) % 7
				local angle = jump / 7 * math.pi * 2
				offset = CFrame.new(math.cos(angle) * 0.8, math.sin(angle) * 0.8, (index % 2) * 0.4)
				bit.Transparency = if (math.floor(elapsed * 30) + index) % 3 == 0 then 1 else 0
			end
			bit.CFrame = frame * offset
		end
		return nil
	end, function()
		for _, bit in bits do
			bit:Destroy()
		end
		local found = table.find(tinted, entry)
		if found then
			table.remove(tinted, found)
		end
	end)
end

local function onContact(position: Vector3, _heading: Vector3, pool: string, _pierce: number)
	if pool ~= "PlayerOrb" or #tinted == 0 then
		return
	end
	local nearest: Tinted? = nil
	local best = 4
	for _, entry in tinted do
		local away = (entry.part.Position - position).Magnitude
		if away < best then
			nearest = entry
			best = away
		end
	end
	if not nearest then
		return
	end
	local colours = ELEMENT_COLOUR[nearest.element]
	if nearest.element == "Fire" then
		Voxel.burst(position, 10, colours, 9, 0.5, 0.45, 9)
		Voxel.flash(position, 3, colours[1], 0.25)
	elseif nearest.element == "Ice" then
		Voxel.burst(position, 8, colours, 6, 0.6, 0.55, 4)
		Voxel.ring(Vector3.new(position.X, 0, position.Z), 2.5, colours, 0.4, 0.3)
	else
		Voxel.flash(position, 3.5, colours[2], 0.18)
		Voxel.burst(position, 8, colours, 14, 0.3, 0.3, 3)
	end
end

--[[ Arcane Turret ]]

type Turret = { owner: Player, parts: { Part }, tip: Part, built: number }
local turrets: { [Player]: Turret } = {}

local function turretFrame(owner: Player, time: number): CFrame?
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local at = root.Position + Balance.Player.turret.offset
	return CFrame.new(at.X, at.Y + 0.6 + math.sin(time * 2.5) * 0.3, at.Z)
end

local function buildTurret(owner: Player)
	SoundFx.play("fx_turret")
	local parts: { Part } = {}
	-- a tall diamond: widening, then narrowing to a point
	local rows = { 0.4, 0.8, 1.1, 1.2, 1.0, 0.75, 0.5, 0.25 }
	for index, width in rows do
		local part =
			Voxel.cube(Vector3.new(width, 0.42, width), CRYSTAL[(index % #CRYSTAL) + 1], true)
		part:SetAttribute("Row", index)
		table.insert(parts, part)
	end
	local heart = Voxel.cube(0.55, GOLD, true)
	heart:SetAttribute("Heart", true)
	Voxel.light(heart, CRYSTAL[1], 12, 2.5)
	table.insert(parts, heart)
	for index = 1, Voxel.share(8) do
		local rune = Voxel.cube(Vector3.new(0.4, 0.18, 0.4), RUNE, true)
		rune:SetAttribute("Rune", index)
		table.insert(parts, rune)
	end
	turrets[owner] = { owner = owner, parts = parts, tip = parts[#rows], built = os.clock() }
	local frame = turretFrame(owner, 0)
	if frame then
		Voxel.burst(frame.Position, 14, CRYSTAL, 9, 0.6, 0.45, 9)
		Voxel.flash(frame.Position, 3.5, CRYSTAL[2], 0.3)
	end
end

local function shatter(owner: Player)
	local turret = turrets[owner]
	if not turret then
		return
	end
	turrets[owner] = nil
	local frame = turretFrame(owner, os.clock() - turret.built)
	if frame then
		Voxel.burst(frame.Position + Vector3.new(0, 1.5, 0), 16, CRYSTAL, 10, 0.7, 0.5, 8)
	end
	for _, part in turret.parts do
		part:Destroy()
	end
end

local function turretStep()
	local now = Workspace:GetServerTimeNow()
	for _, owner in Players:GetPlayers() do
		local untilTime = owner:GetAttribute("TurretUntil")
		local up = type(untilTime) == "number" and untilTime > now
		if up and not turrets[owner] then
			buildTurret(owner)
		elseif not up and turrets[owner] then
			shatter(owner)
		end
	end
	for owner, turret in turrets do
		if not owner.Parent then
			shatter(owner)
			continue
		end
		local time = os.clock() - turret.built
		local frame = turretFrame(owner, time)
		if not frame then
			continue
		end
		local rise = math.min(1, time / 0.3)
		local base = frame * CFrame.new(0, -1.6 * (1 - rise), 0)
		local maxRow = 8
		for _, part in turret.parts do
			local row = part:GetAttribute("Row") :: number?
			local rune = part:GetAttribute("Rune") :: number?
			if row then
				part.CFrame = base * CFrame.new(0, row * 0.42, 0) * CFrame.Angles(0, time * 1.5, 0)
			elseif rune then
				local angle = rune / 8 * math.pi * 2 - time * 2
				part.CFrame = CFrame.new(
					base.Position.X + math.cos(angle) * 1.4,
					base.Position.Y - 1.1,
					base.Position.Z + math.sin(angle) * 1.4
				) * CFrame.Angles(0, -angle, 0)
			else
				-- the gold heart beats inside the crystal: a Legendary's glow
				part.CFrame = base
					* CFrame.new(0, maxRow * 0.42 * 0.45, 0)
					* CFrame.Angles(time * 2, time * 3, 0)
				part.Size = Vector3.one * (0.55 + math.sin(time * 8) * 0.1)
			end
		end
	end
end

local function onLaunched(part: BasePart, pool: string, _aim: Vector3, from: Model?, look: string?)
	if look == "TurretOrb" then
		-- the nearest crystal flashes at its tip as it casts
		for _, turret in turrets do
			if (turret.tip.Position - part.Position).Magnitude < 6 then
				Voxel.flash(turret.tip.Position, 1.8, CRYSTAL[2], 0.15)
			end
		end
		part.Color = CRYSTAL[1]
		return
	end
	if pool ~= "PlayerOrb" or from ~= nil or look ~= "Orb" then
		return
	end
	local element = elementNow()
	if element then
		dressOrb(part, element)
	end
end

function ArcanistBuildFx.start()
	FxEvents.launched:connect(onLaunched)
	FxEvents.contact:connect(onContact)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			local args = { ... }
			if kind == "BlackHole" then
				flyToHole(args[1], args[2], args[3], args[4], args[5])
			elseif kind == "BlackHoleImplode" then
				implode(args[1], args[2])
			end
		end)
	RunService.Heartbeat:Connect(turretStep)
end

return ArcanistBuildFx
