--!strict
--[[
	The pets fight (docs/PETS-FOREST.md, Attacks; numbers in
	`Config/PetCombat`, placeholders until the owner balances them).

	A player's pet is their `Pet` attribute (a `Config/PetModels` key); only
	the Studio sandbox sets it until Phase 6. Every `every` seconds the pet
	attacks from its owner's side: the server decides who it hits and does
	it, and tells the clients (`Remotes.PetAttack`) so the owner's pet plays
	its Attack clip and pieces (`Fx/PetPreview`, `Fx/PetAttackFx`). The
	blows land when the look's first piece fires (`Config/PetAttacks`), so
	the damage number meets the projectile rather than leading it.

	The pet stands at its owner for the server's purposes: it walks at heel,
	and reach is measured from the owner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Burning = require(script.Parent.Burning)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
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

local states: { [Player]: State } = {}
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

	for _, model in struck do
		if spec.damage then
			local amount = spec.damage
				+ (if spec.bossDamage and EnemyManager.isBoss(model) then spec.bossDamage else 0)
			for _ = 1, spec.hits or 1 do
				hit(session, model, amount, origin)
			end
		end
		if spec.slow then
			EnemyManager.slow(model, spec.slow.scale, now + spec.slow.duration)
		end
		if spec.root then
			EnemyManager.slow(model, 0, now + spec.root)
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

	if spec.heal then
		state.patch = origin
		state.patchUntil = now + spec.heal.duration
	end
	if spec.guard then
		session.petGuard = true
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

--[[ Seconds into the pet's Attack clip its first piece fires: when the
     blows land. ]]
local function leadOf(pet: string): number
	local shots = (PetAttacks :: any)[pet]
	local first = shots and shots[1]
	return if first then first.at else 0
end

--[[ Whether the pet has anything to do now: something in reach, or it
     supports its owner without one. ]]
local function hasWork(spec: Spec, origin: Vector3): boolean
	if spec.heal or spec.guard or spec.magnet then
		return true
	end
	return #inRange(origin, spec.range) > 0
end

function PetCombat.step(deltaTime: number, now: number)
	for player, session in RunSession.all() do
		local pet = player:GetAttribute("Pet")
		local spec = if type(pet) == "string" then PetCombatConfig.pets[pet] else nil
		if not spec or not session.alive then
			states[player] = nil
			continue
		end
		local existing = states[player]
		local state: State
		if existing and existing.pet == pet then
			state = existing
		else
			state = {
				pet = pet :: string,
				nextAt = now + spec.every,
				attacks = 0,
				patch = nil,
				patchUntil = 0,
			}
			states[player] = state
			-- a new pet's shell is not up yet
			session.petGuard = false
			log.info("%s's %s joins the fight", player.Name, state.pet)
		end
		local root = rootOf(session)
		if not root then
			continue
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
			continue
		end
		state.nextAt = now + spec.every
		state.attacks += 1
		petAttack:FireAllClients(player, state.pet)
		task.delay(leadOf(state.pet), function()
			local current = RunSession.get(player)
			local at = current and rootOf(current)
			if current and current.alive and at then
				strike(current, state, spec, at.Position, os.clock())
			end
		end)
	end
end

function PetCombat.forget(player: Player)
	states[player] = nil
end

return PetCombat
