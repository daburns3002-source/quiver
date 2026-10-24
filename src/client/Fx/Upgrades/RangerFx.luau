--!strict
--[[
	The Ranger's upgrades with an effect (docs/effects/ranger-power.md).
	Ricochet, Front Arrow, Double Shot and Multishot never had one, their
	arrows being the effect; Side, Diagonal and Rear Arrow, Dual Bows, Swift
	Arrows, Long Shot and Piercing Shot had theirs cut as clutter (owner,
	2026-10-24).

	- Overdraw: rings that grow while the archer stands and charges, punched
	  out when the shot leaves.
	- Bouncy Wall: a yellow kick on the wall at each bounce.
	- Blast Arrows: a starburst at the blast's own radius.
	- Soul Chain: a chain between linked enemies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local LocalFiring = require(script.Parent.Parent.Parent.Combat.LocalFiring)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
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

local overdraw: Model? = nil

local function onFired(aim: Vector3)
	if not overdraw or not ranger() then
		return
	end
	-- the charge is spent: the rings punch out and go
	SoundFx.play("fx_overdraw")
	local spent = overdraw
	overdraw = nil
	UpgradeFx.stop(spent)
	local at = atBow(aim)
	if at then
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
	SoundFx.play("fx_blast_arrows")
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
	SoundFx.play("fx_soul_chain")
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
	FxEvents.wall:connect(onWall)
	Remotes.event(Remotes.Explosion).OnClientEvent:Connect(onExplosion)
	Remotes.event(Remotes.SoulLink).OnClientEvent:Connect(onSoulLink)
	RunService.Heartbeat:Connect(overdrawStep)
end

return RangerFx
