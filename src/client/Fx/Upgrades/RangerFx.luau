--!strict
--[[
	The Ranger's upgrades (docs/effects/ranger-power.md, ranger-spread.md,
	ranger-shots.md). Ricochet, Front Arrow, Double Shot and Multishot have no
	effect of their own: their arrows are the effect (owner, 2026-10-24).

	- At the bow, as a volley leaves: Side Arrows' green bar, Diagonal
	  Arrows' blue X, Rear Arrow's back flash, and Dual Bows' crossed burst
	  (no more than once every `dualBowsEvery` seconds: it is the loud one).
	- Overdraw: rings that grow while the archer stands and charges, punched
	  out when the shot leaves.
	- On the arrow: Swift Arrows' speed slabs, Long Shot's heating ladder,
	  which grows with the distance flown.
	- Where it lands: Piercing Shot's aperture at each body passed through,
	  Bouncy Wall's yellow kick at each bounce, Blast Arrows' starburst at
	  the blast's own radius, Soul Chain's chain between linked enemies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local LocalFiring = require(script.Parent.Parent.Parent.Combat.LocalFiring)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local RangerFx = {}

local function ranger(): boolean
	return UpgradeFx.class() == "Ranger"
end

--[[ Where a flare at the bow goes: in front of the archer at arrow height,
     its front (-Z) along the aim. ]]
local function atBow(aim: Vector3): CFrame?
	local root = UpgradeFx.root()
	if not root then
		return nil
	end
	local heading = UpgradeFx.flat(aim)
	local at = Aim.shotOrigin(root.Position) + heading * K.bowAhead
	return CFrame.lookAt(at, at + heading)
end

local lastDualBows = -math.huge
local overdraw: Model? = nil

local function onFired(aim: Vector3)
	if not ranger() then
		return
	end
	local at = atBow(aim)
	if not at then
		return
	end
	if UpgradeFx.level("SideArrows") > 0 then
		UpgradeFx.play("FxSideArrows", { at = at, life = K.flareLife, motion = UpgradeFx.pop(1) })
	end
	if UpgradeFx.level("DiagonalArrows") > 0 then
		UpgradeFx.play(
			"FxDiagonalArrows",
			{ at = at, life = K.flareLife, motion = UpgradeFx.pop(1) }
		)
	end
	if UpgradeFx.level("RearArrow") > 0 then
		UpgradeFx.play("FxRearArrow", { at = at, clip = "RearArrow", life = K.rearLife })
	end
	local now = os.clock()
	if UpgradeFx.level("DualBows") > 0 and now - lastDualBows >= K.dualBowsEvery then
		lastDualBows = now
		local root = UpgradeFx.root()
		if root then
			local flat = CFrame.lookAt(root.Position, root.Position + UpgradeFx.flat(aim))
			UpgradeFx.play("FxDualBows", {
				at = flat * CFrame.new(0, K.chest, 0),
				life = K.dualBowsLife,
				motion = UpgradeFx.pop(1, 0.25),
			})
		end
	end
	if overdraw then
		-- the charge is spent: the rings punch out and go
		local spent = overdraw
		overdraw = nil
		UpgradeFx.stop(spent)
		UpgradeFx.play("FxOverdraw", { at = at, life = K.flareLife, motion = UpgradeFx.pop(1.3) })
	end
end

--[[ Overdraw: shown while standing still with the card, growing over the
     ramp the server charges over. ]]
local function overdrawStep()
	local held = ranger() and UpgradeFx.level("Overdraw") > 0
	local _, stationarySince = LocalFiring.motion()
	local target = LocalFiring.currentTarget()
	if not held or not stationarySince or not target then
		if overdraw then
			UpgradeFx.stop(overdraw)
			overdraw = nil
		end
		return
	end
	if not overdraw then
		overdraw = UpgradeFx.play("FxOverdraw", {
			at = CFrame.new(),
			life = math.huge,
			follow = function(): CFrame?
				local aimAt = LocalFiring.currentTarget()
				local root = UpgradeFx.root()
				if not (aimAt and root) then
					return nil
				end
				return atBow(aimAt:GetPivot().Position - root.Position)
			end,
			motion = function(model: Model, _t: number, _life: number)
				local _, since = LocalFiring.motion()
				local charge = if since
					then math.clamp((os.clock() - since) / Balance.Player.overdrawRamp, 0, 1)
					else 0
				-- stepped, as the rings snap flush one at a time
				model:SetAttribute("ModelClipScale", 0.4 + math.floor(charge * 3) / 3 * 0.6)
			end,
		})
	end
end

--[[ Trails that ride a player arrow while it flies. ]]
local function onLaunched(part: BasePart, pool: string, _aim: Vector3, _chained: boolean)
	if pool ~= "Player" then
		return
	end
	local start = part.Position
	local function riding(): CFrame?
		if not part.Parent then
			return nil
		end
		return part.CFrame
	end
	if UpgradeFx.level("SwiftArrows") > 0 then
		UpgradeFx.play("FxSwiftArrows", { at = part.CFrame, life = K.trailLife, follow = riding })
	end
	if UpgradeFx.level("LongShot") > 0 then
		UpgradeFx.play("FxLongShot", {
			at = part.CFrame,
			life = K.trailLife,
			follow = riding,
			motion = function(model: Model, _t: number, _life: number)
				if not part.Parent then
					return
				end
				-- it heats and grows as the shot earns its bonus
				local flown = (part.Position - start).Magnitude
				local u = math.clamp(flown / Balance.Projectile.farRange, 0, 1)
				model:SetAttribute("ModelClipScale", K.longShotMin + (1 - K.longShotMin) * u)
			end,
		})
	end
end

local function onContact(position: Vector3, heading: Vector3, pool: string, pierceLeft: number)
	if pool ~= "Player" or pierceLeft <= 0 or UpgradeFx.level("PiercingShot") <= 0 then
		return
	end
	UpgradeFx.play("FxPiercingShot", {
		at = CFrame.lookAt(position, position + UpgradeFx.flat(heading)),
		life = K.pierceLife,
		motion = UpgradeFx.pop(1),
	})
end

local function onWall(
	position: Vector3,
	normal: Vector3,
	heading: Vector3,
	pool: string,
	bounced: boolean
)
	if pool ~= "Player" or not bounced or UpgradeFx.level("BouncyWall") <= 0 then
		return
	end
	-- stamped on the wall, pointing the way the arrow leaves
	local up = normal
	local leave = UpgradeFx.flat(heading)
	UpgradeFx.play("FxBouncyWall", {
		at = CFrame.lookAt(position + normal * 0.1, position + normal * 0.1 + leave, up),
		life = K.bounceLife,
		motion = UpgradeFx.pop(1),
	})
end

local function onExplosion(centre: Vector3, radius: number)
	if not ranger() or UpgradeFx.level("BlastArrows") <= 0 then
		return
	end
	UpgradeFx.play("FxBlastArrows", {
		at = CFrame.new(UpgradeFx.floor(centre, 0)),
		life = K.blastLife,
		scale = radius / K.blastRadius,
		motion = UpgradeFx.pop(radius / K.blastRadius, 0.2),
	})
end

local function onSoulLink(centre: Vector3, reached: { Vector3 })
	if UpgradeFx.level("SoulChain") <= 0 then
		return
	end
	for _, to in reached do
		local span = to - centre
		if span.Magnitude < 1e-3 then
			continue
		end
		local mid = (centre + to) / 2 + Vector3.new(0, K.chainLift, 0)
		local scale = math.clamp(span.Magnitude / K.chainLength, 0.35, 1.4)
		UpgradeFx.play("FxSoulChain", {
			-- the chain lies along its length: the model's X
			at = CFrame.lookAt(mid, mid + UpgradeFx.flat(span)) * CFrame.Angles(0, math.rad(90), 0),
			life = K.chainLife,
			scale = scale,
			motion = UpgradeFx.pop(scale, 0.12),
		})
	end
end

function RangerFx.start()
	FxEvents.fired:connect(onFired)
	FxEvents.launched:connect(onLaunched)
	FxEvents.contact:connect(onContact)
	FxEvents.wall:connect(onWall)
	Remotes.event(Remotes.Explosion).OnClientEvent:Connect(onExplosion)
	Remotes.event(Remotes.SoulLink).OnClientEvent:Connect(onSoulLink)
	RunService.Heartbeat:Connect(overdrawStep)
end

return RangerFx
