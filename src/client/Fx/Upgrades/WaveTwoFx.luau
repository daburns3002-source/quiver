--!strict
--[[
	What wave 2's last five class cards look like (`Config/Abilities`,
	docs/CLASS-CARDS.md, 2026-11-26; the server's side is
	`Combat/MeleeSystem`, `Combat/ProjectileSystem` and
	`Combat/ClassUpgrades`). The client only draws, in voxel cubes like the
	rest.

	- Echo Slash: the `EchoSlash` event, the blow's own shape: a pale cyan
	  copy of the slash sweeps through it a moment after the real one.
	- Riposte: a shot thrown back ("Riposte" look) flies gold, with a gold
	  flash where the sword caught it.
	- Split Orb: the shards ("Shard" look) fly violet out of the hit, with a
	  puff of crystal.
	- Gravity Well: the `GravityWell` event, where the blast was and how far
	  it pulls: a ring of violet cubes spiralling in to a dark core.
	- Orbiting Orb: `OrbitingOrbs` on a player is how many orbs circle them,
	  drawn where the server's are (`AssassinRules.orbit`, on the clock
	  every client shares, as Phantom Blades are).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local Voxel = require(script.Parent.Voxel)

local WaveTwoFx = {}

local ECHO = { Color3.fromRGB(170, 240, 255), Color3.fromRGB(235, 252, 255) }
local GOLD = { Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 244, 190) }
local SHARD = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 160, 230) }
local WELL = { Color3.fromRGB(120, 60, 200), Color3.fromRGB(190, 120, 255) }
local CORE = Color3.fromRGB(40, 10, 70)
local ORB = Color3.fromRGB(176, 110, 255)

--[[ Echo Slash: the blow again, ghostly. An arc's cubes sweep across it
     from one side to the other; a slam's ring rolls out. ]]
local function onEchoSlash(
	from: Vector3,
	direction: Vector3,
	kind: string,
	size: number,
	extra: number,
	delay: number
)
	task.delay(delay, function()
		SoundFx.play("fx_echo_slash")
		if kind == "Circle" then
			local centre = from + direction * extra
			Voxel.ring(Vector3.new(centre.X, 0, centre.Z), size, ECHO, 0.3, 1.2)
			return
		end
		local heading = math.atan2(direction.Z, direction.X)
		local half = math.rad(extra) / 2
		local count = Voxel.share(14)
		local parts: { Part } = {}
		for index = 1, count do
			local part = Voxel.cube(0.55, ECHO[index % 2 + 1], true)
			part.Transparency = 1
			table.insert(parts, part)
		end
		local height = from.Y
		Voxel.run(0.26, function(t)
			for index, part in parts do
				local along = (index - 1) / math.max(count - 1, 1)
				-- the cubes light up in turn as the ghost blade passes them
				local shown = math.clamp((t * 1.6 - along * 0.6) * 2, 0, 1)
				local angle = heading - half + along * half * 2
				local reach = size * (0.55 + 0.45 * math.sin(along * math.pi))
				part.CFrame = CFrame.new(
					from.X + math.cos(angle) * reach,
					height,
					from.Z + math.sin(angle) * reach
				) * CFrame.Angles(0, -angle, 0)
				part.Transparency = if shown <= 0 then 1 else 0.2 + 0.8 * t
			end
			return nil
		end, function()
			for _, part in parts do
				part:Destroy()
			end
		end)
	end)
end

--[[ Gravity Well: cubes round the blast's edge spiral in to its middle. ]]
local function onGravityWell(at: Vector3, radius: number, duration: number)
	SoundFx.play("fx_gravity_well")
	local count = Voxel.share(16)
	local parts: { Part } = {}
	for index = 1, count do
		table.insert(parts, Voxel.cube(0.6, WELL[index % 2 + 1], true))
	end
	local floor = Vector3.new(at.X, 0.8, at.Z)
	Voxel.flash(floor, 2.2, CORE, duration + 0.15)
	Voxel.run(duration + 0.1, function(t)
		local ease = t * t
		for index, part in parts do
			local angle = index / count * math.pi * 2 + t * 2.4
			local r = radius * (1 - ease) + 0.4
			part.CFrame = CFrame.new(
				floor.X + math.cos(angle) * r,
				floor.Y + math.sin(t * math.pi) * 0.5,
				floor.Z + math.sin(angle) * r
			) * CFrame.Angles(0, -angle, 0)
			part.Size = Vector3.one * (0.7 - 0.35 * t)
			part.Transparency = 0.1 + 0.6 * t
		end
		return nil
	end, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
end

--[[ A drawn shot left: a thrown-back shot or a shard. ]]
local function onLaunched(
	part: BasePart,
	_pool: string,
	_aim: Vector3,
	_from: Model?,
	look: string?
)
	if look == "Riposte" then
		part.Color = GOLD[1]
		Voxel.flash(part.Position, 2.4, GOLD[1], 0.22)
		Voxel.burst(part.Position, 6, GOLD, 9, 0.3, 0.35, 3)
		SoundFx.play("fx_riposte")
	elseif look == "Shard" then
		part.Color = SHARD[1]
		Voxel.burst(part.Position, 3, SHARD, 7, 0.3, 0.3, 3)
		SoundFx.play("fx_split_orb")
	end
end

--[[ Orbiting Orb: every player's orbs, where the server's are. ]]
local orbits: { [Player]: { Part } } = {}

local function orbitsStep()
	local config = Balance.Player.waveTwo.orbit
	local clock = Workspace:GetServerTimeNow()
	local lobby = Workspace:GetAttribute("InLobby") == true
	for _, player in Players:GetPlayers() do
		local count = player:GetAttribute("OrbitingOrbs")
		local wanted = if type(count) == "number" and not lobby then math.floor(count) else 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			wanted = 0
		end
		local orbs = orbits[player]
		if not orbs and wanted > 0 then
			orbs = {}
			orbits[player] = orbs
		end
		if not orbs then
			continue
		end
		while #orbs > wanted do
			(table.remove(orbs) :: Part):Destroy()
		end
		while #orbs < wanted do
			local orb = Voxel.cube(1.1, ORB, true)
			Voxel.light(orb, ORB, 7, 1.6)
			table.insert(orbs, orb)
		end
		if root then
			for index, orb in orbs do
				local at = AssassinRules.orbit(
					root.Position,
					config.radius,
					config.turn,
					clock,
					index,
					wanted
				)
				-- a cube that tumbles as it goes round
				orb.CFrame = CFrame.new(at) * CFrame.Angles(clock * 3, clock * 4, 0)
			end
		end
		if wanted == 0 then
			orbits[player] = nil
		end
	end
	for player, orbs in orbits do
		if not player.Parent then
			for _, orb in orbs do
				orb:Destroy()
			end
			orbits[player] = nil
		end
	end
end

function WaveTwoFx.start()
	FxEvents.launched:connect(onLaunched)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			local args = { ... }
			if kind == "EchoSlash" then
				local from, direction, shape, size, extra, delay =
					args[1], args[2], args[3], args[4], args[5], args[6]
				if
					typeof(from) == "Vector3"
					and typeof(direction) == "Vector3"
					and type(shape) == "string"
					and type(size) == "number"
					and type(extra) == "number"
					and type(delay) == "number"
				then
					onEchoSlash(from, direction, shape, size, extra, delay)
				end
			elseif kind == "GravityWell" then
				local at, radius, duration = args[1], args[2], args[3]
				if
					typeof(at) == "Vector3"
					and type(radius) == "number"
					and type(duration) == "number"
				then
					onGravityWell(at, radius, duration)
				end
			end
		end)
	RunService.RenderStepped:Connect(orbitsStep)
end

return WaveTwoFx
