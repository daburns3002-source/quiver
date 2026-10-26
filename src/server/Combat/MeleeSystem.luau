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
	combo keeps its place between swings, however long the swinger moves in
	between. A class with `swing.guard` cannot be hurt for the whole swing
	(`RunSession.isInvulnerable`). A swing takes crit, Blaze and Soul Chain from the
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
local ProjectileSystem = require(script.Parent.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local SoulLink = require(script.Parent.SoulLink)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local WeaponTiming = require(ReplicatedStorage.Shared.Combat.WeaponTiming)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

type Session = RunSession.Session

local MeleeSystem = {}

local shotsParried = Remotes.event(Remotes.ShotsParried)

--[[ A swing whose blow has not landed yet. ]]
type Pending = {
	session: Session,
	startedAt: number,
	hitAt: number,
	direction: Vector3,
	index: number,
	--[[ The combo's place before this swing, given back if it never
	     lands. ]]
	previous: number,
	--[[ Whirlwind: this swing is the spin, hitting all round. ]]
	spin: boolean,
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
		(class.reach or Balance.Player.attackRange) + session.melee.reachBonus,
		Aim.clearTest(Arena.blockers(), Balance.Projectile.radius)
	)
	if not target then
		return false
	end
	local direction = Targeting.flatDirection(root.Position, target.aimPoint)
	if not direction then
		return false
	end

	--[[ The combo keeps its place between swings, however long the
	     Warden moves in between, as the client plays it. ]]
	local index = WeaponTiming.nextInCombo(class.weapon, session.swingIndex)
	local weapon = (Weapons :: any)[class.weapon] :: Weapons.Weapon
	local clip = WeaponAnimations[class.weapon][weapon.clips.fire[index]]
	local speed = WeaponTiming.cycleSpeed(class.weapon, index, cooldown)

	local previous = session.swingIndex
	session.swingIndex = index
	--[[ Whirlwind: every nth swing spins. ]]
	session.swingCount += 1
	local every = session.melee.whirlwindEvery
	local spin = every > 0 and session.swingCount % every == 0
	session.swingEndsAt = now + clip.length / speed
	session.lastFiredAt = now

	--[[ Untouchable for the whole swing, and for a while after with
	     Steadfast. ]]
	if class.swing.guard then
		session.guardFrom = now
		session.guardUntil = session.swingEndsAt + session.melee.guardLinger
	end

	table.insert(pending, {
		session = session,
		startedAt = now,
		hitAt = now + WeaponTiming.hitDelay(class.weapon, index, cooldown),
		direction = direction,
		index = index,
		previous = previous,
		spin = spin,
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

	--[[ Moving since the swing began cancels it, and a swing that never
	     landed does not spend its place in the combo: the slam is still to
	     come. The client gives the place back the same way. ]]
	local still = session.stationarySince
	if not still or still > swing.startedAt then
		if session.swingIndex == swing.index then
			session.swingIndex = swing.previous
		end
		return
	end
	--[[ Which blow of the combo landed last, for anything that wants to
	     show or check it. ]]
	session.player:SetAttribute("ComboBlow", swing.index)

	local lead = session.pipeline:build({
		damage = session.damage,
		speed = session.projectileSpeed,
		lifetime = session.projectileLifetime,
		origin = root.Position,
		direction = swing.direction,
	})[1]
	local melee = session.melee
	local blow = session.damage * (config.damage[swing.index] or 1)
	--[[ Heavy Blade: the combo's last blow, the slam, hits harder. ]]
	if swing.index == #config.damage then
		blow *= 1 + melee.slamBonus
	end

	--[[ An arc for the side-to-side blows, a circle for the slam, grown by
	     Cleave and Long Reach (`Shared/Combat/SwingBox`). ]]
	local shape =
		SwingBox.shape(config, swing.index, #config.damage, melee.widthScale, melee.reachBonus)
	local slam = swing.index == #config.damage
	--[[ Whirlwind: the spin hits everything round the Warden instead; the
	     attribute tells every client to draw it. ]]
	if swing.spin then
		shape = SwingBox.spin(Balance.Player.whirlwind.radius, melee.widthScale)
		session.player:SetAttribute("WhirlwindAt", workspace:GetServerTimeNow())
	end

	--[[ Parry: the blow's shape knocks enemy shots out of the air: the side
	     blows and the spin at level 1, the slam too at level 2. Measured as
	     the circle round the shape, for the server and every client alike. ]]
	if melee.parry >= (if slam and not swing.spin then 2 else 1) then
		local centre = root.Position + swing.direction * shape.ahead
		local radius = if shape.kind == "Circle" then shape.radius else shape.reach
		ProjectileSystem.clearEnemyShotsNear(centre, radius)
		shotsParried:FireAllClients(centre, radius)
	end

	--[[ Shockwave: the slam's wave rolls on down a lane, hitting each enemy
	     in it as it arrives. ]]
	if slam and not swing.spin and melee.shockwaveLength > 0 then
		local wave = Balance.Player.shockwave
		local origin = root.Position
		for _, enemy in candidates() do
			local along = SwingBox.waveAlong(
				origin,
				swing.direction,
				shape.ahead,
				melee.shockwaveLength,
				wave.width,
				enemy.position,
				enemy.halfWidth
			)
			if along then
				local model = enemy.model
				task.delay(along / wave.speed, function()
					if not (session.alive and EnemyManager.healthFraction(model)) then
						return
					end
					local _, xp, fell = EnemyManager.damage(model, blow * wave.share, origin, "Hit")
					RunSession.creditKill(session.player, xp, fell)
				end)
			end
		end
	end

	for _, enemy in candidates() do
		if
			not SwingBox.hits(
				shape,
				root.Position,
				swing.direction,
				enemy.position,
				enemy.halfWidth
			)
		then
			continue
		end

		local damage = blow
		--[[ Execute: more against an enemy already badly hurt. ]]
		local left = EnemyManager.healthFraction(enemy.model)
		if melee.executeBonus > 0 and left and left < Balance.Player.executeBelow then
			damage *= 1 + melee.executeBonus
		end
		local kind: Types.HitKind = "Hit"
		if lead and lead.critChance > 0 and math.random() < lead.critChance then
			damage *= lead.critMultiplier
			kind = "Crit"
		end

		local landed, xp, fell = EnemyManager.damage(enemy.model, damage, root.Position, kind)
		--[[ Bloodletting: a share of the blow comes back as health. ]]
		if landed and melee.lifesteal > 0 then
			RunSession.heal(session, damage * melee.lifesteal)
		end
		if xp > 0 then
			RunSession.creditKill(session.player, xp, fell)
		end
		if landed and lead then
			Burning.ignite(enemy.model, blow * lead.burn, lead.burnDuration, session.player, now)
			--[[ Soul Chain: the nearest others share the blow, as they would
			     an arrow's. ]]
			SoulLink.apply(session.player, lead.link, enemy.model, enemy.position, damage)
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

--[[ The world moves again after standing still: a swing begun before the
     pause never lands, and gives its place in the combo back, so the next
     blow waits for a swing the client plays from the start
     (`RunSession.resumeAttacks`). ]]
function MeleeSystem.resume()
	for _, swing in pending do
		local session = swing.session
		if session.swingIndex == swing.index then
			session.swingIndex = swing.previous
		end
	end
	table.clear(pending)
end

--[[ Forgets every swing in the air, for a run that is ending. ]]
function MeleeSystem.clear()
	table.clear(pending)
end

return MeleeSystem
