--!strict
--[[
	A melee class's swing (`Config/Classes.swing`; the Warden's greatsword).

	The same move-or-shoot rule as an arrow, decided by `FiringSystem`:
	stand still with an enemy within the class's `reach`, off cooldown, and
	a swing starts. Its blow lands later, at the moment the drawn blade
	reaches the slash's `Hit` marker (`Shared/Combat/WeaponTiming`, the
	same timing the client plays the clip at), and strikes every enemy in a
	box in front of the swinger, facing the target it swung at. Moving
	before then cancels it, as moving cancels a draw.

	Each blow of the weapon's combo has its own damage (`swing.damage`); the
	combo starts over after a pause. A swing takes crit and Blaze from the
	player's draft, read off the lead shot of the volley the pipeline would
	build, so a drafted ability means the same thing on any class. The
	server decides every hit; the client only plays the swing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Burning)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local WeaponTiming = require(ReplicatedStorage.Shared.Combat.WeaponTiming)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

type Session = RunSession.Session

local MeleeSystem = {}

--[[ A swing whose blow has not landed yet. ]]
type Pending = {
	session: Session,
	startedAt: number,
	hitAt: number,
	direction: Vector3,
	index: number,
}

local pending: { Pending } = {}

--[[ Every enemy's position and half its width, for targeting and the box. ]]
local function candidates(): { Aim.Candidate }
	local out: { Aim.Candidate } = {}
	for model, position in EnemyManager.positions() do
		local body = model.PrimaryPart
		local half = if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
		table.insert(out, { model = model, position = position, halfWidth = half })
	end
	return out
end

--[[ Starts a swing if an enemy is within reach. Returns whether it did. ]]
function MeleeSystem.swing(session: Session, root: BasePart, now: number, cooldown: number): boolean
	local class = Classes[session.loadout.class]
	if not class.swing then
		return false
	end

	local origin = Aim.shotOrigin(root.Position)
	local target = Aim.choose(
		origin,
		candidates(),
		class.reach or Balance.Player.attackRange,
		Aim.clearTest(Arena.blockers(), Balance.Projectile.radius)
	)
	if not target then
		return false
	end
	local direction = Targeting.flatDirection(root.Position, target.aimPoint)
	if not direction then
		return false
	end

	--[[ The combo goes on while swings follow one another, and starts over
	     after a pause, as the client plays it. ]]
	local index =
		WeaponTiming.nextInCombo(class.weapon, session.swingIndex, now - session.swingEndsAt)
	local weapon = (Weapons :: any)[class.weapon] :: Weapons.Weapon
	local clip = WeaponAnimations[class.weapon][weapon.clips.fire[index]]
	local speed = WeaponTiming.cycleSpeed(class.weapon, index, cooldown)

	session.swingIndex = index
	session.swingEndsAt = now + clip.length / speed
	session.lastFiredAt = now

	table.insert(pending, {
		session = session,
		startedAt = now,
		hitAt = now + WeaponTiming.hitDelay(class.weapon, index, cooldown),
		direction = direction,
		index = index,
	})
	return true
end

--[[ Lands one blow: everything in the box takes it. ]]
local function land(swing: Pending, now: number)
	local session = swing.session
	local root = session.root
	local class = Classes[session.loadout.class]
	local config = class.swing
	if not (root and config and session.alive) then
		return
	end

	--[[ Moving since the swing began cancels it. ]]
	local still = session.stationarySince
	if not still or still > swing.startedAt then
		return
	end

	local lead = session.pipeline:build({
		damage = session.damage,
		speed = session.projectileSpeed,
		lifetime = session.projectileLifetime,
		origin = root.Position,
		direction = swing.direction,
	})[1]
	local blow = session.damage * (config.damage[swing.index] or 1)

	for _, enemy in candidates() do
		if
			not SwingBox.contains(
				root.Position,
				swing.direction,
				config.width,
				config.depth,
				enemy.position,
				enemy.halfWidth
			)
		then
			continue
		end

		local damage = blow
		local kind: Types.HitKind = "Hit"
		if lead and lead.critChance > 0 and math.random() < lead.critChance then
			damage *= lead.critMultiplier
			kind = "Crit"
		end

		local landed, xp, fell = EnemyManager.damage(enemy.model, damage, root.Position, kind)
		if xp > 0 then
			RunSession.creditKill(session.player, xp, fell)
		end
		if landed and lead then
			Burning.ignite(enemy.model, blow * lead.burn, lead.burnDuration, session.player, now)
		end
	end
end

--[[ Lands every blow that is due. ]]
function MeleeSystem.step(now: number)
	local i = 1
	while i <= #pending do
		local swing = pending[i]
		if now >= swing.hitAt then
			table.remove(pending, i)
			land(swing, now)
		else
			i += 1
		end
	end
end

--[[ Forgets every swing in the air, for a run that is ending. ]]
function MeleeSystem.clear()
	table.clear(pending)
end

return MeleeSystem
