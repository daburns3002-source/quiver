--!strict
--[[
	Plays a pet's attack pieces (`Config/PetAttacks`) alongside its Attack
	clip: projectiles flying at the nearest enemies, marks and ground effects
	under or over them, a reach (tongue, beam) toward them, auras on the
	owner. Copies come from `Fx/Upgrades/UpgradeFx` (pooled, capped per
	device), so a piece the owner has not imported yet is simply not drawn.

	Presentation only: nothing here hits anything. Phase 6's pet combat will
	decide the hits; until then the Studio sandbox's PET ATTACK button
	(`Fx/PetPreview.attack`) is the caller.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetSounds = require(ReplicatedStorage.Shared.Config.PetSounds)
local SoundFx = require(script.Parent.SoundFx)
local UpgradeFx = require(script.Parent.Upgrades.UpgradeFx)

local PetAttackFx = {}

--[[ How high above the pet's pivot shots leave from, and how far ahead a
     shot aims with no enemy to aim at. ]]
local MOUTH = 1.2
local NO_TARGET = 12

local function enemies(from: Vector3): { Model }
	local folder = Workspace:FindFirstChild("Enemies")
	local out: { Model } = {}
	if folder then
		for _, e in folder:GetChildren() do
			if e:IsA("Model") then
				table.insert(out, e)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a:GetPivot().Position - from).Magnitude < (b:GetPivot().Position - from).Magnitude
	end)
	return out
end

local function ownerRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--[[ A Projectile: flies from `from` to `target` (or straight ahead),
     turned `yaw` degrees off the line, then plays its impact. ]]
local function fly(
	shot: PetAttacks.Shot,
	from: Vector3,
	target: Model?,
	ahead: Vector3,
	yaw: number
)
	local function dest(): Vector3
		local p = if target and target.Parent
			then target:GetPivot().Position
			else from + ahead * NO_TARGET
		local offset = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(p - from)
		return from + offset
	end
	local fixed = dest()
	local life = math.max(0.15, (fixed - from).Magnitude / (shot.speed or 25))
	local arc = shot.arc or 0
	local function place(t: number): Vector3
		local goal = if shot.homing then dest() else fixed
		local u = math.clamp(t / life, 0, 1)
		return from:Lerp(goal, u) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
	end
	UpgradeFx.play(shot.effect, {
		at = CFrame.lookAt(from, fixed),
		life = life,
		clip = shot.clip,
		motion = function(model: Model, t: number)
			local p, next = place(t), place(t + 1 / 30)
			model:PivotTo(
				if (next - p).Magnitude > 1e-3 then CFrame.lookAt(p, next) else CFrame.new(p)
			)
		end,
	})
	local impact = shot.impact
	if impact then
		task.delay(life, function()
			local landed = place(life)
			UpgradeFx.play(impact.effect, {
				at = CFrame.new(UpgradeFx.floor(landed)) * CFrame.Angles(0, math.rad(yaw), 0),
				life = impact.life,
				clip = impact.clip,
			})
		end)
	end
end

--[[ One firing of `shot`, the `index`th of its count. ]]
local function fire(shot: PetAttacks.Shot, pet: Model, index: number)
	if not pet.Parent then
		return
	end
	local pivot = pet:GetPivot()
	local from = pivot.Position + Vector3.new(0, MOUTH, 0)
	local targets = enemies(from)
	local nearest = targets[1]
	local ahead =
		UpgradeFx.flat(if nearest then nearest:GetPivot().Position - from else pivot.LookVector)
	local life = shot.life or 1
	local kind = shot.kind
	if kind == "Projectile" then
		-- a fan centred on the line to the enemy
		local yaw = (index - ((shot.count or 1) + 1) / 2) * (shot.spread or 0)
		fly(shot, from, nearest, ahead, yaw)
	elseif kind == "Reach" then
		local sweep = shot.sweep or 0
		local base = CFrame.lookAt(from, from + ahead)
			* (if shot.flip then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		UpgradeFx.play(shot.effect, {
			at = base,
			life = life,
			clip = shot.clip,
			motion = if sweep ~= 0
				then function(model: Model, t: number, span: number)
					local turn = math.rad(sweep) * (t / span - 0.5)
					model:PivotTo(base * CFrame.Angles(0, -turn, 0))
				end
				else nil,
		})
	elseif kind == "Ground" then
		local want = shot.targets or 1
		local spot: Vector3
		if want == 0 or not targets[index] then
			spot = if want == 0 or not nearest then pivot.Position else nearest:GetPivot().Position
		else
			spot = targets[index]:GetPivot().Position
		end
		UpgradeFx.play(shot.effect, {
			at = CFrame.lookAt(
				UpgradeFx.floor(spot, shot.lift),
				UpgradeFx.floor(spot, shot.lift) + ahead
			),
			life = life,
			clip = shot.clip,
		})
	elseif kind == "Overhead" then
		local target = nearest
		local lift = shot.lift or 4
		local function over(): CFrame?
			if target and target.Parent then
				return CFrame.new(target:GetPivot().Position + Vector3.new(0, lift, 0))
			end
			return nil
		end
		local start = over()
		if start then
			UpgradeFx.play(
				shot.effect,
				{ at = start, life = life, clip = shot.clip, follow = over }
			)
		end
	elseif kind == "Owner" then
		local function under(): CFrame?
			local root = ownerRoot()
			return if root then CFrame.new(UpgradeFx.floor(root.Position, shot.lift)) else nil
		end
		local start = under()
		if start then
			UpgradeFx.play(
				shot.effect,
				{ at = start, life = life, clip = shot.clip, follow = under }
			)
		end
	end
end

--[[ One blow of a pet that dashes (`Config/PetCombat` `dash`, the Glade
     Fox), as it lands beside `target`: its first piece on the floor under
     the enemy, facing the way the pet came in, and its sounds. ]]
function PetAttackFx.strike(pet: Model, key: string, target: Model?)
	for _, cue in (PetSounds :: any)[key] or {} do
		SoundFx.play(cue.sound)
	end
	local shots = (PetAttacks :: any)[key] :: { PetAttacks.Shot }?
	local shot = shots and shots[1]
	if not shot or not pet.Parent then
		return
	end
	local from = pet:GetPivot().Position
	local spot = if target and target.Parent then target:GetPivot().Position else from
	local ahead = UpgradeFx.flat(spot - from)
	local floor = UpgradeFx.floor(spot, shot.lift)
	UpgradeFx.play(shot.effect, {
		at = CFrame.lookAt(floor, floor + ahead),
		life = shot.life or 1,
		clip = shot.clip,
	})
end

--[[ Plays the pieces of `key`'s attack (a `Config/PetAttacks` key, the
     pet's model name) from `pet`, and its sounds (`Config/PetSounds`), timed
     from now as its Attack clip starts. Returns how many pieces it will fire. ]]
function PetAttackFx.play(pet: Model, key: string): number
	for _, cue in (PetSounds :: any)[key] or {} do
		task.delay(cue.at, SoundFx.play, cue.sound)
	end
	local shots = (PetAttacks :: any)[key] :: { PetAttacks.Shot }?
	if not shots then
		return 0
	end
	local fired = 0
	for _, shot in shots do
		local count = if shot.kind == "Ground"
			then math.max(shot.targets or 1, 1)
			else shot.count or 1
		for i = 1, count do
			local delay = shot.at + (i - 1) * (shot.every or 0)
			task.delay(delay, fire, shot, pet, i)
			fired += 1
		end
	end
	return fired
end

return PetAttackFx
