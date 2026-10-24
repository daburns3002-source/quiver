--!strict
--[[
	Plays the upgrade cards' effects: copies of the models the server built
	(`Server/Fx/UpgradeEffects`, ReplicatedStorage.UpgradeEffects), played by
	`Fx/ModelAnimator` with their own clips, or moved here in code for the
	ones that have none.

	Built for phones first (owner, 2026-10-24: "make sure that this is not too
	taxing so it can run on phones"):
	- every effect was merged to a handful of parts before import;
	- copies are pooled: made once, parked outside the Workspace (where
	  ModelAnimator does not pose them) and reused, never rebuilt per hit;
	- each effect has its own cap (`Balance.UpgradeFx.caps`) and all one-shots
	  together share the device's (`DeviceTiers.maxUpgradeFx`). Past a cap a
	  new one-shot is skipped: the hit still happened, it just is not drawn.

	Presentation only. Nothing here decides an outcome.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Players = game:GetService("Players")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Parent.Device)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)

local UpgradeFx = {}

local K = Balance.UpgradeFx
local TAG = "ModelClips"

export type Motion = (model: Model, t: number, life: number) -> ()

export type Play = {
	--[[ Where the effect's pivot goes. ]]
	at: CFrame,
	--[[ Seconds until it is put away. `math.huge` for a persistent one,
	     which `UpgradeFx.stop` puts away. ]]
	life: number,
	--[[ The clip to play, and how long it is to take (its own length when
	     nil). ]]
	clip: string?,
	span: number?,
	--[[ Uniform scale about the pivot. ]]
	scale: number?,
	--[[ Called every frame with the seconds since it began: code motion for
	     an effect with no clip, or extra motion on top of one. ]]
	motion: Motion?,
	--[[ Re-places the pivot every frame (an effect riding a body); nil once
	     the thing it rides is gone, which puts it away. ]]
	follow: (() -> CFrame?)?,
}

type Live = {
	model: Model,
	key: string,
	started: number,
	life: number,
	motion: Motion?,
	follow: (() -> CFrame?)?,
	persistent: boolean,
	--[[ Each part's own transparency, for fades to return to. ]]
	base: { [BasePart]: number },
}

local pools: { [string]: { Model } } = {}
local live: { Live } = {}
local counts: { [string]: number } = {}
local oneShots = 0
local holder: Folder? = nil
local parked: Folder? = nil

local function templates(): Instance?
	return ReplicatedStorage:FindFirstChild("UpgradeEffects")
end

--[[ The template, once it and all of its parts have replicated. ]]
local function template(key: string): Model?
	local folder = templates()
	local model = folder and folder:FindFirstChild(key)
	if not model or not model:IsA("Model") then
		return nil
	end
	local want = model:GetAttribute("Parts")
	if type(want) == "number" and #model:GetChildren() < want then
		return nil
	end
	return model
end

--[[ Levels of a card this player holds; 0 for none. ]]
function UpgradeFx.level(id: string): number
	return PlayerStats.get().abilities[id] or 0
end

--[[ This player's class ("Ranger", "Arcanist", "Warden"). ]]
function UpgradeFx.class(): string
	return PlayerStats.get().class
end

--[[ This player's root part, while they have a character. ]]
function UpgradeFx.root(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--[[ `at` moved onto the arena floor (y = 0), `lift` above it. ]]
function UpgradeFx.floor(at: Vector3, lift: number?): Vector3
	return Vector3.new(at.X, lift or K.floorLift, at.Z)
end

--[[ A flat heading: `v` with no height, as a unit vector (or -Z). ]]
function UpgradeFx.flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

function UpgradeFx.ready(key: string): boolean
	return template(key) ~= nil
end

local function take(key: string): Model?
	local pool = pools[key]
	if pool and #pool > 0 then
		return table.remove(pool)
	end
	local source = template(key)
	if not source then
		return nil
	end
	local model = source:Clone()
	-- parts with no clip ride the pivot, so every effect places and scales
	model:SetAttribute("ModelClipRigid", true)
	-- tagged once for good: ModelAnimator skips it while it is parked
	CollectionService:AddTag(model, TAG)
	return model
end

local function put(entry: Live)
	local model = entry.model
	for part, t in entry.base do
		part.Transparency = t
	end
	model:SetAttribute("ModelClip", nil)
	model:SetAttribute("ModelClipAt", nil)
	model:SetAttribute("ModelClipSpan", nil)
	model:SetAttribute("ModelClipScale", nil)
	model.Parent = parked
	local pool = pools[entry.key]
	if not pool then
		pool = {}
		pools[entry.key] = pool
	end
	table.insert(pool, model)
	counts[entry.key] = (counts[entry.key] or 1) - 1
	if not entry.persistent then
		oneShots -= 1
	end
end

--[[ Plays `key` (an `ImportedModels` name, e.g. "FxHeavyBlade"). Returns the
     model, or nil when it is not drawn: not replicated yet, or over a cap. ]]
function UpgradeFx.play(key: string, opts: Play): Model?
	local persistent: boolean = opts.life == math.huge
	local cap = (K.caps :: any)[key] or K.defaultCap
	if (counts[key] or 0) >= cap then
		return nil
	end
	if not persistent and oneShots >= Device.tier().maxUpgradeFx then
		return nil
	end
	local model = take(key)
	if not model then
		return nil
	end
	model:PivotTo(opts.at)
	model:SetAttribute("ModelClipScale", opts.scale)
	model:SetAttribute("ModelClip", opts.clip)
	model:SetAttribute("ModelClipSpan", opts.span)
	model:SetAttribute("ModelClipAt", Workspace:GetServerTimeNow())
	local base: { [BasePart]: number } = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			base[part] = part.Transparency
		end
	end
	model.Parent = holder
	counts[key] = (counts[key] or 0) + 1
	if not persistent then
		oneShots += 1
	end
	local entry: Live = {
		model = model,
		key = key,
		started = os.clock(),
		life = opts.life,
		motion = opts.motion,
		follow = opts.follow,
		persistent = persistent,
		base = base,
	}
	table.insert(live, entry)
	return model
end

--[[ Puts away a model `play` returned (a persistent one, or one cut short). ]]
function UpgradeFx.stop(model: Model?)
	if not model then
		return
	end
	for i, entry in live do
		if entry.model == model then
			table.remove(live, i)
			put(entry)
			return
		end
	end
end

--[[ Restarts a playing model's clip (or switches it): a persistent effect's
     next beat. ]]
function UpgradeFx.clip(model: Model?, clip: string?, span: number?)
	if not model then
		return
	end
	model:SetAttribute("ModelClip", clip)
	model:SetAttribute("ModelClipSpan", span)
	model:SetAttribute("ModelClipAt", Workspace:GetServerTimeNow())
end

--[[ Fades a playing model toward fully clear by `amount` (0 to 1), over its
     parts' own transparency. ]]
function UpgradeFx.fade(model: Model, amount: number)
	for _, entry in live do
		if entry.model == model then
			for part, t in entry.base do
				part.Transparency = t + (1 - t) * math.clamp(amount, 0, 1)
			end
			return
		end
	end
end

--[[ The standard one-shot for an effect with no clip of its own, stepped
     rather than eased, as the effects' clips are: snaps up through two
     sizes, holds, then shrinks away over the last `out` seconds. ]]
function UpgradeFx.pop(scale: number, out: number?): Motion
	local tail = out or K.popOut
	return function(model: Model, t: number, life: number)
		local s
		if t < K.popStep then
			s = 0.55
		elseif t < K.popStep * 2 then
			s = 1.12
		elseif t > life - tail then
			s = math.max(0.05, (life - t) / tail)
			s = math.ceil(s * 4) / 4 -- stepped
		else
			s = 1
		end
		model:SetAttribute("ModelClipScale", s * scale)
	end
end

local function step()
	local now = os.clock()
	for i = #live, 1, -1 do
		local entry = live[i]
		local t = now - entry.started
		local ended = t >= entry.life
		if not ended and entry.follow then
			local at = entry.follow()
			if at then
				entry.model:PivotTo(at)
			else
				ended = true
			end
		end
		if not ended and entry.motion then
			entry.motion(entry.model, t, entry.life)
		end
		if ended then
			table.remove(live, i)
			put(entry)
		end
	end
end

function UpgradeFx.start()
	local folder = Instance.new("Folder")
	folder.Name = "UpgradeFx"
	folder.Parent = Workspace
	holder = folder
	local park = Instance.new("Folder")
	park.Name = "UpgradeFxPool"
	park.Parent = ReplicatedStorage
	parked = park
	RunService.RenderStepped:Connect(step)
end

return UpgradeFx
