--!strict
--[[
	Soul Chain: the enemies nearest the one hit share in the hit.

	The nearest `link` others within `linkRange` each take `linkShare` of
	the damage, as they always have. Since 2026-11-11 the link is a fireball
	(owner: "soul link should be like brand ult"): it leaps from the enemy
	hit to each linked one in turn (`Shared/Combat/SoulBounce`), and each
	takes its share as the fireball lands on it, a fraction of a second after
	the last, pushed away from where the fireball came from. Every client is
	told the enemies in the order they are visited and when each is reached,
	and draws the leaps (`Fx/Upgrades/SoulFireFx`).

	Who is linked is snapshotted at the hit, for the same reason as splash: a
	kill removes its enemy from the table being read. A share whose enemy has
	died before the fireball arrives is declined by `EnemyManager.damage`,
	like a burn's tick.

	Shared by an arrow or orb landing (`ProjectileSystem`) and a melee blow
	(`MeleeSystem`), since every class can draft the card (owner,
	2026-10-25: "have soul chain for every class not just ranger").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local SoulBounce = require(ReplicatedStorage.Shared.Combat.SoulBounce)

local soulLink = Remotes.event(Remotes.SoulLink)

local SoulLink = {}

--[[ A share on its way: whose, for how much, when the fireball lands, and
     where it leapt from, which is the way the landing pushes. ]]
type Landing = {
	model: Model,
	damage: number,
	owner: Player?,
	at: number,
	from: Vector3,
}

local landings: { Landing } = {}

function SoulLink.apply(
	owner: Player?,
	link: number,
	hit: Model,
	centre: Vector3,
	damage: number,
	now: number
)
	if link <= 0 then
		return
	end

	local config = Balance.Projectile
	local flatCentre = Vector3.new(centre.X, 0, centre.Z)
	local nearby: { { model: Model, position: Vector3, distance: number } } = {}

	for model, position in EnemyManager.positions() do
		if model == hit then
			continue
		end

		local distance = (Vector3.new(position.X, 0, position.Z) - flatCentre).Magnitude
		if distance <= config.linkRange then
			table.insert(nearby, { model = model, position = position, distance = distance })
		end
	end

	if #nearby == 0 then
		return
	end

	table.sort(nearby, function(a, b)
		return a.distance < b.distance
	end)

	local linked: { Vector3 } = {}
	for index = 1, math.min(link, #nearby) do
		table.insert(linked, nearby[index].position)
	end

	--[[ The same enemies as ever; the fireball only chooses the order it
	     visits them in. ]]
	local models: { Model } = {}
	local reached: { Vector3 } = {}
	for _, index in SoulBounce.route(centre, linked) do
		table.insert(models, nearby[index].model)
		table.insert(reached, nearby[index].position)
	end
	local times = SoulBounce.times(centre, reached)

	soulLink:FireAllClients(centre, models, reached, times)

	local from = centre
	for index, model in models do
		table.insert(landings, {
			model = model,
			damage = damage * config.linkShare,
			owner = owner,
			at = now + times[index],
			from = from,
		})
		from = reached[index]
	end
end

--[[ Lands every share whose fireball has arrived. ]]
function SoulLink.step(now: number)
	if #landings == 0 then
		return
	end

	--[[ Taken first: whatever a landing sets off may queue more. ]]
	local due = landings
	landings = {}
	for _, landing in due do
		if now < landing.at then
			table.insert(landings, landing)
			continue
		end

		local _, xp, fell = EnemyManager.damage(landing.model, landing.damage, landing.from)
		RunSession.creditKill(landing.owner, xp, fell)
	end
end

--[[ Drops every fireball still in the air. Called when a room is torn down,
     alongside the burns, so nothing from the last room lands in the next. ]]
function SoulLink.clear()
	table.clear(landings)
end

return SoulLink
