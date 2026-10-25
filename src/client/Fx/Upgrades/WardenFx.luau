--!strict
--[[
	The Warden's upgrades with an effect (docs/effects/warden-blade.md,
	warden-guard.md). The red streak `Fx/SwingTrail` draws is already grown by
	Cleave and Long Reach; these extend it, never redraw it. Quick Hands, Iron
	Skin, Long Reach, Steadfast and Execute had effects too; the owner cut
	them as clutter (2026-10-24).

	- Cleave: the crescent of ground a side blow covers, left for a moment.
	- Heavy Blade: the slam's gold starburst.
	- Bloodletting: life drawn from the struck enemy into the Warden.
	- Earthbreaker: the slam's torn sod and stone.
	- Whirlwind: a ring of blade-coloured cubes whirling once round the
	  Warden as the spin lands, with its sound.
	- Shockwave: earth cubes bursting up one after another down the slam's
	  lane, at the wave's own pace, with its sound.
	- Battle Cry: its sound on every kill that adds a stack.
	- Parry: no effect of its own; the parried shots simply stop being drawn.

	Whirlwind and Shockwave are built here in cubes, as the bosses' effects
	are (owner, 2026-10-25: "a quick animation and sound"), a dozen parts at
	most, so they cost a phone nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local FxEvents = require(script.Parent.FxEvents)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)
local ProjectileRenderer = require(script.Parent.Parent.ProjectileRenderer)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local K = Balance.UpgradeFx

local WardenFx = {}

local function reach(): number
	local class = Classes[UpgradeFx.class()]
	local box = class and class.swing
	return (if box then box.reach else 4) + PlayerStats.get().reachBonus
end

local function facing(): (BasePart?, Vector3)
	local root = UpgradeFx.root()
	return root, if root then UpgradeFx.flat(root.CFrame.LookVector) else Vector3.new(0, 0, -1)
end

local function onBlow(index: number, blows: number, heavy: boolean)
	local root, look = facing()
	if not root then
		return
	end
	local class = Classes[UpgradeFx.class()]
	local slamAhead = if class and class.swing then class.swing.slamAhead else 5
	local ahead = UpgradeFx.floor(root.Position, 0) + look * slamAhead
	if heavy and UpgradeFx.level("HeavyBlade") > 0 then
		SoundFx.play("fx_heavy_blade")
		UpgradeFx.play("FxHeavyBlade", {
			at = CFrame.lookAt(ahead, ahead + look),
			life = K.slamLife,
			motion = UpgradeFx.pop(1, 0.2),
		})
	end
	if index < blows and UpgradeFx.level("Cleave") > 0 then
		local at = UpgradeFx.floor(root.Position)
		UpgradeFx.play("FxCleave", {
			at = CFrame.lookAt(at, at + look),
			life = K.cleaveLife,
			motion = UpgradeFx.pop(PlayerStats.get().widthScale, 0.12),
		})
	end
	if UpgradeFx.level("Bloodletting") > 0 then
		-- from the enemy struck, nearest in front within reach
		local enemies = Workspace:FindFirstChild("Enemies")
		local struck: Vector3? = nil
		local best = math.huge
		if enemies then
			for _, enemy in enemies:GetChildren() do
				if enemy:IsA("Model") then
					local offset = enemy:GetPivot().Position - root.Position
					local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
					if d <= reach() + 1 and d < best then
						best, struck = d, enemy:GetPivot().Position
					end
				end
			end
		end
		if struck then
			SoundFx.play("fx_bloodletting")
			local toward = UpgradeFx.flat(struck - root.Position)
			-- the model's heart is at its -X end, the burst at +X
			local chest = root.Position + Vector3.new(0, K.chest, 0)
			local scale = math.clamp(best / K.drainLength, 0.4, 1.2)
			UpgradeFx.play("FxBloodletting", {
				at = CFrame.lookAt(chest, chest + toward)
					* CFrame.Angles(0, math.rad(90), 0)
					* CFrame.new(K.drainHeart * scale, 0, 0),
				life = K.drainLife,
				scale = scale,
				motion = UpgradeFx.pop(scale, 0.15),
			})
		end
	end
end

local function onSlam(origin: Vector3, radius: number)
	if UpgradeFx.level("Earthbreaker") <= 0 then
		return
	end
	SoundFx.play("fx_earthbreaker")
	local scale = radius / K.earthbreakerRadius
	UpgradeFx.play("FxEarthbreaker", {
		at = CFrame.new(UpgradeFx.floor(origin, 0)),
		life = K.earthbreakerLife,
		scale = scale,
		motion = UpgradeFx.pop(scale, 0.3),
	})
end

--[[ A handful of cubes animated for `life` seconds, then removed: `pose`
     places each one every frame, given its index and 0..1 through. ]]
local function cubes(
	count: number,
	size: number,
	colours: { Color3 },
	life: number,
	pose: (index: number, t: number, part: BasePart) -> ()
)
	local folder = Instance.new("Folder")
	folder.Name = "WardenCubes"
	local parts: { BasePart } = {}
	for index = 1, count do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.new(size, size, size)
		part.Color = colours[(index - 1) % #colours + 1]
		part.Transparency = 1
		part.Parent = folder
		parts[index] = part
	end
	folder.Parent = Workspace
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / life
		if t >= 1 then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		for index, part in parts do
			pose(index, t, part)
		end
	end)
end

--[[ Whirlwind: the blade's colours whirled once round the Warden. ]]
local function onSpin()
	local root = UpgradeFx.root()
	if not root then
		return
	end
	SoundFx.play("fx_whirlwind")
	local class = Classes[UpgradeFx.class()]
	local weapon = class and (Weapons :: any)[class.weapon]
	local trail = weapon and weapon.swingTrail
	local glow: Color3? = weapon and weapon.trailGlow
	-- a Legendary's or Mythic's ring is its blade's glow, a Mythic's a rainbow
	local colours = if glow and weapon.rainbow
		then {
			Color3.fromHSV(0, 0.7, 1),
			Color3.fromHSV(0.33, 0.7, 1),
			Color3.fromHSV(0.66, 0.7, 1),
		}
		elseif glow then { glow }
		elseif trail then trail.colour
		else { Color3.fromRGB(255, 214, 150) }
	local radius = Balance.Player.whirlwind.radius * PlayerStats.get().widthScale
	local count = 12
	cubes(count, 0.9, colours, K.whirlwindLife, function(index, t, part)
		local centre = UpgradeFx.root()
		if not centre then
			return
		end
		local ease = 1 - (1 - t) ^ 2
		local angle = (index / count) * math.pi * 2 + ease * math.pi * 2
		local r = radius * (0.55 + 0.45 * ease)
		local at = UpgradeFx.floor(centre.Position, 1.2)
			+ Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		part.CFrame = CFrame.new(at) * CFrame.Angles(0, -angle, math.rad(45))
		part.Transparency = math.clamp((t - 0.6) / 0.4, 0, 1)
	end)
end

--[[ Shockwave: earth bursting up down the lane as the wave passes. ]]
local function onWave(look: Vector3, from: Vector3)
	local level = UpgradeFx.level("Shockwave")
	if level <= 0 then
		return
	end
	SoundFx.play("fx_shockwave")
	local levels = Abilities.byId.Shockwave.levels
	local length = levels[math.min(level, #levels)]
	local wave = Balance.Player.shockwave
	local class = Classes[UpgradeFx.class()]
	local ahead = (if class and class.swing then class.swing.slamAhead else 5)
		+ PlayerStats.get().reachBonus
	local step = 2
	local count = math.max(1, math.floor(length / step))
	local across = Vector3.new(-look.Z, 0, look.X)
	local life = (ahead + length) / wave.speed + K.shockwaveRise
	local colours =
		{ Color3.fromRGB(122, 86, 52), Color3.fromRGB(146, 140, 132), Color3.fromRGB(98, 70, 44) }
	cubes(count * 2, 1.1, colours, life, function(index, t, part)
		local row = math.ceil(index / 2)
		local side = if index % 2 == 0 then 1 else -1
		local distance = ahead + row * step
		local arrive = distance / wave.speed / life
		local rise = K.shockwaveRise / life
		local local01 = (t - arrive) / rise
		if local01 < 0 or local01 > 1 then
			part.Transparency = 1
			return
		end
		local lift = math.sin(local01 * math.pi) * 1.4 - 0.5
		local at = UpgradeFx.floor(from, lift) + look * distance + across * side * (wave.width / 4)
		part.CFrame = CFrame.new(at) * CFrame.Angles(row * 0.7, row * 1.3, side * 0.4)
		part.Transparency = 0
	end)
end

function WardenFx.start()
	FxEvents.blow:connect(onBlow)
	FxEvents.slam:connect(onSlam)
	FxEvents.blow:connect(function(_index: number, _blows: number, heavy: boolean)
		local root, look = facing()
		if heavy and root then
			onWave(look, root.Position)
		end
	end)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("WhirlwindAt"):Connect(onSpin)
	player:GetAttributeChangedSignal("BattleCry"):Connect(function()
		SoundFx.play("fx_battle_cry")
	end)
	--[[ Parry: shots the server knocked out of the air stop being drawn. ]]
	Remotes.event(Remotes.ShotsParried).OnClientEvent
		:Connect(function(centre: Vector3, radius: number)
			ProjectileRenderer.clearEnemyNear(centre, radius)
		end)
end

return WardenFx
