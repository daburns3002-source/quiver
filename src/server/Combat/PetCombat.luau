--!strict
--[[
	The pets fight (docs/PETS-FOREST.md, Attacks; numbers in
	`Config/PetCombat`, placeholders until the owner balances them).

	A player's pets are their `Pet` and `Pet2` attributes (`Config/Eggs`
	slots, `Config/PetModels` keys), set from the gear screen
	(`Server/Data/Hatchery`) or, in Studio, the sandbox. Each fights on its
	own clock. Every `every` seconds a pet
	attacks from its owner's side: the server decides who it hits and does
	it, and tells the clients (`Remotes.PetAttack`) so the owner's pet plays
	its Attack clip and pieces (`Fx/PetPreview`, `Fx/PetAttackFx`). Its
	targets are chosen when the look's first piece fires (`Config/PetAttacks`).
	A pet that throws a projectile lands each blow as the piece carrying it
	reaches its enemy (`Shared/Combat/PetShots`), so the damage number meets
	the projectile rather than leading it; a target that moves is followed,
	one that dies first loses the blow. Other pets' blows land at once.

	The pet stands at its owner for the server's purposes: it walks at heel,
	and reach is measured from the owner. A pet that dashes (`dash`, the
	Glade Fox) runs from there to each target round the cover
	(`Enemies/Pathing`), and each blow lands as it arrives
	(`Shared/Util/PetDash`); the plan goes to the clients with the attack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Burning = require(script.Parent.Burning)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Pathing = require(script.Parent.Parent.Enemies.Pathing)
local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetDash = require(ReplicatedStorage.Shared.Util.PetDash)
local PetShots = require(ReplicatedStorage.Shared.Combat.PetShots)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RootHold = require(ReplicatedStorage.Shared.Util.RootHold)
local RunSession = require(script.Parent.Parent.Run.RunSession)

type Spec = PetCombatConfig.Spec
type Session = RunSession.Session

local log = Log.forTag("PetCombat")

local PetCombat = {}

type State = {
	pet: string,
	nextAt: number,
	attacks: number,
	--[[ The Toadstool Tot's spore patch, while it lasts. ]]
	patch: Vector3?,
	patchUntil: number,
}

--[[ Each player's pets, by slot. ]]
local states: { [Player]: { [number]: State } } = {}

--[[ The pets in a player's slots that can fight, by slot. ]]
local function petsOf(player: Player): { [number]: string }
	local out = {}
	for slot, attribute in Eggs.slots do
		local pet = player:GetAttribute(attribute)
		if type(pet) == "string" and PetCombatConfig.pets[pet] then
			out[slot] = pet
		end
	end
	return out
end

--[[ Whether `state` is still one of the player's pets in the fight. ]]
local function current(player: Player, state: State): boolean
	local mine = states[player]
	if not mine then
		return false
	end
	for _, held in mine do
		if held == state then
			return true
		end
	end
	return false
end
local petAttack = Remotes.event(Remotes.PetAttack)

local function rootOf(session: Session): BasePart?
	local character = session.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--[[ Live enemies within `range` of `origin`, nearest first. ]]
local function inRange(origin: Vector3, range: number): { { model: Model, position: Vector3 } }
	local out = {}
	for model, position in EnemyManager.positions() do
		local flat = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
		if flat.Magnitude <= range then
			table.insert(out, { model = model, position = position })
		end
	end
	table.sort(out, function(a, b)
		return (a.position - origin).Magnitude < (b.position - origin).Magnitude
	end)
	return out
end

--[[ The enemies a beam `width` studs wide from `origin` toward `toward`
     passes through, out to `range`. ]]
local function inLine(origin: Vector3, toward: Vector3, width: number, range: number): { Model }
	local ahead = Vector3.new(toward.X - origin.X, 0, toward.Z - origin.Z)
	if ahead.Magnitude < 1e-3 then
		return {}
	end
	ahead = ahead.Unit
	local out = {}
	for model, position in EnemyManager.positions() do
		local offset = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
		local along = offset:Dot(ahead)
		if along > 0 and along <= range and (offset - ahead * along).Magnitude <= width / 2 then
			table.insert(out, model)
		end
	end
	return out
end

--[[ One blow, credited to the owner as an arrow's kill is. ]]
local function hit(session: Session, model: Model, amount: number, from: Vector3): boolean
	local landed, xp, fell = EnemyManager.damage(model, amount, from)
	if landed and xp > 0 then
		RunSession.creditKill(session.player, xp, fell)
	end
	return landed
end

--[[ What a pet does to an enemy besides its damage, once a target. ]]
local function afflict(session: Session, pet: string, model: Model, spec: Spec, now: number)
	if spec.slow then
		EnemyManager.slow(model, spec.slow.scale, now + spec.slow.duration)
	end
	if spec.root then
		EnemyManager.root(model, RootHold.seconds(spec.root, EnemyManager.isBoss(model)), pet)
	end
	if spec.burn then
		Burning.ignite(model, spec.burn.rate, spec.burn.duration, session.player, now)
	end
	if spec.mark then
		EnemyManager.mark(model, spec.mark.scale, now + spec.mark.duration)
	end
	if spec.healPerHit then
		RunSession.heal(session, spec.healPerHit)
	end
end

--[[ A piece leaves the pet for `model`, and its blow lands when it gets
     there: on the target wherever it has moved (a homing piece follows
     it), and not at all if it died on the way or the pet was put away. ]]
local function launch(
	player: Player,
	state: State,
	spec: Spec,
	shot: PetAttacks.Shot,
	model: Model,
	amount: number,
	first: boolean
)
	local session = RunSession.get(player)
	local root = session and rootOf(session)
	local position = EnemyManager.positions()[model]
	if not session or not root or not position then
		return
	end
	local from = PetShots.heel(root.CFrame)
	task.delay(PetShots.flight(shot, (position - from).Magnitude), function()
		local now = RunSession.get(player)
		if
			not now
			or not now.alive
			or not current(player, state)
			or not EnemyManager.positions()[model]
		then
			return
		end
		if amount > 0 then
			hit(now, model, amount, from)
		end
		if first then
			afflict(now, state.pet, model, spec, os.clock())
		end
	end)
end

--[[ Everything one attack does to the enemies and to its owner. ]]
local function strike(session: Session, state: State, spec: Spec, origin: Vector3, now: number)
	local targets = inRange(origin, spec.range)
	local nearest = targets[1]
	local struck: { Model } = {}
	if spec.beam and nearest then
		struck = inLine(origin, nearest.position, spec.beam, spec.range)
	elseif spec.damage or spec.root or spec.mark then
		for i = 1, math.min(spec.targets or 1, #targets) do
			table.insert(struck, targets[i].model)
		end
	end

	local shot = PetShots.projectile(state.pet)
	local hits = spec.hits or 1
	for index, model in struck do
		local amount = if spec.damage
			then spec.damage + (if spec.bossDamage and EnemyManager.isBoss(model)
				then spec.bossDamage
				else 0)
			else 0
		if shot then
			-- each blow waits for the piece carrying it to leave, then to fly
			for blow = (index - 1) * hits + 1, index * hits do
				local wait = PetShots.launch(shot, blow) - shot.at
				local first = blow == (index - 1) * hits + 1
				task.delay(wait, launch, session.player, state, spec, shot, model, amount, first)
			end
		else
			for _ = 1, if amount > 0 then hits else 0 do
				hit(session, model, amount, origin)
			end
			afflict(session, state.pet, model, spec, now)
		end
	end

	if spec.heal then
		state.patch = origin
		state.patchUntil = now + spec.heal.duration
	end
	if spec.magnet then
		RunSession.collectCrystals()
	end
	local haste = spec.haste
	if haste and state.attacks % haste.every == 0 then
		session.petHaste = haste.bonus
		session.petHasteUntil = now + haste.duration
	end
end

--[[ Half the width of an enemy's body. ]]
local function radiusOf(model: Model): number
	local hitbox = model:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return math.max(hitbox.Size.X, hitbox.Size.Z) / 2
	end
	return 1
end

--[[ A dashing pet's attack: runs to each target round the cover, the
     blow landing as it arrives, and back. Returns how long it takes, or
     nil with no target it can reach. ]]
local function dashAt(
	player: Player,
	state: State,
	spec: Spec,
	dash: PetDash.Dash,
	origin: Vector3
): number?
	local start = Vector3.new(origin.X, 0, origin.Z)
	local routes: { { Vector3 } } = {}
	local aims: { Vector3 } = {}
	local struck: { Model } = {}
	local from = start
	for _, target in inRange(origin, spec.range) do
		if #struck >= (spec.targets or 1) then
			break
		end
		local land =
			PetDash.landing(from, target.position, radiusOf(target.model) + dash.radius + dash.gap)
		local route = Pathing.find(from, land, dash.radius)
		local finish = route and route[#route]
		if route and finish and (finish - land).Magnitude <= dash.reach then
			table.insert(routes, route)
			table.insert(aims, Vector3.new(target.position.X, 0, target.position.Z))
			table.insert(struck, target.model)
			from = finish
		end
	end
	if #struck == 0 then
		return nil
	end
	local home = Pathing.find(from, start, dash.radius)
	table.insert(routes, if home and #home > 0 then home else { start })
	local plan = PetDash.plan(start, routes, aims, dash)

	petAttack:FireAllClients(player, state.pet, {
		at = Workspace:GetServerTimeNow(),
		plan = plan,
		targets = struck,
	})
	for i, arrive in PetDash.hits(plan) do
		local model = struck[i]
		local route = plan.stops[i].route
		-- struck from where the pet lands, for the knockback
		local landed = Vector3.new(route[#route].X, origin.Y, route[#route].Z)
		task.delay(arrive, function()
			local live = RunSession.get(player)
			if live and live.alive and current(player, state) then
				if spec.damage then
					local amount = spec.damage
						+ (
							if spec.bossDamage and EnemyManager.isBoss(model)
								then spec.bossDamage
								else 0
						)
					for _ = 1, spec.hits or 1 do
						hit(live, model, amount, landed)
					end
				end
				afflict(live, state.pet, model, spec, os.clock())
			end
		end)
	end
	return plan.length
end

--[[ Seconds into the pet's Attack clip its first piece fires: when the
     targets are chosen. ]]
local function leadOf(pet: string): number
	local shots = (PetAttacks :: any)[pet]
	local first = shots and shots[1]
	return if first then first.at else 0
end

--[[ Whether the pet has anything to do now: something in reach, or it
     supports its owner without one. ]]
local function hasWork(spec: Spec, origin: Vector3): boolean
	if spec.heal or spec.magnet then
		return true
	end
	return #inRange(origin, spec.range) > 0
end

--[[ One pet's turn: its clock, its spore patch, its attack. ]]
local function stepPet(
	player: Player,
	session: Session,
	state: State,
	spec: Spec,
	deltaTime: number,
	now: number
)
	-- a guard goes up once a room (`PetCombat.newRoom`), not on the clock
	if spec.guard then
		return
	end
	local root = rootOf(session)
	if not root then
		return
	end
	local origin = root.Position

	-- the spore patch heals while the owner stands in it
	local patch = state.patch
	if patch and spec.heal then
		if now >= state.patchUntil then
			state.patch = nil
		elseif
			(Vector3.new(origin.X - patch.X, 0, origin.Z - patch.Z)).Magnitude
			<= spec.heal.radius
		then
			RunSession.heal(session, spec.heal.perSecond * deltaTime)
		end
	end

	if now < state.nextAt or not hasWork(spec, origin) then
		return
	end
	state.nextAt = now + spec.every
	state.attacks += 1
	local dash = spec.dash
	if dash then
		local length = dashAt(player, state, spec, dash, origin)
		if length then
			-- never off again before it is back
			state.nextAt = math.max(state.nextAt, now + length)
		end
		return
	end
	petAttack:FireAllClients(player, state.pet)
	task.delay(leadOf(state.pet), function()
		local live = RunSession.get(player)
		local at = live and rootOf(live)
		if live and live.alive and at and current(player, state) then
			strike(live, state, spec, at.Position, os.clock())
		end
	end)
end

function PetCombat.step(deltaTime: number, now: number)
	for player, session in RunSession.all() do
		local pets = petsOf(player)
		if not session.alive or next(pets) == nil then
			states[player] = nil
			continue
		end
		local mine = states[player] or {}
		states[player] = mine
		for slot = 1, #Eggs.slots do
			local pet = pets[slot]
			if not pet then
				mine[slot] = nil
				continue
			end
			local spec = PetCombatConfig.pets[pet]
			local held = mine[slot]
			local state: State
			if held and held.pet == pet then
				state = held
			else
				state = {
					pet = pet,
					nextAt = now + spec.every,
					attacks = 0,
					patch = nil,
					patchUntil = 0,
				}
				mine[slot] = state
				-- a guard pet joins with its shell up for this room
				if spec.guard then
					session.petGuard = true
				end
				log.info("%s's %s joins the fight", player.Name, pet)
			end
			stepPet(player, session, state, spec, deltaTime, now)
		end
	end
end

--[[ Raises `session`'s pet's shell if its pet guards (the Mossback Snail's
     Shell Guard): it blocks the next hit (`RunSession.applyDamage`). ]]
function PetCombat.raiseShell(session: Session)
	for _, pet in petsOf(session.player) do
		if PetCombatConfig.pets[pet].guard then
			session.petGuard = true
		end
	end
end

--[[ A room or a wave begins (`Run/RoomController`): every guarding pet's
     shell is up again, once a room. ]]
function PetCombat.newRoom()
	for _, session in RunSession.all() do
		PetCombat.raiseShell(session)
	end
end

function PetCombat.forget(player: Player)
	states[player] = nil
end

return PetCombat
