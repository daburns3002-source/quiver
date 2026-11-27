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
local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local AssassinUpgrades = require(script.Parent.AssassinUpgrades)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Burning)
local ClassUpgrades = require(script.Parent.ClassUpgrades)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local DashCut = require(ReplicatedStorage.Shared.Combat.DashCut)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local FireRhythm = require(ReplicatedStorage.Shared.Combat.FireRhythm)
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
local upgradeFx = Remotes.event(Remotes.UpgradeFx)

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
	--[[ The rhythm's last attack before this swing, and as this swing
	     booked it, so a swing that never lands gives its cooldown back. ]]
	firedBefore: number,
	booked: number,
}

local pending: { Pending } = {}

--[[ The combo's place once a swing has landed or been called off, on the
     player as `Combo`: the client takes its next blow from it
     (`Fx/WeaponPose`), so a swing the two sides decided differently -- the
     client's blade past its Hit marker the frame before the server saw the
     player move -- cannot leave the client a blow ahead for the rest of the
     run (2026-11-11 playtest: the client's slam over the server's side
     swipe, every swing after one such cancel). Published only when settled,
     never at a swing's start, so it always names the blow before the next. ]]
local function publishCombo(session: Session)
	session.player:SetAttribute("Combo", session.swingIndex)
end

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
		((class.reach or Balance.Player.attackRange) + session.melee.reachBonus)
			* session.melee.reachScale,
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
	local firedBefore = session.lastFiredAt
	FireRhythm.fired(session, now, cooldown)

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
		firedBefore = firedBefore,
		booked = session.lastFiredAt,
	})
	return true
end

--[[ The lead shot of the volley the player's draft would build, which a
     blow takes its crit, Blaze and Soul Chain from. ]]
local function leadShot(session: Session, origin: Vector3, direction: Vector3): Types.ShotSpec?
	return session.pipeline:build({
		damage = session.damage,
		speed = session.projectileSpeed,
		lifetime = session.projectileLifetime,
		origin = origin,
		direction = direction,
	})[1]
end

--[[ One enemy struck for `blow`, pushed away from `from`: Execute, a crit,
     Bloodletting, Sunder, Blaze and Soul Chain, and the Assassin's Backstab,
     Serrated Edge and Bleed, as the player's draft has them. A swing's blow
     and a dash's cut land the same way. `standing` is where the striker is,
     when not `from` (a dash is pushed out from its line, but struck from
     where it ended). ]]
local function strike(
	session: Session,
	lead: Types.ShotSpec?,
	enemy: Aim.Candidate,
	blow: number,
	from: Vector3,
	now: number,
	standing: Vector3?,
	knock: number?
)
	local melee = session.melee
	local assassin = Balance.Player.assassin
	local damage = blow
	--[[ Backstab: more from behind the enemy. ]]
	if melee.backstab > 0 then
		local facing = EnemyManager.facing(enemy.model)
		if
			facing
			and AssassinRules.behind(facing, enemy.position, standing or from, assassin.backstabArc)
		then
			damage *= 1 + melee.backstab
			upgradeFx:FireAllClients("Backstab", session.player, enemy.position)
		end
	end
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

	local landed, xp, fell =
		EnemyManager.damage(enemy.model, damage, from, kind, session.player, knock)
	--[[ Comet Crash (the Comet Daggers): a comet comes down on it. ]]
	if landed then
		AssassinUpgrades.struck(session, enemy.model, enemy.position, damage, now)
	end
	--[[ Bloodletting: a share of the blow comes back as health. ]]
	if landed and melee.lifesteal > 0 then
		RunSession.heal(session, damage * melee.lifesteal)
	end
	if xp > 0 then
		RunSession.creditKill(session.player, xp, fell)
	end
	--[[ Sunder: what was struck takes more from everything for a while. ]]
	if landed and melee.sunder > 0 then
		EnemyManager.sunder(enemy.model, melee.sunder, os.clock() + Balance.Player.sunder.duration)
	end
	--[[ Serrated Edge: a crit opens the enemy the same way, for its own
	     while. ]]
	if landed and kind == "Crit" and melee.serrated > 0 then
		EnemyManager.sunder(enemy.model, melee.serrated, os.clock() + assassin.serratedDuration)
	end
	--[[ Bleed: another cut, each worth a share of this strike a second
	     (`Shared/Combat/Bleed`, ticked by `Combat/Burning`). ]]
	if landed and melee.bleed > 0 then
		Burning.bleed(enemy.model, {
			rate = blow * melee.bleed,
			stacks = assassin.bleed.stacks,
			duration = assassin.bleed.duration,
		}, session.player, now)
	end
	if landed and lead then
		Burning.ignite(enemy.model, blow * lead.burn, lead.burnDuration, session.player, now)
		--[[ Soul Chain: the nearest others share the blow, as they would
		     an arrow's. ]]
		SoulLink.apply(session.player, lead.link, enemy.model, enemy.position, damage, now)
	end
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
		--[[ And its cooldown: the swing never happened. Most of these are
		     the frame or two after the player starts moving, before the
		     server sees it, when the client never swung at all; kept, the
		     server's next swing came a whole cooldown after this phantom,
		     the client's on time, and the two combos drifted a blow apart
		     (2026-11-11 playtest: the client's side swipe over the
		     server's slam, and swings on screen that dealt nothing). The
		     client gives it back the same way (`LocalFiring.cancelSwing`). ]]
		if session.lastFiredAt == swing.booked then
			session.lastFiredAt = swing.firedBefore
		end
		publishCombo(session)
		return
	end
	--[[ Which blow of the combo landed last, for anything that wants to
	     show or check it. ]]
	session.player:SetAttribute("ComboBlow", swing.index)
	publishCombo(session)

	local lead = leadShot(session, root.Position, swing.direction)
	local melee = session.melee
	local blow = session.damage * (config.damage[swing.index] or 1)
	--[[ Heavy Blade: the combo's last blow, the slam, hits harder. ]]
	if swing.index == #config.damage then
		blow *= 1 + melee.slamBonus
	end
	--[[ Counter Strike: the first blow after being hit, charged
	     (`Combat/ClassUpgrades`). ]]
	blow *= ClassUpgrades.spendCounter(session)
	--[[ Combo Counter (the Token Daggers): every strike landed since the
	     last hit taken adds a little (`Combat/AssassinUpgrades`). ]]
	blow *= AssassinUpgrades.comboScale(session)

	--[[ An arc for the side-to-side blows, a circle for the slam, grown by
	     Cleave and Long Reach (`Shared/Combat/SwingBox`). ]]
	local shape = SwingBox.shape(
		config,
		swing.index,
		#config.damage,
		melee.widthScale,
		melee.reachBonus,
		melee.reachScale
	)
	local slam = swing.index == #config.damage
	--[[ Titan's Grip: the giant sword's slam shakes the room for everyone. ]]
	if slam and not swing.spin then
		ClassUpgrades.slammed(session, root.Position + swing.direction * shape.ahead, shape.radius)
	end
	--[[ Whirlwind: the spin hits everything round the Warden instead; the
	     attribute tells every client to draw it. ]]
	if swing.spin then
		shape = SwingBox.spin(Balance.Player.whirlwind.radius, melee.widthScale * melee.reachScale)
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
					local _, xp, fell =
						EnemyManager.damage(model, blow * wave.share, origin, "Hit", session.player)
					RunSession.creditKill(session.player, xp, fell)
				end)
			end
		end
	end

	local rushed = 0
	local struck: { Aim.Candidate } = {}
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

		strike(
			session,
			lead,
			enemy,
			blow,
			root.Position,
			now,
			nil,
			--[[ A spin shoves all the way, whatever the blow it replaced. ]]
			if config.knock and not swing.spin then config.knock[swing.index] else nil
		)
		table.insert(struck, enemy)
		--[[ Thornwood's two, on the slam alone. Boar Rush: what it hit is
		     shoved much further (a boss takes no shove at all). Ruin
		     Cracks: and takes more from everything for a while, as Sunder's
		     mark does, the stronger of the two holding. ]]
		if slam and not swing.spin then
			if melee.boarRush > 0 then
				EnemyManager.knock(enemy.model, root.Position, melee.boarRush)
				rushed += 1
			end
			if melee.ruinCracks > 0 then
				EnemyManager.sunder(
					enemy.model,
					melee.ruinCracks,
					os.clock() + Balance.Player.thornwood.ruin.duration
				)
			end
		end
	end
	if rushed > 0 then
		upgradeFx:FireAllClients(
			"BoarRush",
			session.player,
			root.Position + swing.direction * shape.ahead,
			if shape.kind == "Circle" then shape.radius else shape.reach
		)
	end

	--[[ Echo Slash: what the blow struck is struck again a moment later,
	     for the card's share of it, as a plain hit (no crit, nothing the
	     strike carries), as Shockwave's wave lands. The echo is drawn on
	     every client in the blow's own shape. ]]
	if melee.echoSlash > 0 and #struck > 0 then
		local echo = Balance.Player.waveTwo.echo
		local from = root.Position
		local echoed = blow * melee.echoSlash
		local models: { Model } = {}
		for _, enemy in struck do
			table.insert(models, enemy.model)
		end
		upgradeFx:FireAllClients(
			"EchoSlash",
			session.player,
			from,
			swing.direction,
			shape.kind,
			if shape.kind == "Circle" then shape.radius else shape.reach,
			if shape.kind == "Circle" then shape.ahead else shape.arc,
			echo.delay
		)
		task.delay(echo.delay, function()
			if not session.alive then
				return
			end
			for _, model in models do
				if EnemyManager.healthFraction(model) then
					local _, xp, fell =
						EnemyManager.damage(model, echoed, from, "Hit", session.player)
					RunSession.creditKill(session.player, xp, fell)
				end
			end
		end)
	end

	--[[ Blade Storm: every few blows that land, the sword is thrown. ]]
	ClassUpgrades.afterBlow(session, root.Position, swing.direction, now)
	--[[ Fan of Knives: and every few of the Assassin's, a fan of knives;
	     and the themed daggers' own, from what the blow struck. ]]
	AssassinUpgrades.afterBlow(session, root.Position, swing.direction, now, {
		struck = struck,
		blow = blow,
		stab = slam and not swing.spin,
		ahead = shape.ahead,
	})
end

--[[ A dash the server accepted (`Main`'s `DashStarted`), for a class whose
     dash cuts (`Classes.dash`; the Assassin's Shadow Dash), going `heading`
     (what the client sent, made a flat direction; the way the character
     faces when it sent none). Nothing can hurt the dasher until a moment
     after it ends. As it ends, every enemy within the cut along the line it
     ran is struck once, pushed out to the side it stood on
     (`Shared/Combat/DashCut`): a dash's length from where the character
     stands now, or as far as a wall or cover lets a dash go. Returns
     whether it cut. ]]
function MeleeSystem.dash(session: Session, root: BasePart, now: number, heading: Vector3?): boolean
	local class = Classes[session.loadout.class]
	local config = class and class.dash
	if not config then
		return false
	end
	local travel = Balance.Player.dash
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = heading or (if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis)
	local length =
		ClassUpgrades.flightLength(Aim.shotOrigin(root.Position), direction, travel.distance)
	local a, b = DashCut.line(root.Position, direction, length)
	session.guardFrom = now
	session.guardUntil = math.max(session.guardUntil, now + travel.duration + config.guard)

	task.delay(travel.duration, function()
		if not (session.alive and session.root == root and root.Parent) then
			return
		end
		local landedAt = os.clock()
		local lead = leadShot(session, root.Position, direction)
		local blow = session.damage * config.damage * AssassinUpgrades.comboScale(session)
		local struck: { Vector3 } = {}
		for _, enemy in candidates() do
			if DashCut.hits(a, b, config.width, enemy.position, enemy.halfWidth) then
				strike(
					session,
					lead,
					enemy,
					blow,
					DashCut.nearest(a, b, enemy.position),
					landedAt,
					b
				)
				table.insert(struck, enemy.position)
			end
		end
		upgradeFx:FireAllClients("ShadowDash", session.player, a, b, struck)
		--[[ Poison Trail: the cloud the dash leaves. ]]
		AssassinUpgrades.dashed(session, a, b, landedAt)
	end)
	return true
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
		publishCombo(session)
	end
	table.clear(pending)
end

--[[ Forgets every swing in the air, for a run that is ending. ]]
function MeleeSystem.clear()
	table.clear(pending)
end

return MeleeSystem
