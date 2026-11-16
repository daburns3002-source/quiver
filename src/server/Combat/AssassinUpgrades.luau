--!strict
--[[
	The Assassin's cards that act beside its strikes (`Config/Abilities`,
	group "dagger"; `AbilityEffects.UpgradeStats`), as `Combat/ClassUpgrades`
	holds the other classes'. Each is off without its card: the server reads
	the session's `upgrades`, never a card's name.

	- Poison Trail (Rare): a dash that cut leaves a cloud round its middle
	  that hurts what stands in it (`dashed`, an `AreaStrikes` zone).
	- Fan of Knives (Epic): every 4th strike that lands throws a fan of
	  knives along it (`afterBlow`), invented shots like Split Shot's.
	- Death Mark (Legendary): one enemy takes more from everything
	  (`EnemyManager.mark`); when it falls the mark jumps to the nearest
	  (`step`).
	- Phantom Blades (Legendary): ghost daggers circle the Assassin and cut
	  what they touch (`step`). Where each one is comes from the server's
	  clock (`Shared/Combat/AssassinRules.orbit`), so every client draws
	  them where the server cuts.
	- Thousand Cuts (Mythic): every 10 s of fighting, shadows strike up to
	  eight enemies in turn (`step`).

	Backstab, Serrated Edge and Bleed are in the strike itself
	(`Combat/MeleeSystem`), Twin Fangs in its numbers, Quickstep in
	`RunSession.onEnemyKilled`.

	The numbers are `Balance.Player.assassin`. Clients only draw:
	`Remotes.UpgradeFx` and the attributes `DeathMarked` (on the enemy) and
	`PhantomBlades` (on the player).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local AreaStrikes = require(script.Parent.AreaStrikes)
local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ClassUpgrades = require(script.Parent.ClassUpgrades)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

type Session = RunSession.Session

local AssassinUpgrades = {}

local upgradeFx = Remotes.event(Remotes.UpgradeFx)

--[[ A gap between steps longer than this is the world standing still
     behind a card screen; none of it may count (as `ClassUpgrades`). ]]
local PAUSE = 0.25

type State = {
	--[[ Fan of Knives: strikes landed this run. ]]
	blows: number,
	--[[ Death Mark: the enemy carrying it, and where it last stood. ]]
	marked: Model?,
	markedAt: Vector3?,
	--[[ Phantom Blades: when each enemy may be cut again (os.clock), and
	     how many blades were last published on the player. ]]
	cutAgain: { [Model]: number },
	shownBlades: number,
	--[[ Thousand Cuts: when the next round starts (os.clock); nil before
	     the first fight. ]]
	cutsNextAt: number?,
}

local states: { [Session]: State } = setmetatable({}, { __mode = "k" }) :: any

--[[ One strike of a round of Thousand Cuts, waiting for its shadow. ]]
type Cut = { session: Session, model: Model, from: Vector3, hitAt: number }
local cuts: { Cut } = {}

local lastStep: number? = nil

local function state(session: Session): State
	local own = states[session]
	if not own then
		own = { blows = 0, cutAgain = {}, shownBlades = 0 }
		states[session] = own
	end
	return own
end

local function halfWidth(model: Model): number
	local body = model.PrimaryPart
	return if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
end

--[[ Poison Trail: a dash cut the ground from `a` to `b`
     (`Combat/MeleeSystem.dash`). ]]
function AssassinUpgrades.dashed(session: Session, a: Vector3, b: Vector3, now: number)
	local seconds = session.upgrades.poisonTrail
	if seconds <= 0 then
		return
	end
	local config = Balance.Player.assassin.poison
	local middle = (a + b) / 2
	AreaStrikes.zone(
		session.player,
		middle,
		config.radius,
		session.damage * config.damage,
		config.every,
		seconds,
		now,
		nil,
		false
	)
	upgradeFx:FireAllClients(
		"PoisonTrail",
		session.player,
		Vector3.new(middle.X, 0, middle.Z),
		config.radius,
		seconds
	)
end

--[[ Fan of Knives: a strike landed along `direction`
     (`Combat/MeleeSystem`); every `every`th throws the fan. ]]
function AssassinUpgrades.afterBlow(
	session: Session,
	origin: Vector3,
	direction: Vector3,
	now: number
)
	local count = session.upgrades.fanOfKnives
	if count <= 0 then
		return
	end
	local config = Balance.Player.assassin.knives
	local own = state(session)
	own.blows += 1
	if own.blows % config.every ~= 0 then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local speed = Balance.Projectile.speed * config.speed
	local spec = ClassUpgrades.plainSpec(speed, config.range / speed, 0)
	local from = Aim.shotOrigin(origin)
	for _, angle in AssassinRules.fan(count, config.spread) do
		ClassUpgrades.invent(
			session,
			from,
			AssassinRules.turned(flat.Unit, angle),
			spec,
			session.damage * config.damage,
			"Knife",
			now
		)
	end
end

--[[ Death Mark: keeps one enemy marked, moving the mark on when its
     bearer is gone. ]]
local function deathMark(session: Session, own: State, now: number)
	local extra = session.upgrades.deathMark
	local marked = own.marked
	if marked and EnemyManager.healthFraction(marked) then
		if extra <= 0 then
			EnemyManager.mark(marked, 1, 0)
			marked:SetAttribute("DeathMarked", nil)
			own.marked = nil
		else
			own.markedAt = EnemyManager.positions()[marked] or own.markedAt
		end
		return
	end
	own.marked = nil
	if extra <= 0 then
		return
	end
	local root = session.root
	local from = own.markedAt or (if root then root.Position else nil)
	if not from then
		return
	end
	local positions = EnemyManager.positions()
	local reach = Balance.Player.assassin.deathMark.reach
	local nextOne = AssassinRules.nearest(from, positions, reach)
		--[[ None near where the last one fell: the nearest to the Assassin. ]]
		or (if root then AssassinRules.nearest(root.Position, positions, math.huge) else nil)
	if not nextOne then
		own.markedAt = nil
		return
	end
	own.marked = nextOne
	own.markedAt = positions[nextOne]
	--[[ For as long as it lives: the mark only ever leaves by its death. ]]
	EnemyManager.mark(nextOne, 1 + extra, now + 3600)
	nextOne:SetAttribute("DeathMarked", true)
end

--[[ Phantom Blades: each blade cuts what it touches. ]]
local function phantomBlades(session: Session, own: State, now: number, moving: boolean)
	local count = session.upgrades.phantomBlades
	if count ~= own.shownBlades then
		own.shownBlades = count
		session.player:SetAttribute("PhantomBlades", if count > 0 then count else nil)
	end
	local root = session.root
	if count <= 0 or not root or not moving then
		return
	end
	local config = Balance.Player.assassin.phantom
	local clock = Workspace:GetServerTimeNow()
	for model, position in EnemyManager.positions() do
		if (own.cutAgain[model] or 0) > now then
			continue
		end
		local half = halfWidth(model)
		for index = 1, count do
			local blade =
				AssassinRules.orbit(root.Position, config.radius, config.turn, clock, index, count)
			local away = Vector3.new(position.X - blade.X, 0, position.Z - blade.Z).Magnitude
			if away <= config.reach + half then
				own.cutAgain[model] = now + config.again
				--[[ Pushed away from the blade that cut it, not from the
				     Assassin: a ring of blades must not sweep the room clear
				     of everything the daggers are trying to reach. ]]
				local _, xp, fell = EnemyManager.damage(
					model,
					session.damage * config.damage,
					blade,
					"Hit",
					session.player,
					config.knock
				)
				RunSession.creditKill(session.player, xp, fell)
				break
			end
		end
	end
	--[[ Forget the fallen, so the table never outgrows the room. ]]
	for model, again in own.cutAgain do
		if again <= now and not model.Parent then
			own.cutAgain[model] = nil
		end
	end
end

--[[ Thousand Cuts: a round every `every` seconds of fighting. ]]
local function thousandCuts(session: Session, own: State, now: number, deltaTime: number)
	if session.upgrades.thousandCuts <= 0 then
		own.cutsNextAt = nil
		return
	end
	local config = Balance.Player.assassin.thousandCuts
	local root = session.root
	if not root or EnemyManager.aliveCount() == 0 then
		--[[ Only fighting counts: an empty room holds the clock. ]]
		if own.cutsNextAt then
			own.cutsNextAt = (own.cutsNextAt :: number) + deltaTime
		end
		return
	end
	if not own.cutsNextAt then
		own.cutsNextAt = now + config.every
		return
	end
	if now < own.cutsNextAt then
		return
	end
	local positions = EnemyManager.positions()
	local round = AssassinRules.round(root.Position, positions, config.range, config.most)
	if #round == 0 then
		return
	end
	own.cutsNextAt = now + config.every
	local at: { Vector3 } = {}
	for index, model in round do
		table.insert(cuts, {
			session = session,
			model = model,
			from = root.Position,
			hitAt = now + index * config.gap,
		})
		local position = positions[model]
		table.insert(at, Vector3.new(position.X, 0, position.Z))
	end
	upgradeFx:FireAllClients("ThousandCuts", session.player, at, config.gap)
end

function AssassinUpgrades.step(deltaTime: number, now: number)
	--[[ A card screen held the world: push every clock on by the time it
	     stood, so nothing fires what it missed at once. ]]
	local last = lastStep
	lastStep = now
	local moving = true
	if last and now - last > PAUSE then
		local stood = now - last
		moving = false
		for _, cut in cuts do
			cut.hitAt += stood
		end
		for _, own in states do
			if own.cutsNextAt then
				own.cutsNextAt = (own.cutsNextAt :: number) + stood
			end
		end
	end

	--[[ Thousand Cuts: each shadow's strike lands as it appears. ]]
	local config = Balance.Player.assassin.thousandCuts
	for index = #cuts, 1, -1 do
		local cut = cuts[index]
		if now >= cut.hitAt then
			table.remove(cuts, index)
			local session = cut.session
			if session.alive and EnemyManager.healthFraction(cut.model) then
				local _, xp, fell = EnemyManager.damage(
					cut.model,
					session.damage * config.damage,
					cut.from,
					"Hit",
					session.player,
					config.knock
				)
				RunSession.creditKill(session.player, xp, fell)
			end
		end
	end

	for _, session in RunSession.all() do
		local upgrades = session.upgrades
		local held = upgrades.deathMark > 0
			or upgrades.phantomBlades > 0
			or upgrades.thousandCuts > 0
		--[[ A session that never held one of these has nothing to keep. ]]
		if not (held or states[session]) or not session.alive then
			continue
		end
		local own = state(session)
		deathMark(session, own, now)
		phantomBlades(session, own, now, moving)
		thousandCuts(session, own, now, if moving then deltaTime else 0)
	end
end

--[[ Forgets everything in the air and every mark, for a room that is done
     (`RoomController`'s `clearFight`). Thousand Cuts keeps its clock: it
     counts fighting across rooms, as the cards that count strikes do. ]]
function AssassinUpgrades.clear()
	table.clear(cuts)
	for session, own in states do
		own.marked = nil
		own.markedAt = nil
		table.clear(own.cutAgain)
		if own.shownBlades ~= 0 and session.upgrades.phantomBlades <= 0 then
			own.shownBlades = 0
			session.player:SetAttribute("PhantomBlades", nil)
		end
	end
end

return AssassinUpgrades
