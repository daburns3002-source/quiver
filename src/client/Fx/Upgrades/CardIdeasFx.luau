--!strict
--[[
	What the nineteen cards of 2026-11-27 look like (docs/CARD-IDEAS.md,
	owner: "Build all nineteen"; the server's side is `Combat/ClassUpgrades`,
	`Combat/MeleeSystem`, `Combat/ProjectileSystem` and `Run/RunSession`).
	The client only draws, in voxel cubes like the rest, and plays each
	card's sound (`Config/Sounds`, each an existing card's clip).

	From `Remotes.UpgradeFx` events:
	- Hunter's Mark: a red diamond over the enemy being aimed at.
	- Pin Down: a puff of earth where an arrow pinned (the roots are Root
	  Hold's, `Fx/RootHoldFx`). Serpent Arrow: a green bite.
	- Trick Shot: an orange flash where an arrow came off a wall.
	- Barrage: a gold burst as the fan leaves.
	- Skyfall: the archer leaps (the body lifted off its root joint on every
	  client, a shadow below), then a rainbow ring where they land.
	- Siphon: red cubes fly from the hit to the Arcanist.
	- Overcharge: a crackle of yellow and a red flash at the staff.
	- Mana Burn: blue flame off a healthy enemy.
	- Rune Circle: a violet ring on the floor with flames, while it burns.
	- Arcane Tether: a violet chain between two enemies, while it holds.
	- Starfall: its sound (the meteors are Meteor's own warnings).
	- Singularity: the great orb drawn rolling, white and violet, round the
	  plain orb the server flies.
	- Bellow: white rings of sound rolling out.
	- Grave Chains: iron chain links round each held enemy's feet.
	- Reaper's Harvest: green wisps from the body to the Warden.
	- Colossus: rocks thrown up all round him, and the room shakes.

	From attributes on each player, drawn every frame for every player:
	`BarrageReady` (gold sparks over the head), `SingularityFrom` (the orb
	growing at the staff), `StoneSkin` and `StoneSkinAt` (stone plates
	round him, crumbling as they take a hit), `CycloneBlades` (ruby blades
	whirling round him, on the shared orbit clock as Orbiting Orb's are).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local TopDownCamera = require(script.Parent.Parent.Parent.Camera.TopDownCamera)
local Voxel = require(script.Parent.Voxel)

local CardIdeasFx = {}

local RED = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 150) }
local EARTH = { Color3.fromRGB(120, 85, 50), Color3.fromRGB(90, 150, 60) }
local VENOM = { Color3.fromRGB(110, 220, 80), Color3.fromRGB(200, 255, 120) }
local ORANGE = { Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 220, 120) }
local GOLD = { Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 244, 190) }
local SPARK = { Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 255, 220) }
local BLUE_FLAME = { Color3.fromRGB(90, 120, 255), Color3.fromRGB(170, 150, 255) }
local VIOLET = { Color3.fromRGB(170, 100, 255), Color3.fromRGB(220, 170, 255) }
local FLAME = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 210, 90) }
local SOUND = { Color3.fromRGB(240, 245, 255), Color3.fromRGB(200, 220, 255) }
local IRON = Color3.fromRGB(70, 75, 85)
local GHOST = { Color3.fromRGB(150, 255, 170), Color3.fromRGB(210, 255, 220) }
local ROCK = { Color3.fromRGB(120, 95, 70), Color3.fromRGB(150, 130, 105) }
local STONE = Color3.fromRGB(150, 150, 155)
local RUBY = Color3.fromRGB(220, 40, 60)
local ORB_CORE = Color3.fromRGB(245, 240, 255)

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function bodyOf(model: Instance): BasePart?
	if model:IsA("Model") then
		return model.PrimaryPart
	end
	return nil
end

--[[ Cubes that fly from `from` to wherever `to` is now, then go. ]]
local function flyTo(
	from: Vector3,
	to: () -> Vector3?,
	colours: { Color3 },
	count: number,
	life: number
)
	local parts: { Part } = {}
	for index = 1, Voxel.share(count) do
		table.insert(parts, Voxel.cube(0.45, colours[index % #colours + 1], true))
	end
	Voxel.run(life, function(t)
		local target = to()
		if not target then
			return false
		end
		for index, part in parts do
			local lag = math.clamp(t * 1.4 - index * 0.05, 0, 1)
			local arc = math.sin(lag * math.pi) * 2
			part.Position = from:Lerp(target, lag) + Vector3.new(0, arc, 0)
			part.Transparency = if lag >= 1 then 1 else 0.1
		end
		return nil
	end, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
end

--[[ Hunter's Mark: each owner's diamond, on the enemy they aim at. ]]
local marks: { [Player]: { model: Model, part: Part } } = {}

local function onHuntersMark(owner: Player, model: Model?)
	local old = marks[owner]
	if old then
		old.part:Destroy()
		marks[owner] = nil
	end
	if not model then
		return
	end
	SoundFx.play("fx_hunters_mark")
	local part = Voxel.cube(Vector3.new(0.9, 0.9, 0.25), RED[1], true)
	Voxel.light(part, RED[1], 6, 1.5)
	marks[owner] = { model = model, part = part }
end

--[[ Skyfall: the body lifted off its root joint for the leap, on every
     client (a joint's offset set here is this client's own), and a shadow
     on the floor. ]]
local function onSkyfall(owner: Player, airborne: number)
	local root = rootOf(owner)
	local character = owner.Character
	if not root or not character then
		return
	end
	local joint: Motor6D? = nil
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") and item.Part0 == root then
			joint = item
			break
		end
	end
	local base = if joint then joint.C0 else nil
	local shadow = Voxel.cube(Vector3.new(3, 0.1, 3), Color3.fromRGB(30, 30, 40))
	shadow.Transparency = 0.5
	Voxel.run(airborne, function(t)
		local lift = math.sin(t * math.pi) * 6
		if joint and base then
			joint.C0 = base * CFrame.new(0, lift, 0)
		end
		local at = root.Position
		shadow.CFrame = CFrame.new(at.X, 0.15, at.Z)
		shadow.Size = Vector3.new(3 - lift * 0.2, 0.1, 3 - lift * 0.2)
		return nil
	end, function()
		if joint and base then
			joint.C0 = base
		end
		shadow:Destroy()
	end)
end

local function onSkyfallLand(at: Vector3)
	SoundFx.play("fx_skyfall")
	local colours: { Color3 } = {}
	for index = 0, 6 do
		table.insert(colours, Voxel.rainbow(0, index / 7))
	end
	Voxel.ring(at, 6, colours, 0.45, 0.8)
	Voxel.burst(at + Vector3.new(0, 1, 0), 10, colours, 10, 0.5, 0.45, 8)
end

--[[ Rune Circle: a ring of violet cubes with angular marks inside, flames
     licking up off it, for as long as it burns. ]]
local function onRuneCircle(at: Vector3, radius: number, duration: number)
	SoundFx.play("fx_rune_circle")
	local ring: { Part } = {}
	local count = Voxel.share(14)
	for index = 1, count do
		table.insert(ring, Voxel.cube(Vector3.new(0.5, 0.15, 0.5), VIOLET[index % 2 + 1], true))
	end
	local marksIn: { Part } = {}
	for _ = 1, 4 do
		table.insert(marksIn, Voxel.cube(Vector3.new(0.7, 0.12, 0.25), VIOLET[1], true))
	end
	local flames: { Part } = {}
	for index = 1, Voxel.share(5) do
		table.insert(flames, Voxel.cube(0.35, FLAME[index % 2 + 1], true))
	end
	local floor = Vector3.new(at.X, 0.12, at.Z)
	Voxel.run(duration, function(t)
		local fade = if t > 0.85 then (t - 0.85) / 0.15 else 0
		local spin = t * duration * 0.6
		for index, part in ring do
			local angle = index / count * math.pi * 2 + spin
			part.CFrame = CFrame.new(
				floor.X + math.cos(angle) * radius,
				floor.Y,
				floor.Z + math.sin(angle) * radius
			) * CFrame.Angles(0, -angle, 0)
			part.Transparency = 0.15 + 0.85 * fade
		end
		for index, part in marksIn do
			local angle = index / 4 * math.pi * 2 - spin
			part.CFrame = CFrame.new(
				floor.X + math.cos(angle) * radius * 0.5,
				floor.Y,
				floor.Z + math.sin(angle) * radius * 0.5
			) * CFrame.Angles(0, -angle + math.pi / 4, 0)
			part.Transparency = 0.25 + 0.75 * fade
		end
		for index, part in flames do
			local phase = (t * duration * 1.5 + index / #flames) % 1
			local angle = index / #flames * math.pi * 2 + spin
			part.CFrame = CFrame.new(
				floor.X + math.cos(angle) * radius,
				floor.Y + phase * 1.6,
				floor.Z + math.sin(angle) * radius
			)
			part.Transparency = math.max(phase, fade)
		end
		return nil
	end, function()
		for _, list in { ring, marksIn, flames } do
			for _, part in list do
				part:Destroy()
			end
		end
	end)
end

--[[ Arcane Tether: a chain of violet cubes between the two, while both
     stand and the tie holds. ]]
local function onArcaneTether(a: Model, b: Model, duration: number)
	SoundFx.play("fx_arcane_tether")
	local links: { Part } = {}
	for index = 1, Voxel.share(9) do
		table.insert(links, Voxel.cube(0.35, VIOLET[index % 2 + 1], true))
	end
	Voxel.run(duration, function(t)
		local first, second = bodyOf(a), bodyOf(b)
		if not (first and second and a.Parent and b.Parent) then
			return false
		end
		local from, to = first.Position, second.Position
		for index, part in links do
			local along = index / (#links + 1)
			local sag = math.sin(along * math.pi) * -0.6
			local wobble = math.sin(t * 30 + index) * 0.08
			part.Position = from:Lerp(to, along) + Vector3.new(0, sag + wobble, 0)
			part.Transparency = if t > 0.9 then (t - 0.9) * 10 else 0.1
		end
		return nil
	end, function()
		for _, part in links do
			part:Destroy()
		end
	end)
end

--[[ Bellow: three white rings of sound rolling out from him. ]]
local function onBellow(at: Vector3, radius: number)
	SoundFx.play("fx_bellow")
	for index = 0, 2 do
		task.delay(index * 0.08, function()
			Voxel.ring(at, radius * (0.6 + index * 0.2), SOUND, 0.35, 1.2 + index * 0.3)
		end)
	end
end

--[[ Grave Chains: a ring of iron links round each held enemy's feet. ]]
local function onGraveChains(models: { Model }, seconds: number)
	SoundFx.play("fx_grave_chains")
	for _, model in models do
		local body = bodyOf(model)
		if not body then
			continue
		end
		local half = math.max(body.Size.X, body.Size.Z) / 2 + 0.3
		local links: { Part } = {}
		for _ = 1, Voxel.share(8) do
			table.insert(links, Voxel.cube(Vector3.new(0.5, 0.3, 0.25), IRON))
		end
		Voxel.run(seconds, function(t)
			local holder = bodyOf(model)
			if not (holder and model.Parent) then
				return false
			end
			local at = holder.Position
			local rise = math.min(t * 6, 1)
			for index, part in links do
				local angle = index / #links * math.pi * 2
				part.CFrame = CFrame.new(
					at.X + math.cos(angle) * half,
					0.2 + rise * 0.6 + (index % 2) * 0.25,
					at.Z + math.sin(angle) * half
				) * CFrame.Angles(0, -angle, (index % 2) * math.pi / 2)
				part.Transparency = if t > 0.85 then (t - 0.85) / 0.15 else 0
			end
			return nil
		end, function()
			for _, part in links do
				part:Destroy()
			end
		end)
	end
end

--[[ Singularity: the great orb rolling out along the line the server's
     shot flies, at its speed, to the wall. ]]
local function onSingularity(origin: Vector3, direction: Vector3, speed: number, length: number)
	SoundFx.play("fx_singularity")
	local orb = Voxel.cube(2.6, ORB_CORE, true)
	Voxel.light(orb, VIOLET[1], 12, 3)
	local ring: { Part } = {}
	for index = 1, Voxel.share(8) do
		table.insert(ring, Voxel.cube(0.5, VIOLET[index % 2 + 1], true))
	end
	local life = length / math.max(speed, 1)
	Voxel.run(life, function(t)
		local at = origin + direction * (length * t)
		local spin = t * life * 6
		orb.CFrame = CFrame.new(at) * CFrame.Angles(spin, spin * 0.7, 0)
		orb.Color = ORB_CORE:Lerp(VIOLET[1], 0.5 + 0.5 * math.sin(spin))
		for index, part in ring do
			local angle = index / #ring * math.pi * 2 - spin * 1.5
			part.Position = at
				+ Vector3.new(
					math.cos(angle) * 2.2,
					math.sin(angle * 2) * 0.4,
					math.sin(angle) * 2.2
				)
		end
		return nil
	end, function()
		Voxel.burst(orb.Position, 8, VIOLET, 8, 0.4, 0.5, 4)
		orb:Destroy()
		for _, part in ring do
			part:Destroy()
		end
	end)
end

--[[ The attribute-driven pieces, per player. ]]
type Drawn = {
	sparks: { Part },
	orb: Part?,
	plates: { Part },
	blades: { Part },
	stoneAt: number?,
	cyclone: number,
}
local drawn: { [Player]: Drawn } = {}

local function drawnFor(player: Player): Drawn
	local existing = drawn[player]
	if existing then
		return existing
	end
	local fresh: Drawn =
		{ sparks = {}, orb = nil, plates = {}, blades = {}, stoneAt = nil, cyclone = 0 }
	drawn[player] = fresh
	return fresh
end

local function clearList(list: { Part })
	for _, part in list do
		part:Destroy()
	end
	table.clear(list)
end

local function playerStep(player: Player, clock: number, lobby: boolean)
	local root = rootOf(player)
	local own = drawnFor(player)
	local here = root ~= nil and not lobby

	-- Barrage: gold sparks over the head while the fan is ready
	if here and root and player:GetAttribute("BarrageReady") == true then
		while #own.sparks < 3 do
			table.insert(own.sparks, Voxel.cube(0.3, SPARK[#own.sparks % 2 + 1], true))
		end
		for index, part in own.sparks do
			local angle = clock * 4 + index / 3 * math.pi * 2
			part.CFrame = CFrame.new(
				root.Position + Vector3.new(math.cos(angle) * 0.8, 3.4, math.sin(angle) * 0.8)
			) * CFrame.Angles(0, angle, math.pi / 4)
		end
	elseif #own.sparks > 0 then
		clearList(own.sparks)
	end

	-- Singularity: the orb growing at the staff, full at the charge
	local from = player:GetAttribute("SingularityFrom")
	if here and root and type(from) == "number" then
		local grown = math.clamp(
			(Workspace:GetServerTimeNow() - from) / Balance.Player.singularity.charge,
			0,
			1
		)
		local orb: Part = own.orb or Voxel.cube(1, ORB_CORE, true)
		if not own.orb then
			Voxel.light(orb, VIOLET[1], 8, 2)
			own.orb = orb
		end
		local look = root.CFrame.LookVector
		local size = 0.4 + 2.2 * grown
		orb.Size = Vector3.one * size
		orb.Color = ORB_CORE:Lerp(VIOLET[1], 0.5 + 0.5 * math.sin(clock * 6))
		orb.CFrame = CFrame.new(root.Position + look * (1.8 + size / 2) + Vector3.new(0, 1, 0))
			* CFrame.Angles(clock * 2, clock * 3, 0)
	elseif own.orb then
		own.orb:Destroy()
		own.orb = nil
	end

	-- Stone Skin: grey plates round him while the guard is up; a crumble
	-- when it takes a hit
	local broke = player:GetAttribute("StoneSkinAt")
	if type(broke) == "number" and broke ~= own.stoneAt then
		local first = own.stoneAt == nil
		own.stoneAt = broke
		if not first and root and Workspace:GetServerTimeNow() - broke < 1 then
			SoundFx.play("fx_stone_skin")
			Voxel.burst(root.Position, 8, { STONE, Color3.fromRGB(110, 110, 115) }, 8, 0.5, 0.45, 6)
		end
	end
	if here and root and player:GetAttribute("StoneSkin") == true then
		while #own.plates < 4 do
			local plate = Voxel.cube(Vector3.new(1.1, 1.6, 0.3), STONE)
			plate.Transparency = 0.15
			table.insert(own.plates, plate)
		end
		for index, plate in own.plates do
			local angle = index / 4 * math.pi * 2 + clock * 0.8
			plate.CFrame = CFrame.new(
				root.Position + Vector3.new(math.cos(angle) * 1.7, 0, math.sin(angle) * 1.7)
			) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		end
	elseif #own.plates > 0 then
		clearList(own.plates)
	end

	-- Blade Cyclone: ruby blades where the server's cut
	local count = player:GetAttribute("CycloneBlades")
	local wanted = if here and type(count) == "number" then math.floor(count) else 0
	if wanted > own.cyclone and wanted > 0 then
		SoundFx.play("fx_blade_cyclone")
	end
	own.cyclone = wanted
	while #own.blades > wanted do
		(table.remove(own.blades) :: Part):Destroy()
	end
	while #own.blades < wanted do
		local blade = Voxel.cube(Vector3.new(0.35, 0.25, 1.8), RUBY, true)
		table.insert(own.blades, blade)
	end
	if root and wanted > 0 then
		local orbit = Balance.Player.bladeCyclone.orbit
		local server = Workspace:GetServerTimeNow()
		for index, blade in own.blades do
			local at =
				AssassinRules.orbit(root.Position, orbit.radius, orbit.turn, server, index, wanted)
			local out = Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z)
			local angle = math.atan2(out.Z, out.X)
			blade.CFrame = CFrame.new(at) * CFrame.Angles(0, -angle, 0)
		end
	end
end

local function step()
	local clock = os.clock()
	local lobby = Workspace:GetAttribute("InLobby") == true
	for _, player in Players:GetPlayers() do
		playerStep(player, clock, lobby)
	end
	for player, own in drawn do
		if not player.Parent then
			clearList(own.sparks)
			clearList(own.plates)
			clearList(own.blades)
			if own.orb then
				own.orb:Destroy()
			end
			drawn[player] = nil
		end
	end
	-- Hunter's Mark: each diamond over its enemy, gone with it
	for owner, mark in marks do
		local body = bodyOf(mark.model)
		if not (body and mark.model.Parent and owner.Parent) or lobby then
			mark.part:Destroy()
			marks[owner] = nil
			continue
		end
		local top = body.Position
			+ Vector3.new(0, body.Size.Y / 2 + 1.4 + math.sin(clock * 4) * 0.15, 0)
		mark.part.CFrame = CFrame.new(top) * CFrame.Angles(0, clock * 2, math.pi / 4)
	end
end

local function onEvent(kind: string, owner: Player, ...)
	local args = { ... }
	local a, b, c = args[1], args[2], args[3]
	if kind == "HuntersMark" then
		if typeof(owner) == "Instance" and owner:IsA("Player") then
			onHuntersMark(owner, if typeof(a) == "Instance" and a:IsA("Model") then a else nil)
		end
	elseif kind == "PinDown" and typeof(a) == "Vector3" then
		SoundFx.play("fx_pin_down")
		Voxel.burst(a, 5, EARTH, 6, 0.35, 0.35, 4)
	elseif kind == "SerpentBite" and typeof(a) == "Vector3" then
		SoundFx.play("fx_serpent_bite")
		Voxel.burst(a, 5, VENOM, 5, 0.35, 0.3, 4)
	elseif kind == "TrickShot" and typeof(a) == "Vector3" then
		SoundFx.play("fx_trick_shot")
		Voxel.flash(a, 2, ORANGE[1], 0.2)
		Voxel.burst(a, 5, ORANGE, 8, 0.3, 0.3, 4)
	elseif kind == "Barrage" and typeof(a) == "Vector3" then
		SoundFx.play("fx_barrage")
		Voxel.burst(a, 6, GOLD, 8, 0.3, 0.3, 4)
	elseif
		kind == "Skyfall"
		and typeof(owner) == "Instance"
		and owner:IsA("Player")
		and type(a) == "number"
	then
		onSkyfall(owner, a)
	elseif kind == "SkyfallLand" and typeof(a) == "Vector3" then
		onSkyfallLand(a)
	elseif kind == "Siphon" and typeof(a) == "Vector3" then
		SoundFx.play("fx_siphon")
		flyTo(a, function()
			local root = rootOf(owner)
			return if root then root.Position else nil
		end, RED, 6, 0.6)
	elseif kind == "Overcharge" and typeof(a) == "Vector3" then
		SoundFx.play("fx_overcharge")
		Voxel.flash(a, 2.4, RED[1], 0.2)
		Voxel.burst(a, 8, SPARK, 10, 0.35, 0.3, 6)
	elseif kind == "ManaBurn" and typeof(a) == "Vector3" then
		SoundFx.play("fx_mana_burn")
		Voxel.burst(a, 5, BLUE_FLAME, 4, 0.45, 0.35, 7)
	elseif
		kind == "RuneCircle"
		and typeof(a) == "Vector3"
		and type(b) == "number"
		and type(c) == "number"
	then
		onRuneCircle(a, b, c)
	elseif
		kind == "ArcaneTether"
		and typeof(a) == "Instance"
		and typeof(b) == "Instance"
		and type(c) == "number"
	then
		if a:IsA("Model") and b:IsA("Model") then
			onArcaneTether(a, b, c)
		end
	elseif kind == "Starfall" then
		SoundFx.play("fx_starfall")
	elseif
		kind == "Singularity"
		and typeof(a) == "Vector3"
		and typeof(b) == "Vector3"
		and type(c) == "number"
		and type(args[4]) == "number"
	then
		onSingularity(a, b, c, args[4])
	elseif kind == "Bellow" and typeof(a) == "Vector3" and type(b) == "number" then
		onBellow(a, b)
	elseif kind == "GraveChains" and type(a) == "table" and type(b) == "number" then
		local models: { Model } = {}
		for _, item in a :: { any } do
			if typeof(item) == "Instance" and item:IsA("Model") then
				table.insert(models, item)
			end
		end
		onGraveChains(models, b)
	elseif kind == "ReapersHarvest" and typeof(a) == "Vector3" then
		SoundFx.play("fx_reapers_harvest")
		flyTo(a, function()
			local root = rootOf(owner)
			return if root then root.Position else nil
		end, GHOST, 5, 0.5)
	elseif kind == "ColossusQuake" and typeof(a) == "Vector3" and type(b) == "number" then
		SoundFx.play("fx_colossus")
		TopDownCamera.shake(0.7, 0.35)
		Voxel.ring(a, b, ROCK, 0.5, 1.4)
		Voxel.burst(a + Vector3.new(0, 0.5, 0), 12, ROCK, 12, 0.7, 0.6, 10)
	end
end

function CardIdeasFx.start()
	Remotes.event(Remotes.UpgradeFx).OnClientEvent:Connect(onEvent)
	RunService.RenderStepped:Connect(step)
end

return CardIdeasFx
