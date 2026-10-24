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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local FxEvents = require(script.Parent.FxEvents)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)
local UpgradeFx = require(script.Parent.UpgradeFx)

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
	local scale = radius / K.earthbreakerRadius
	UpgradeFx.play("FxEarthbreaker", {
		at = CFrame.new(UpgradeFx.floor(origin, 0)),
		life = K.earthbreakerLife,
		scale = scale,
		motion = UpgradeFx.pop(scale, 0.3),
	})
end

function WardenFx.start()
	FxEvents.blow:connect(onBlow)
	FxEvents.slam:connect(onSlam)
end

return WardenFx
