--!strict
--[[
	The vitality upgrades with an effect (docs/effects/shared-vitality.md).
	Healing reads as damage's inverse: it rises where damage falls, pulls
	inward where a hit throws outward, and never shakes. Lightfoot and Mending
	had effects too; the owner cut them as clutter (2026-10-24).

	- Vitality: a heart block pops and beats over the head when taken.
	- Bloodthirst: a drop flies from each kill into the player.
	- Second Wind: the winged heart rises out of the body as it saves them.
	- Heal: the flask pours over the head when the card is taken.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local VitalFx = {}

local function overHead(lift: number): () -> CFrame?
	return function(): CFrame?
		local root = UpgradeFx.root()
		return if root then CFrame.new(root.Position + Vector3.new(0, lift, 0)) else nil
	end
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
	if not UpgradeFx.root() then
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
		SoundFx.play("fx_heal")
		UpgradeFx.play("FxHeal", {
			at = CFrame.new(),
			clip = "AL_VFX_06_life_flask_play",
			life = K.flaskLife,
			follow = overHead(K.overHead),
		})
	end
end

function VitalFx.start()
	Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(onEnemyDied)
	Remotes.event(Remotes.PlayerRevived).OnClientEvent:Connect(onRevived)
	FxEvents.picked:connect(onPicked)
end

return VitalFx
