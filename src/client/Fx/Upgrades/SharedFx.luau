--!strict
--[[
	The six upgrades every class can draft (docs/effects/shared-combat.md):
	each anchored to the player's body, the enemy, or the point of impact,
	never to a weapon, so one effect serves the bow, the staff and the sword.

	- Deadly Strike: a skull snaps up where a crit lands, then breaks.
	- Strength: red cuffs on the arms for the run; they settle when taken.
	- Precision: a reticle under the enemy being aimed at; it locks as a
	  shot leaves.
	- Blaze: an ember tuft on every burning enemy, beside `BurnFx`'s flames.
	- Momentum: slabs shed while moving, a lit ring when the bank is full,
	  draining over the two seconds of fire it pays for.
	- Agility: an after-image left behind by a dodge.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local LocalFiring = require(script.Parent.Parent.Parent.Combat.LocalFiring)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local SharedFx = {}

local function onEnemyHit(_model: Model, _amount: number, position: Vector3, kind: string)
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

--[[ Strength's cuffs ride the upper torso for the run. ]]
local cuffs: Model? = nil
local function strength()
	local held = UpgradeFx.level("Strength") > 0
	if held and not cuffs then
		cuffs = UpgradeFx.play("FxStrength", {
			at = CFrame.new(),
			life = math.huge,
			clip = "Settle",
			follow = function(): CFrame?
				local root = UpgradeFx.root()
				local torso = root and root.Parent and root.Parent:FindFirstChild("UpperTorso")
				if torso and torso:IsA("BasePart") then
					return torso.CFrame * K.strengthOffset
				end
				return if root then root.CFrame * K.strengthOffset else nil
			end,
		})
	elseif not held and cuffs then
		UpgradeFx.stop(cuffs)
		cuffs = nil
	end
end

--[[ Precision's reticle sits under the aimed-at enemy. ]]
local reticle: Model? = nil
local reticleTarget: Model? = nil
local function precision()
	local target = if UpgradeFx.level("Precision") > 0 then LocalFiring.currentTarget() else nil
	if target ~= reticleTarget and reticle then
		UpgradeFx.stop(reticle)
		reticle = nil
	end
	reticleTarget = target
	if target and not reticle then
		reticle = UpgradeFx.play("FxPrecision", {
			at = CFrame.new(UpgradeFx.floor(target:GetPivot().Position)),
			life = math.huge,
			clip = "Track",
			follow = function(): CFrame?
				if not target.Parent then
					return nil
				end
				return CFrame.new(UpgradeFx.floor(target:GetPivot().Position))
			end,
		})
	end
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

--[[ Momentum: Bank while moving, Charged once the bank is full and still,
     Spend over the fire it pays for, then nothing until the next move. ]]
local momentum: Model? = nil
local momentumClip: string? = nil
local spendFrom: number? = nil
local function setMomentum(clip: string?)
	if clip == momentumClip then
		return
	end
	momentumClip = clip
	if not clip then
		UpgradeFx.stop(momentum)
		momentum = nil
		return
	end
	local span = if clip == "Spend" then Balance.Player.momentum.duration else nil
	if momentum then
		UpgradeFx.clip(momentum, clip, span)
		return
	end
	momentum = UpgradeFx.play("FxMomentum", {
		at = CFrame.new(),
		life = math.huge,
		clip = clip,
		span = span,
		follow = function(): CFrame?
			local root = UpgradeFx.root()
			if not root then
				return nil
			end
			local look = UpgradeFx.flat(root.CFrame.LookVector)
			local at = UpgradeFx.floor(root.Position)
			return CFrame.lookAt(at, at + look)
		end,
	})
	if not momentum then
		momentumClip = nil
	end
end

local function momentumStep()
	if UpgradeFx.level("Momentum") <= 0 then
		setMomentum(nil)
		return
	end
	local movingSince, stationarySince, movedFor = LocalFiring.motion()
	local now = os.clock()
	if movingSince then
		spendFrom = nil
		setMomentum("Bank")
	elseif stationarySince and movedFor >= Balance.Player.momentum.windup then
		if spendFrom then
			if now - spendFrom >= Balance.Player.momentum.duration then
				setMomentum(nil)
			else
				setMomentum("Spend")
			end
		else
			setMomentum("Charged")
		end
	else
		setMomentum(nil)
	end
end

local function onFired()
	if reticle then
		UpgradeFx.clip(reticle, "Lock")
		local current = reticle
		task.delay(K.precisionLock, function()
			if reticle == current then
				UpgradeFx.clip(current, "Track")
			end
		end)
	end
	if momentumClip == "Charged" then
		spendFrom = os.clock()
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

local function onPicked(id: string)
	if id == "Strength" and cuffs then
		UpgradeFx.clip(cuffs, "Settle")
		task.delay(K.strengthFlexAfter, function()
			if cuffs then
				UpgradeFx.clip(cuffs, "Flex")
			end
		end)
	end
end

function SharedFx.start()
	Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(onEnemyHit)
	Remotes.event(Remotes.PlayerDodged).OnClientEvent:Connect(onDodged)
	FxEvents.fired:connect(onFired)
	FxEvents.picked:connect(onPicked)
	local polled = 0
	RunService.Heartbeat:Connect(function(dt)
		momentumStep()
		precision()
		polled += dt
		if polled >= K.poll then
			polled = 0
			strength()
			blaze()
		end
	end)
end

return SharedFx
