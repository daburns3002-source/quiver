--!strict
--[[
	Falls off the Windswept Cliffs (docs/WINDSWEPT-CLIFFS.md, "The edges";
	owner, 2026-11-26: "Fall: 12% health"). Every push on a player
	(`EnemyManager`'s shove) is read against the room's edges
	(`Arena.edges`, `Shared/Util/CliffEdges`): one whose line leaves the
	floor is a fall, landed as the push would reach the edge. The player is
	put back on the floor they were pushed across, loses 12% of their max
	health (as a hit, so a shield or a dodge can still save them) and is
	untouchable for a second; every client sees the drop
	(`Remotes.PlayerFell`, `Fx/CliffFallFx`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CliffEdges = require(ReplicatedStorage.Shared.Util.CliffEdges)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

local CliffFalls = {}

--[[ Half the player's width: carried this far past an edge, they are over. ]]
local RADIUS = 1

local playerFell = Remotes.event(Remotes.PlayerFell)

type Fall = { at: number, landing: Vector2 }
local pending: { [RunSession.Session]: Fall } = {}

--[[ A push on `session` along `direction` for `distance` studs: a fall
     waiting to land, if it carries them over an edge. ]]
function CliffFalls.pushed(session: RunSession.Session, direction: Vector3, distance: number)
	local on, half, voids = Arena.edges()
	local root = session.root
	if not on or not root or not session.alive or pending[session] then
		return
	end
	local from = Vector2.new(root.Position.X, root.Position.Z)
	local t, landing = CliffEdges.crossing(
		from,
		Vector2.new(direction.X, direction.Z),
		distance,
		half,
		voids,
		RADIUS,
		Arena.coverAt
	)
	if t and landing then
		pending[session] = {
			at = os.clock() + Balance.Shove.duration * math.clamp(t / distance, 0.2, 1),
			landing = landing,
		}
	end
end

function CliffFalls.step(now: number)
	for session, fall in pending do
		if now < fall.at then
			continue
		end
		pending[session] = nil
		local root = session.root
		local character = if root then root.Parent else nil
		if not session.alive or not root or not character or not character:IsA("Model") then
			continue
		end
		character:PivotTo(
			CFrame.new(fall.landing.X, root.Position.Y, fall.landing.Y) * root.CFrame.Rotation
		)
		RunSession.applyDamage(session, session.maxHealth * CliffEdges.share)
		session.invulnerableUntil = math.max(session.invulnerableUntil, now + CliffEdges.grace)
		playerFell:FireAllClients(session.player, Vector3.new(fall.landing.X, 0, fall.landing.Y))
	end
end

--[[ A room ending forgets every fall still on its way. ]]
function CliffFalls.clear()
	table.clear(pending)
end

return CliffFalls
