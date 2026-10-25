--!strict
--[[
	Soul Chain: the enemies nearest the one hit share in the hit.

	The nearest `link` others within `linkRange` each take `linkShare` of
	the damage — no knockback, since nothing struck them — and every client
	is told to draw the link. Snapshotted first, for the same reason as
	splash: a kill removes its enemy from the table being read.

	Shared by an arrow or orb landing (`ProjectileSystem`) and a melee blow
	(`MeleeSystem`), since every class can draft the card (owner,
	2026-10-25: "have soul chain for every class not just ranger").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

local soulLink = Remotes.event(Remotes.SoulLink)

local SoulLink = {}

function SoulLink.apply(owner: Player?, link: number, hit: Model, centre: Vector3, damage: number)
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

	local reached: { Vector3 } = {}
	for index = 1, math.min(link, #nearby) do
		table.insert(reached, nearby[index].position)
	end

	soulLink:FireAllClients(centre, reached)

	for index = 1, #reached do
		local entry = nearby[index]
		local _, xp, fell = EnemyManager.damage(entry.model, damage * config.linkShare)
		RunSession.creditKill(owner, xp, fell)
	end
end

return SoulLink
