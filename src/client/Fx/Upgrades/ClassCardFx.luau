--!strict
--[[
	The class cards of 2026-11-13 (owner's pick C, docs/CLASS-CARDS.md), drawn
	from voxel cubes as the class upgrades before them (`Fx/Upgrades/Voxel`).
	`Combat/ClassUpgrades`, `Combat/ProjectileSystem`, `Run/RunSession` and
	`Enemies/EnemyManager` decide every hit; this only draws.

	- Sniper Shot (Ranger): a gold cross glints over a player whose sniper
	  arrow is ready (`SniperReady`); the arrow itself ("Sniper" look) flies
	  gold with a long gold streak behind it.
	- Split Shot (Ranger): splinters ("Splinter" look) fly green out of a
	  green burst at the kill.
	- Wind Arrows (Ranger): this player's arrows wear a swirl of white cubes;
	  the shots they blow away vanish in a puff (`UpgradeFx` "Gust").
	- Mana Surge (Arcanist): a kill lights a blue flare round the staff hand
	  (`ManaSurge`); the next cast's orbs go out in a big blue shell.
	- Frost Orb (Arcanist): this player's plain orbs are icy; a chilled enemy
	  (`FrostUntil`, any slow from an orb) has ice cubes round its feet.
	- Arcane Shield (Arcanist): a ring of violet panels turns round the
	  player while the shield is up; a blocked hit shatters it
	  (`ArcaneShieldAt`, when it is back).
	- Shield Throw (Warden): a spinning blue-and-gold shield hops enemy to
	  enemy and flies home (`UpgradeFx` "ShieldThrow").
	- Blade Storm (Warden): a spinning sword flies out and back along the
	  swing, a red streak behind it (`UpgradeFx` "BladeStorm").
	- Sunder (Warden): a struck enemy wears red cracks over its head while
	  it takes more (`SunderedUntil`).
	Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FxEvents = require(script.Parent.FxEvents)
local ProjectileRenderer = require(script.Parent.Parent.ProjectileRenderer)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local TopDownCamera = require(script.Parent.Parent.Parent.Camera.TopDownCamera)
local UpgradeFx = require(script.Parent.UpgradeFx)
local Voxel = require(script.Parent.Voxel)

local ClassCardFx = {}

local GOLD = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(255, 240, 170) }
local GREEN = { Color3.fromRGB(120, 235, 90), Color3.fromRGB(200, 255, 160) }
local WIND = { Color3.fromRGB(245, 255, 255), Color3.fromRGB(170, 235, 230) }
local MANA = { Color3.fromRGB(80, 160, 255), Color3.fromRGB(190, 225, 255) }
local ICE = { Color3.fromRGB(190, 240, 255), Color3.fromRGB(120, 200, 255) }
local VIOLET = { Color3.fromRGB(140, 130, 255), Color3.fromRGB(205, 190, 255) }
local SHIELD_FACE = Color3.fromRGB(60, 110, 210)
local SHIELD_RIM = Color3.fromRGB(255, 200, 60)
local STEEL = Color3.fromRGB(205, 210, 220)
local RED = { Color3.fromRGB(255, 50, 50), Color3.fromRGB(255, 140, 110) }

--[[ A drawn shot that is no longer the one we followed: put back in its
     pool (no parent), or jumped (taken out again for another shot). ]]
local function gone(part: BasePart, last: Vector3): boolean
	return part.Parent == nil or (part.Position - last).Magnitude > 12
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--[[ Sniper Shot ]]

--[[ The sniper arrow: gold, with a gold streak from where it left to its
     head that lingers a moment after it stops. ]]
local function sniperArrow(part: BasePart)
	part.Color = GOLD[1]
	local start = part.Position
	local streak = Voxel.cube(Vector3.new(0.35, 0.35, 0.1), GOLD[2], true)
	Voxel.light(streak, GOLD[1], 10, 2)
	SoundFx.play("fx_sniper")
	Voxel.flash(start, 2.6, GOLD[1], 0.2)
	TopDownCamera.shake(0.12, 0.12)
	local last = part.Position
	local head = last
	Voxel.run(3, function()
		if gone(part, last) then
			return false
		end
		last = part.Position
		head = last
		local length = (head - start).Magnitude
		if length > 0.2 then
			streak.Size = Vector3.new(0.35, 0.35, length)
			streak.CFrame = CFrame.lookAt((start + head) / 2, head)
		end
		return nil
	end, function()
		Voxel.burst(head, 8, GOLD, 9, 0.4, 0.4, 4)
		local size = streak.Size
		Voxel.run(0.35, function(t)
			streak.Size = Vector3.new(size.X * (1 - t), size.Y * (1 - t), size.Z)
			streak.Transparency = t
			return nil
		end, function()
			streak:Destroy()
		end)
	end)
end

--[[ A gold cross over each player whose sniper arrow is ready. ]]
type Glint = { model: Model, player: Player }
local glints: { [Player]: Glint } = {}

local function glintStep(time: number)
	for _, player in Players:GetPlayers() do
		local ready = player:GetAttribute("SniperReady") == true
		local root = rootOf(player)
		local glint: Glint? = glints[player]
		if ready and root and not glint then
			local model = Instance.new("Model")
			model.Name = "SniperGlint"
			model.Parent = Voxel.folder()
			Voxel.cube(Vector3.new(1.3, 0.22, 0.22), GOLD[1], true, model)
			Voxel.cube(Vector3.new(0.22, 1.3, 0.22), GOLD[1], true, model)
			Voxel.cube(0.4, GOLD[2], true, model)
			glint = { model = model, player = player }
			glints[player] = glint
			Voxel.flash(root.Position + Vector3.new(0, 3.4, 0), 1.6, GOLD[1], 0.2)
		elseif (not ready or not root) and glint then
			glint.model:Destroy()
			glints[player] = nil
			glint = nil
		end
		if glint and root then
			local pulse = 1 + math.sin(time * 9) * 0.18
			local frame = CFrame.new(root.Position + Vector3.new(0, 3.4, 0))
				* CFrame.Angles(0, time * 2.5, math.rad(45))
			for _, piece in glint.model:GetChildren() do
				if piece:IsA("BasePart") then
					piece.CFrame = frame
					local base = piece:GetAttribute("Base") :: Vector3?
					if not base then
						base = piece.Size
						piece:SetAttribute("Base", base)
					end
					piece.Size = (base :: Vector3) * pulse
				end
			end
		end
	end
	for player, glint in glints do
		if not player.Parent then
			glint.model:Destroy()
			glints[player] = nil
		end
	end
end

--[[ Split Shot: a splinter is green, out of a green burst. ]]
local function splinter(part: BasePart)
	part.Color = GREEN[1]
	Voxel.burst(part.Position, 4, GREEN, 7, 0.3, 0.35, 3)
	SoundFx.play("fx_split_shot")
end

--[[ Wind Arrows ]]

--[[ Two white cubes swirling round an arrow while it flies. ]]
local function windSwirl(part: BasePart)
	local bits = { Voxel.cube(0.3, WIND[1], true), Voxel.cube(0.26, WIND[2], true) }
	local started = os.clock()
	local last = part.Position
	Voxel.run(2.5, function()
		if gone(part, last) then
			return false
		end
		last = part.Position
		local time = os.clock() - started
		local frame = part.CFrame
		for index, bit in bits do
			local angle = time * 22 + index * math.pi
			bit.CFrame = frame * CFrame.new(math.cos(angle) * 0.7, math.sin(angle) * 0.7, 0.6)
		end
		return nil
	end, function()
		for _, bit in bits do
			bit:Destroy()
		end
	end)
end

local function onGust(at: Vector3, radius: number)
	ProjectileRenderer.clearEnemyNear(at, radius)
	Voxel.burst(at, 7, WIND, 8, 0.35, 0.4, 3)
	SoundFx.play("fx_wind_gust")
end

--[[ Mana Surge ]]

--[[ A big blue shell of cubes round a surged orb, following it. ]]
local function surgeShell(part: BasePart)
	local shell = Voxel.cube(1.9, MANA[1], true)
	shell.Transparency = 0.55
	local core = Voxel.cube(1.1, MANA[2], true)
	Voxel.light(core, MANA[1], 12, 3)
	Voxel.flash(part.Position, 2.4, MANA[1], 0.2)
	local started = os.clock()
	local last = part.Position
	Voxel.run(3, function()
		if gone(part, last) then
			return false
		end
		last = part.Position
		local spin = (os.clock() - started) * 6
		shell.CFrame = CFrame.new(last) * CFrame.Angles(spin, spin * 0.7, 0)
		core.CFrame = CFrame.new(last) * CFrame.Angles(0, -spin, spin * 0.5)
		return nil
	end, function()
		Voxel.burst(last, 10, MANA, 10, 0.45, 0.45, 5)
		shell:Destroy()
		core:Destroy()
	end)
end

--[[ The flare round the staff hand while the next cast is surged. ]]
local flare: { Part }? = nil

local function flareStep(time: number)
	local player = Players.LocalPlayer
	local surged = player:GetAttribute("ManaSurge") == true and UpgradeFx.level("ManaSurge") > 0
	local root = rootOf(player)
	if surged and root and not flare then
		local bits: { Part } = {}
		for index = 1, Voxel.share(5) do
			table.insert(bits, Voxel.cube(0.35, MANA[(index % 2) + 1], true))
		end
		flare = bits
		SoundFx.play("fx_mana_surge")
		Voxel.flash(root.Position + Vector3.new(0, 1.5, 0), 2.2, MANA[1], 0.25)
	elseif (not surged or not root) and flare then
		for _, bit in flare do
			bit:Destroy()
		end
		flare = nil
	end
	local bits = flare
	if bits and root then
		local hand = root.CFrame * CFrame.new(1.2, 0.8, -0.6)
		for index, bit in bits do
			local angle = time * 7 + index / #bits * math.pi * 2
			bit.CFrame = hand
				* CFrame.new(
					math.cos(angle) * 0.8,
					math.sin(time * 5 + index) * 0.4,
					math.sin(angle) * 0.8
				)
		end
	end
end

--[[ Frost Orb: this player's plain orbs are icy, a trail of ice bits. ]]
local function frostOrb(part: BasePart)
	part.Color = ICE[2]
	local light = part:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Color = ICE[1]
	end
end

--[[ Arcane Shield ]]

local shieldRing: { Part }? = nil

local function shieldUp(): boolean
	if UpgradeFx.level("ArcaneShield") <= 0 then
		return false
	end
	local back = Players.LocalPlayer:GetAttribute("ArcaneShieldAt")
	return type(back) ~= "number" or Workspace:GetServerTimeNow() >= back
end

local function shieldStep(time: number)
	local up = shieldUp()
	local root = rootOf(Players.LocalPlayer)
	if up and root and not shieldRing then
		local panels: { Part } = {}
		for index = 1, Voxel.share(8) do
			local panel = Voxel.cube(Vector3.new(0.9, 1.1, 0.15), VIOLET[(index % 2) + 1], true)
			panel.Transparency = 0.35
			table.insert(panels, panel)
		end
		shieldRing = panels
		Voxel.flash(root.Position, 3, VIOLET[1], 0.25)
	elseif (not up or not root) and shieldRing then
		for _, panel in shieldRing do
			panel:Destroy()
		end
		shieldRing = nil
	end
	local panels = shieldRing
	if panels and root then
		local centre = root.Position
		for index, panel in panels do
			local angle = time * 1.6 + index / #panels * math.pi * 2
			local at = centre
				+ Vector3.new(
					math.cos(angle) * 2.3,
					math.sin(time * 3 + index) * 0.15,
					math.sin(angle) * 2.3
				)
			panel.CFrame = CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z))
		end
	end
end

local function onShieldSpent()
	if UpgradeFx.level("ArcaneShield") <= 0 then
		return
	end
	local root = rootOf(Players.LocalPlayer)
	if not root then
		return
	end
	SoundFx.play("fx_arcane_shield")
	Voxel.burst(root.Position, 14, VIOLET, 12, 0.5, 0.5, 5)
	Voxel.flash(root.Position, 3.5, VIOLET[2], 0.2)
end

--[[ Shield Throw ]]

local function buildShield(): Model
	local model = Instance.new("Model")
	model.Name = "ThrownShield"
	model.Parent = Voxel.folder()
	local face = Voxel.cube(Vector3.new(1.8, 0.3, 1.8), SHIELD_FACE, false, model)
	face:SetAttribute("Offset", CFrame.new())
	local boss = Voxel.cube(Vector3.new(0.6, 0.45, 0.6), SHIELD_RIM, true, model)
	boss:SetAttribute("Offset", CFrame.new(0, 0.12, 0))
	for side = 0, 3 do
		local rim = Voxel.cube(Vector3.new(2.1, 0.38, 0.32), SHIELD_RIM, true, model)
		rim:SetAttribute(
			"Offset",
			CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0.02, 1.0)
		)
	end
	return model
end

local function poseModel(model: Model, frame: CFrame)
	for _, piece in model:GetChildren() do
		if piece:IsA("BasePart") then
			piece.CFrame = frame * ((piece:GetAttribute("Offset") :: CFrame?) or CFrame.new())
		end
	end
end

local function onShieldThrow(
	owner: Player,
	start: Vector3,
	points: { Vector3 },
	times: { number },
	speed: number
)
	local model = buildShield()
	SoundFx.play("fx_shield_throw")
	local height = 1.6
	local route = { Vector3.new(start.X, height, start.Z) }
	for _, point in points do
		table.insert(route, Vector3.new(point.X, height, point.Z))
	end
	local arrivals = { 0 }
	for _, at in times do
		table.insert(arrivals, at)
	end
	local reached = 1
	local started = os.clock()
	Voxel.run(math.huge, function()
		local elapsed = os.clock() - started
		local spin = CFrame.Angles(0, elapsed * 20, 0)
		-- hopping between the enemies, each hop landing as the server's
		while reached < #route and elapsed >= arrivals[reached + 1] do
			reached += 1
			Voxel.flash(route[reached], 1.8, SHIELD_RIM, 0.15)
			Voxel.burst(route[reached], 5, { SHIELD_RIM, SHIELD_FACE }, 8, 0.35, 0.4, 4)
		end
		if reached < #route then
			local a, b = route[reached], route[reached + 1]
			local span = math.max(arrivals[reached + 1] - arrivals[reached], 1e-3)
			local t = math.clamp((elapsed - arrivals[reached]) / span, 0, 1)
			poseModel(model, CFrame.new(a:Lerp(b, t)) * spin)
			return nil
		end
		-- then home, to wherever its owner is now
		local root = rootOf(owner)
		local last = route[#route]
		local home = if root then Vector3.new(root.Position.X, height, root.Position.Z) else last
		local back = (home - last).Magnitude / speed
		local t = if back > 0 then (elapsed - arrivals[#arrivals]) / back else 1
		if t >= 1 then
			return false
		end
		poseModel(model, CFrame.new(last:Lerp(home, t)) * spin)
		return nil
	end, function()
		model:Destroy()
	end)
end

--[[ Blade Storm ]]

local function buildBlade(): Model
	local model = Instance.new("Model")
	model.Name = "StormBlade"
	model.Parent = Voxel.folder()
	local blade = Voxel.cube(Vector3.new(0.55, 0.22, 4.2), STEEL, false, model)
	blade:SetAttribute("Offset", CFrame.new(0, 0, -1.2))
	local edge =
		Voxel.cube(Vector3.new(0.18, 0.24, 4.0), Color3.fromRGB(255, 255, 255), true, model)
	edge:SetAttribute("Offset", CFrame.new(0.2, 0, -1.2))
	local guard = Voxel.cube(Vector3.new(1.5, 0.3, 0.3), RED[1], true, model)
	guard:SetAttribute("Offset", CFrame.new(0, 0, 1.0))
	local grip = Voxel.cube(Vector3.new(0.3, 0.3, 1.0), Color3.fromRGB(110, 40, 30), false, model)
	grip:SetAttribute("Offset", CFrame.new(0, 0, 1.6))
	return model
end

local function onBladeStorm(origin: Vector3, direction: Vector3, length: number, duration: number)
	local model = buildBlade()
	SoundFx.play("fx_blade_storm")
	local height = 1.6
	local started = os.clock()
	local lastDrop = 0
	Voxel.run(duration, function(t)
		local elapsed = os.clock() - started
		local along = length * math.sin(math.pi * t)
		local at = Vector3.new(origin.X, height, origin.Z) + direction * along
		poseModel(model, CFrame.new(at) * CFrame.Angles(0, elapsed * 26, 0))
		-- a red streak of cubes left behind, fading
		if elapsed - lastDrop >= 0.03 then
			lastDrop = elapsed
			local bit = Voxel.cube(0.45, RED[(math.floor(elapsed * 30) % 2) + 1], true)
			bit.CFrame = CFrame.new(at) * CFrame.Angles(0, elapsed * 10, 0)
			Voxel.run(0.3, function(f)
				bit.Size = Vector3.one * 0.45 * (1 - f)
				bit.Transparency = f
				return nil
			end, function()
				bit:Destroy()
			end)
		end
		return nil
	end, function()
		Voxel.burst(Vector3.new(origin.X, height, origin.Z), 6, RED, 6, 0.3, 0.35, 3)
		model:Destroy()
	end)
end

--[[ Marks on enemies: ice round a chilled one's feet, red cracks over a
     sundered one. Polled, as `Fx/RootHoldFx` polls its roots. ]]
type Mark = { parts: { Part }, untilTime: number }
local frosts: { [Model]: Mark } = {}
local sunders: { [Model]: Mark } = {}

local function clearMark(marks: { [Model]: Mark }, model: Model)
	local mark = marks[model]
	if mark then
		for _, part in mark.parts do
			part:Destroy()
		end
		marks[model] = nil
	end
end

local function makeMark(count: number, colours: { Color3 }, size: Vector3): { Part }
	local parts: { Part } = {}
	for index = 1, Voxel.share(count) do
		table.insert(parts, Voxel.cube(size, colours[(index % #colours) + 1], true))
	end
	return parts
end

local function pollMarks()
	local now = Workspace:GetServerTimeNow()
	local enemies = Workspace:FindFirstChild("Enemies")
	for _, marks in { frosts, sunders } do
		for model, mark in marks do
			if not model.Parent or now >= mark.untilTime then
				clearMark(marks, model)
			end
		end
	end
	if not enemies then
		return
	end
	for _, model in enemies:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local frost = model:GetAttribute("FrostUntil")
		if type(frost) == "number" and frost > now then
			local mark = frosts[model]
			if mark then
				mark.untilTime = frost
			else
				frosts[model] = {
					parts = makeMark(6, ICE, Vector3.new(0.5, 0.7, 0.5)),
					untilTime = frost,
				}
			end
		end
		local sunder = model:GetAttribute("SunderedUntil")
		if type(sunder) == "number" and sunder > now then
			local mark = sunders[model]
			if mark then
				mark.untilTime = sunder
			else
				sunders[model] = {
					parts = makeMark(3, RED, Vector3.new(0.25, 0.9, 0.25)),
					untilTime = sunder,
				}
			end
		end
	end
end

local function marksStep(time: number)
	for model, mark in frosts do
		local body = model.PrimaryPart
		if not body then
			continue
		end
		local centre = body.Position
		local radius = math.max(body.Size.X, body.Size.Z) / 2 + 0.3
		for index, part in mark.parts do
			local angle = index / #mark.parts * math.pi * 2 + time * 0.6
			part.CFrame = CFrame.new(
				centre.X + math.cos(angle) * radius,
				0.35,
				centre.Z + math.sin(angle) * radius
			) * CFrame.Angles(0.3, angle, 0.2)
		end
	end
	for model, mark in sunders do
		local body = model.PrimaryPart
		if not body then
			continue
		end
		local top = body.Position + Vector3.new(0, body.Size.Y / 2 + 1, 0)
		local pulse = 0.8 + math.sin(time * 10) * 0.2
		for index, part in mark.parts do
			-- a jagged crack: three bars leaning alternately
			local lean = if index % 2 == 0 then -0.6 else 0.6
			part.CFrame = CFrame.new(top + Vector3.new((index - 2) * 0.32, (index % 2) * 0.15, 0))
				* CFrame.Angles(0, 0, lean)
			part.Transparency = 1 - pulse
		end
	end
end

--[[ A drawn shot left: dress it if it is one of these cards'. ]]
local function onLaunched(part: BasePart, pool: string, _aim: Vector3, from: Model?, look: string?)
	if look == "Sniper" then
		sniperArrow(part)
		return
	end
	if look == "Splinter" then
		splinter(part)
		return
	end
	if from ~= nil then
		return
	end
	if pool == "Player" and look == "Arrow" and UpgradeFx.level("WindArrows") > 0 then
		windSwirl(part)
	elseif pool == "PlayerOrb" and look == "Orb" then
		if
			Players.LocalPlayer:GetAttribute("ManaSurge") == true
			and UpgradeFx.level("ManaSurge") > 0
		then
			surgeShell(part)
		end
		if
			UpgradeFx.level("FrostOrb") > 0
			and Players.LocalPlayer:GetAttribute("OrbElement") == nil
		then
			frostOrb(part)
		end
	end
end

function ClassCardFx.start()
	FxEvents.launched:connect(onLaunched)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, owner: Player, ...)
			local args = { ... }
			if kind == "Gust" then
				onGust(args[1], args[2])
			elseif kind == "ShieldThrow" then
				onShieldThrow(owner, args[1], args[2], args[3], args[4])
			elseif kind == "BladeStorm" then
				onBladeStorm(args[1], args[2], args[3], args[4])
			end
		end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("ArcaneShieldAt"):Connect(onShieldSpent)
	local sinceLastPoll = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		local time = os.clock()
		sinceLastPoll += deltaTime
		if sinceLastPoll >= 0.1 then
			sinceLastPoll = 0
			pollMarks()
		end
		glintStep(time)
		flareStep(time)
		shieldStep(time)
		marksStep(time)
	end)
end

return ClassCardFx
