--!strict
--[[
	The Warden's upgrades (docs/effects/warden-guard.md, warden-blade.md).
	The red streak `Fx/SwingTrail` draws is already grown by Cleave and Long
	Reach; these extend it, never redraw it.

	- Quick Hands: a chevron per level behind the swing as it finishes.
	- Iron Skin: four plates round the torso for the run; the one facing the
	  danger flashes when a hit is taken.
	- Cleave: the crescent of ground a side blow covers, left for a moment.
	- Long Reach: the blade's ghost carried past its tip, a segment a level.
	- Steadfast: eight plates round the feet as a swing starts, dropping one
	  by one until the guard ends; the one facing a blocked hit flashes.
	- Heavy Blade: the slam's gold starburst.
	- Bloodletting: life drawn from the struck enemy into the Warden.
	- Execute: a brand over every enemy low enough to execute; it slams
	  down when one dies.
	- Earthbreaker: the slam's torn sod and stone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local FxEvents = require(script.Parent.FxEvents)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local WardenFx = {}

local function warden(): boolean
	local class = Classes[UpgradeFx.class()]
	return class ~= nil and class.swing ~= nil
end

--[[ The value the card gives at the level held, as the server reads it. ]]
local function value(id: string): number
	local level = UpgradeFx.level(id)
	if level <= 0 then
		return 0
	end
	local levels = Abilities.byId[id].levels
	return levels[math.min(level, #levels)]
end

--[[ The swing's far edge: the box's reach plus Long Reach's. ]]
local function reach(): number
	local class = Classes[UpgradeFx.class()]
	local box = class and class.swing
	return (if box then box.reach else 4) + PlayerStats.get().reachBonus
end

local function facing(): (BasePart?, Vector3)
	local root = UpgradeFx.root()
	return root, if root then UpgradeFx.flat(root.CFrame.LookVector) else Vector3.new(0, 0, -1)
end

local function partsNamed(model: Model, word: string): { BasePart }
	local out = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and string.find(part.Name, word, 1, true) then
			table.insert(out, part)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

--[[ A plate flashes white: Neon for a beat, then back. ]]
local function flash(part: BasePart)
	local material = part.Material
	part.Material = Enum.Material.Neon
	task.delay(K.plateFlash, function()
		part.Material = material
	end)
end

--[[ Of `parts`, the one facing the nearest enemy from `centre`. ]]
local function facingDanger(parts: { BasePart }, centre: Vector3): BasePart?
	local enemies = Workspace:FindFirstChild("Enemies")
	local nearest: Vector3? = nil
	local best = math.huge
	if enemies then
		for _, enemy in enemies:GetChildren() do
			if enemy:IsA("Model") then
				local d = (enemy:GetPivot().Position - centre).Magnitude
				if d < best then
					best, nearest = d, enemy:GetPivot().Position
				end
			end
		end
	end
	if not nearest then
		return parts[1]
	end
	local toward = UpgradeFx.flat(nearest - centre)
	local pick, score = nil, -math.huge
	for _, part in parts do
		local s = UpgradeFx.flat(part.Position - centre):Dot(toward)
		if s > score then
			pick, score = part, s
		end
	end
	return pick
end

-- Iron Skin's plates, for the run
local plates: Model? = nil
local function ironSkin()
	local held = warden() and UpgradeFx.level("IronSkin") > 0
	if held and not plates then
		plates = UpgradeFx.play("FxIronSkin", {
			at = CFrame.new(),
			life = math.huge,
			follow = function(): CFrame?
				local root = UpgradeFx.root()
				if not root then
					return nil
				end
				-- turning slowly with him
				return CFrame.new(root.Position + Vector3.new(0, K.platesLift, 0))
					* CFrame.Angles(0, os.clock() * K.platesTurn, 0)
			end,
		})
		if plates then
			UpgradeFx.fade(plates, K.platesDim)
		end
	elseif not held and plates then
		UpgradeFx.stop(plates)
		plates = nil
	end
end

local function onDamaged()
	local model = plates
	local root = UpgradeFx.root()
	if not (model and root) then
		return
	end
	local plate = facingDanger(partsNamed(model, "plate"), root.Position)
	if plate then
		local before = plate.Transparency
		plate.Transparency = 0
		flash(plate)
		task.delay(K.plateFlash, function()
			plate.Transparency = before
		end)
	end
end

-- Steadfast's ring: up as a swing starts, emptying until the guard ends
local ring: Model? = nil
local ringParts: { BasePart } = {}
local swingStarted = 0
local swingEnded: number? = nil
local function onFired()
	if not warden() or UpgradeFx.level("Steadfast") <= 0 then
		return
	end
	local root = UpgradeFx.root()
	if not root then
		return
	end
	if ring then
		UpgradeFx.stop(ring)
	end
	ring = UpgradeFx.play("FxSteadfast", {
		at = CFrame.new(UpgradeFx.floor(root.Position, 0)),
		life = math.huge,
		follow = function(): CFrame?
			local r = UpgradeFx.root()
			return if r then CFrame.new(UpgradeFx.floor(r.Position, 0)) else nil
		end,
	})
	ringParts = if ring then partsNamed(ring, "plate") else {}
	swingStarted = os.clock()
	swingEnded = nil
end

local wasSlashing = false
local function onSlash(_blow: number, progress: number?)
	local slashing = progress ~= nil
	if wasSlashing and not slashing then
		swingEnded = os.clock()
		-- Quick Hands: chevrons behind the blade, one a level
		local level = UpgradeFx.level("QuickHands")
		local root, look = facing()
		if level > 0 and root then
			local at = root.Position - look * K.chevronBehind + Vector3.new(0, K.chevronLift, 0)
			local model = UpgradeFx.play("FxQuickHands", {
				at = CFrame.lookAt(at, at + look),
				life = K.chevronLife,
				motion = UpgradeFx.pop(1),
			})
			if model then
				for index, part in partsNamed(model, "chevron") do
					if index > level then
						part.Transparency = 1
					end
				end
			end
		end
	end
	if slashing and not wasSlashing and UpgradeFx.level("LongReach") > 0 then
		-- the blade carried past its tip for the length of the slash
		local root, look = facing()
		if root then
			local at = UpgradeFx.floor(root.Position, K.reachLift) + look * reach()
			local model = UpgradeFx.play("FxLongReach", {
				at = CFrame.lookAt(at, at + look),
				life = K.reachLife,
				motion = UpgradeFx.pop(1),
			})
			if model then
				local level = UpgradeFx.level("LongReach")
				for _, part in partsNamed(model, "segment_L") do
					local n = tonumber(string.match(part.Name, "segment_L(%d)")) or 1
					if n > level then
						part.Transparency = 1
					end
				end
				-- the ruler is for the pick, not every swing
				for _, part in partsNamed(model, "ruler") do
					part.Transparency = 1
				end
			end
		end
	end
	wasSlashing = slashing
end

local function steadfastStep()
	local model = ring
	if not model then
		return
	end
	local now = os.clock()
	local linger = value("Steadfast")
	local total = #ringParts
	if total == 0 then
		return
	end
	-- two plates fall during the swing, the rest over the linger
	local during = math.min(2, total)
	local down
	if not swingEnded then
		down = math.min(during - 1, math.floor((now - swingStarted) / K.steadfastSwing * during))
	else
		local u = if linger > 0 then (now - swingEnded) / linger else 1
		down = during + math.floor(math.clamp(u, 0, 1) * (total - during))
	end
	if down >= total then
		UpgradeFx.stop(model)
		ring = nil
		return
	end
	for index, part in ringParts do
		part.Transparency = if index <= down then 1 else 0
	end
end

local function onDodged(kind: string?)
	if kind ~= "Guard" or not ring then
		return
	end
	local root = UpgradeFx.root()
	local visible = {}
	for _, part in ringParts do
		if part.Transparency < 1 then
			table.insert(visible, part)
		end
	end
	local plate = root and facingDanger(visible, root.Position)
	if plate then
		flash(plate)
	end
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

-- Execute's brands, one per enemy under the line
local brands: { [Model]: Model } = {}
local branded: { [Vector3]: boolean } = {}
local function execute()
	local held = UpgradeFx.level("Execute") > 0
	for enemy, brand in brands do
		local health = enemy:GetAttribute("Health")
		local max = enemy:GetAttribute("MaxHealth")
		local low = type(health) == "number"
			and type(max) == "number"
			and max > 0
			and health / max < Balance.Player.executeBelow
		if not held or not enemy.Parent or not low then
			UpgradeFx.stop(brand)
			brands[enemy] = nil
		end
	end
	if not held then
		return
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end
	for _, enemy in enemies:GetChildren() do
		if not enemy:IsA("Model") or brands[enemy] then
			continue
		end
		local health = enemy:GetAttribute("Health")
		local max = enemy:GetAttribute("MaxHealth")
		if
			type(health) == "number"
			and type(max) == "number"
			and max > 0
			and health / max < Balance.Player.executeBelow
		then
			local brand = UpgradeFx.play("FxExecute", {
				at = enemy:GetPivot(),
				life = math.huge,
				scale = K.executeScale,
				follow = function(): CFrame?
					if not enemy.Parent then
						return nil
					end
					-- the mark half over the enemy: it sits at the model's -X
					return CFrame.new(UpgradeFx.floor(enemy:GetPivot().Position, 0))
						* CFrame.new(-K.executeMark * K.executeScale, 0, 0)
				end,
			})
			if brand then
				for _, part in brand:GetChildren() do
					if part:IsA("BasePart") and string.find(part.Name, "drop", 1, true) then
						part.Transparency = 1
					end
				end
				brands[enemy] = brand
			end
		end
	end
	table.clear(branded)
	for enemy in brands do
		branded[enemy:GetPivot().Position] = true
	end
end

local function onEnemyDied(position: Vector3)
	-- the drop plays where a branded enemy died
	local near = false
	for at in branded do
		if
			(Vector3.new(at.X, 0, at.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			< K.executeMatch
		then
			near = true
			break
		end
	end
	if not near then
		return
	end
	local drop = UpgradeFx.play("FxExecute", {
		at = CFrame.new(UpgradeFx.floor(position, 0))
			* CFrame.new(-K.executeDrop * K.executeScale, 0, 0),
		life = K.executeLife,
		scale = K.executeScale,
		motion = UpgradeFx.pop(K.executeScale, 0.2),
	})
	if drop then
		for _, part in drop:GetChildren() do
			if part:IsA("BasePart") and string.find(part.Name, "mark", 1, true) then
				part.Transparency = 1
			end
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
	FxEvents.fired:connect(onFired)
	FxEvents.slash:connect(onSlash)
	FxEvents.blow:connect(onBlow)
	FxEvents.slam:connect(onSlam)
	Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(onDamaged)
	Remotes.event(Remotes.PlayerDodged).OnClientEvent:Connect(onDodged)
	Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(onEnemyDied)
	local polled = 0
	RunService.Heartbeat:Connect(function(dt)
		steadfastStep()
		polled += dt
		if polled >= K.poll then
			polled = 0
			ironSkin()
			execute()
		end
	end)
end

return WardenFx
