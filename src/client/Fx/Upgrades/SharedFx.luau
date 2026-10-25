--!strict
--[[
	The shared combat upgrades with an effect (docs/effects/shared-combat.md),
	each anchored to the enemy, the impact or the player's body, never to a
	weapon, so one effect serves the bow, the staff and the sword. Strength,
	Precision and Momentum had effects too; the owner cut them as clutter
	(2026-10-24).

	- Deadly Strike: a skull snaps up where a crit lands, then breaks.
	- Blaze: an ember tuft on every burning enemy, beside `BurnFx`'s flames.
	- Agility: an after-image left behind by a dodge.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local SharedFx = {}

local function onEnemyHit(_model: Model, _amount: number, position: Vector3, kind: string)
	--[[ Blaze's sound on every tick of a burn, which the server sends as a
	     hit of its own (owner, 2026-10-24: "the blaze sound effect happens on
	     each tick of burn not just the first one"); `minGap` keeps several
	     burning enemies from stacking it. ]]
	if kind == "Burn" and UpgradeFx.level("Blaze") > 0 then
		SoundFx.play("fx_blaze")
		return
	end
	if kind ~= "Crit" or UpgradeFx.level("DeadlyStrike") <= 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local at = position + Vector3.new(0, K.critLift, 0)
	-- the skull faces the camera, so it reads from above
	local face = if camera then camera.CFrame.Position else at + Vector3.new(0, 10, 10)
	UpgradeFx.play("FxDeadlyStrike", {
		at = CFrame.lookAt(at, face),
		clip = "Strike",
		life = K.critLife,
	})
end

--[[ Blaze's tufts, one per burning enemy, on and off with `Burning`. ]]
local tufts: { [Model]: Model } = {}
local function blaze()
	local enemies = Workspace:FindFirstChild("Enemies")
	for enemy, tuft in tufts do
		if not enemy.Parent or enemy:GetAttribute("Burning") ~= true then
			UpgradeFx.stop(tuft)
			tufts[enemy] = nil
		end
	end
	if not enemies then
		return
	end
	for _, enemy in enemies:GetChildren() do
		if enemy:IsA("Model") and not tufts[enemy] and enemy:GetAttribute("Burning") == true then
			local tuft = UpgradeFx.play("FxBlaze", {
				at = enemy:GetPivot(),
				life = math.huge,
				clip = "Flicker",
				follow = function(): CFrame?
					if not enemy.Parent then
						return nil
					end
					local _, size = enemy:GetBoundingBox()
					return CFrame.new(
						enemy:GetPivot().Position + Vector3.new(0, size.Y * K.blazeHeight, 0)
					)
				end,
			})
			if tuft then
				tufts[enemy] = tuft
			end
		end
	end
end

local function onDodged(kind: string?)
	if kind == "Guard" or UpgradeFx.level("Agility") <= 0 then
		return
	end
	local root = UpgradeFx.root()
	if not root then
		return
	end
	local look = UpgradeFx.flat(root.CFrame.LookVector)
	local at = UpgradeFx.floor(root.Position, 0)
	UpgradeFx.play("FxAgility", {
		at = CFrame.lookAt(at, at + look),
		clip = "Dodge",
		life = K.dodgeLife,
		motion = function(model: Model, t: number, life: number)
			UpgradeFx.fade(model, math.floor(t / life * 3) / 3)
		end,
	})
end

function SharedFx.start()
	Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(onEnemyHit)
	Remotes.event(Remotes.PlayerDodged).OnClientEvent:Connect(onDodged)
	local polled = 0
	RunService.Heartbeat:Connect(function(dt)
		polled += dt
		if polled >= K.poll then
			polled = 0
			blaze()
		end
	end)
end

return SharedFx
