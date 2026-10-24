--!strict
--[[
	The six vitality upgrades every class is dealt
	(docs/effects/shared-vitality.md). Healing reads as damage's inverse: it
	rises where damage falls, pulls inward where a hit throws outward, and
	never shakes.

	- Lightfoot: a speed puff shed behind the feet every few studs moved;
	  closer together per level. Two when the card is taken.
	- Vitality: a heart block pops and beats over the head when taken.
	- Mending: a leaf mote rises once a second, only while hurt.
	- Bloodthirst: a drop flies from each kill into the player.
	- Second Wind: the winged heart rises out of the body as it saves them.
	- Heal: the flask pours over the head when the card is taken.
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

local VitalFx = {}

local function overHead(lift: number): () -> CFrame?
	return function(): CFrame?
		local root = UpgradeFx.root()
		return if root then CFrame.new(root.Position + Vector3.new(0, lift, 0)) else nil
	end
end

local function puff(root: BasePart, back: number)
	local look = UpgradeFx.flat(root.AssemblyLinearVelocity)
	local at = UpgradeFx.floor(root.Position - look * back, K.puffLift)
	UpgradeFx.play("FxLightfoot", {
		at = CFrame.lookAt(at, at + look),
		clip = "AL_VFX_01_speed_puff_play",
		life = K.puffLife,
	})
end

--[[ Lightfoot: one puff per `puffEvery / level` studs travelled. ]]
local travelled = 0
local lastAt: Vector3? = nil
local function lightfoot()
	local level = UpgradeFx.level("Lightfoot")
	local root = UpgradeFx.root()
	local movingSince = LocalFiring.motion()
	if level <= 0 or not root or not movingSince then
		lastAt = if root then root.Position else nil
		return
	end
	local here = root.Position
	if lastAt then
		travelled += (Vector3.new(here.X, 0, here.Z) - Vector3.new(lastAt.X, 0, lastAt.Z)).Magnitude
	end
	lastAt = here
	if travelled >= K.puffEvery / level then
		travelled = 0
		puff(root, K.puffBehind)
	end
end

--[[ Mending: one mote a second while below full health. ]]
local health, maxHealth = 1, 1
local lastMote = 0
local function mending()
	if UpgradeFx.level("Mending") <= 0 or health >= maxHealth then
		return
	end
	local now = os.clock()
	if now - lastMote < K.moteEvery then
		return
	end
	lastMote = now
	local root = UpgradeFx.root()
	if root then
		local side = if math.random() < 0.5 then -1 else 1
		UpgradeFx.play("FxMending", {
			at = root.CFrame * CFrame.new(side * K.moteShoulder, K.moteLift, 0),
			clip = "AL_VFX_03_leaf_mote_play",
			life = K.moteLife,
		})
	end
end

local function onHealth(now: number, max: number)
	health, maxHealth = now, max
end

--[[ Bloodthirst: a drop from the corpse into the chest, half a beat after
     the death pop. ]]
local function onEnemyDied(position: Vector3)
	if UpgradeFx.level("Bloodthirst") <= 0 then
		return
	end
	local from = position + Vector3.new(0, K.dropLift, 0)
	task.delay(K.dropDelay, function()
		UpgradeFx.play("FxBloodthirst", {
			at = CFrame.new(from),
			clip = "AL_VFX_04_life_drop_play",
			life = K.dropLife,
			motion = function(model: Model, t: number, life: number)
				local root = UpgradeFx.root()
				if not root then
					return
				end
				local chest = root.Position + Vector3.new(0, K.chest, 0)
				local u = math.clamp(t / (life * 0.8), 0, 1)
				-- a short arc, up and in
				local at = from:Lerp(chest, u)
					+ Vector3.new(0, math.sin(u * math.pi) * K.dropArc, 0)
				model:PivotTo(CFrame.new(at))
			end,
		})
	end)
end

local function onRevived(player: Player, _position: Vector3, _duration: number, kind: string?)
	if kind ~= "SecondWind" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	UpgradeFx.play("FxSecondWind", {
		at = root.CFrame,
		clip = "AL_VFX_05_winged_heart_play",
		life = K.windLife,
		motion = function(model: Model, t: number, _life: number)
			if not root.Parent then
				return
			end
			-- rises out of the body as it beats
			local rise = math.min(t / K.windRise, 1) * K.windHeight
			local camera = Workspace.CurrentCamera
			local at = root.Position + Vector3.new(0, K.chest + rise, 0)
			local face = if camera then camera.CFrame.Position else at + Vector3.new(0, 10, 10)
			model:PivotTo(CFrame.lookAt(at, Vector3.new(face.X, at.Y, face.Z)))
		end,
	})
end

local function onPicked(id: string)
	local root = UpgradeFx.root()
	if not root then
		return
	end
	if id == "Vitality" then
		UpgradeFx.play("FxVitality", {
			at = CFrame.new(),
			clip = "AL_VFX_02_heart_block_play",
			life = K.heartLife,
			follow = overHead(K.overHead),
		})
	elseif id == "Heal" then
		UpgradeFx.play("FxHeal", {
			at = CFrame.new(),
			clip = "AL_VFX_06_life_flask_play",
			life = K.flaskLife,
			follow = overHead(K.overHead),
		})
	elseif id == "Lightfoot" then
		puff(root, 0)
		task.delay(K.puffLife * 0.5, function()
			local again = UpgradeFx.root()
			if again then
				puff(again, K.puffBehind)
			end
		end)
	end
end

function VitalFx.start()
	Remotes.event(Remotes.HealthChanged).OnClientEvent:Connect(onHealth)
	Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(onEnemyDied)
	Remotes.event(Remotes.PlayerRevived).OnClientEvent:Connect(onRevived)
	FxEvents.picked:connect(onPicked)
	RunService.Heartbeat:Connect(function()
		lightfoot()
		mending()
	end)
end

return VitalFx
