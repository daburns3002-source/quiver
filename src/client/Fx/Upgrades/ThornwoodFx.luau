--!strict
--[[
	What Thornwood's six cards look like (`Config/Abilities`, 2026-11-18;
	the server's side is `Combat/ClassUpgrades.dress`, `ProjectileSystem`
	and `MeleeSystem`). The client only draws.

	- Thorn Burst: the `ThornBurst` event, where the burst landed and how
	  wide: cream thorns thrown out in a ring over the blast.
	- Boar Rush: the `BoarRush` event, where the slam landed: a ring of
	  dust rolling out along the floor.
	- Web Snare: an enemy with `WebbedUntil` (server time) ahead of now
	  wears strands of silk until it passes.
	- Burr Blight: an enemy with `BlightedUntil` ahead of now has burrs of
	  poison bobbing over it.

	Root Hold's roots are `Fx/RootHoldFx`'s (the enemy is held as a pet's
	root holds it), and Ruin Cracks' are Sunder's (`ClassCardFx`,
	`SunderedUntil`): the same state, so the same picture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local Voxel = require(script.Parent.Voxel)

local ThornwoodFx = {}

local CREAM = Color3.fromRGB(240, 226, 180)
local PLUM = Color3.fromRGB(170, 60, 130)
local HEDGE = Color3.fromRGB(110, 160, 70)
local DUST = Color3.fromRGB(196, 170, 130)
local BARK = Color3.fromRGB(120, 84, 56)
local SILK = Color3.fromRGB(244, 240, 250)
local BLIGHT = { Color3.fromRGB(150, 220, 70), Color3.fromRGB(90, 160, 50) }

--[[ Seconds between looks at the enemies for a web or a blight. ]]
local POLL = 0.1

--[[ Thorn Burst: thorns out in a ring, a puff of plum in the middle. ]]
local function onThornBurst(at: Vector3, radius: number)
	local over = Vector3.new(at.X, at.Y + 1.2, at.Z)
	Voxel.flash(over, radius * 0.6, PLUM, 0.2)
	Voxel.burst(over, 10, { CREAM, CREAM, HEDGE }, radius * 1.5, 0.35, 0.32, 3)
	local count = Voxel.share(8)
	local thorns: { { part: Part, way: Vector3 } } = {}
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local way = Vector3.new(math.cos(angle), 0, math.sin(angle))
		table.insert(thorns, {
			part = Voxel.cube(Vector3.new(0.3, 0.3, 1.1), CREAM, true),
			way = way,
		})
	end
	Voxel.run(0.28, function(t)
		for _, thorn in thorns do
			local out = over + thorn.way * (radius * (0.25 + 0.75 * t))
			thorn.part.CFrame = CFrame.lookAt(out, out + thorn.way)
			thorn.part.Transparency = t * t
		end
		return nil
	end, function()
		for _, thorn in thorns do
			thorn.part:Destroy()
		end
	end)
	SoundFx.play("fx_thorn_burst")
end

--[[ Boar Rush: the slam's dust, rolling out. ]]
local function onBoarRush(at: Vector3, radius: number)
	local floor = Vector3.new(at.X, at.Y - 2.4, at.Z)
	Voxel.ring(floor, radius, { DUST, BARK }, 0.35, 0.5)
	Voxel.ring(floor, radius * 1.6, { DUST, CREAM }, 0.5, 0.3)
	SoundFx.play("fx_boar_rush")
end

type Worn = { parts: { Part }, untilTime: number, height: number, half: number }

local webs: { [Model]: Worn } = {}
local blights: { [Model]: Worn } = {}

local function drop(list: { [Model]: Worn }, model: Model)
	local worn = list[model]
	if worn then
		for _, part in worn.parts do
			part:Destroy()
		end
		list[model] = nil
	end
end

local function sized(model: Model): (number, number)
	local size = model:GetExtentsSize()
	return size.Y, math.max(size.X, size.Z) / 2
end

local function poll()
	local now = Workspace:GetServerTimeNow()
	for model, worn in webs do
		if not model.Parent or now >= worn.untilTime then
			drop(webs, model)
		end
	end
	for model, worn in blights do
		if not model.Parent or now >= worn.untilTime then
			drop(blights, model)
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end
	for _, model in enemies:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local webbed = model:GetAttribute("WebbedUntil")
		if type(webbed) == "number" and webbed > now then
			local worn = webs[model]
			if worn then
				worn.untilTime = webbed
			else
				local height, half = sized(model)
				local parts = {}
				--[[ Four strands across it, two each way. ]]
				for _ = 1, 4 do
					table.insert(parts, Voxel.cube(Vector3.new(0.12, 0.12, half * 2.6), SILK, true))
				end
				webs[model] = { parts = parts, untilTime = webbed, height = height, half = half }
			end
		end
		local blighted = model:GetAttribute("BlightedUntil")
		if type(blighted) == "number" and blighted > now then
			local worn = blights[model]
			if worn then
				worn.untilTime = blighted
			else
				local height, half = sized(model)
				local parts = {}
				for index = 1, 3 do
					table.insert(parts, Voxel.cube(0.34, BLIGHT[index % 2 + 1], true))
				end
				blights[model] =
					{ parts = parts, untilTime = blighted, height = height, half = half }
			end
		end
	end
end

local function step(time: number)
	for model, worn in webs do
		if not model.Parent then
			continue
		end
		local base = model:GetPivot().Position
		for index, part in worn.parts do
			local turn = (index - 1) * math.pi / 4
			local lift = worn.height * (0.3 + 0.15 * (index % 2))
			part.CFrame = CFrame.new(base + Vector3.new(0, lift - worn.height / 2, 0))
				* CFrame.Angles(0, turn, 0)
				* CFrame.Angles(math.rad(18 * (if index % 2 == 0 then 1 else -1)), 0, 0)
		end
	end
	for model, worn in blights do
		if not model.Parent then
			continue
		end
		local base = model:GetPivot().Position
		for index, part in worn.parts do
			local angle = time * 2.4 + index * math.pi * 2 / #worn.parts
			local bob = math.sin(time * 5 + index) * 0.25
			part.CFrame = CFrame.new(
				base
					+ Vector3.new(
						math.cos(angle) * (worn.half + 0.5),
						worn.height / 2 + 0.6 + bob,
						math.sin(angle) * (worn.half + 0.5)
					)
			)
		end
	end
end

function ThornwoodFx.start()
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, a: unknown, b: unknown)
			if typeof(a) ~= "Vector3" or type(b) ~= "number" then
				return
			end
			if kind == "ThornBurst" then
				onThornBurst(a, b)
			elseif kind == "BoarRush" then
				onBoarRush(a, b)
			end
		end)
	local sinceLastPoll = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		sinceLastPoll += deltaTime
		if sinceLastPoll >= POLL then
			sinceLastPoll = 0
			poll()
		end
		step(os.clock())
	end)
end

return ThornwoodFx
