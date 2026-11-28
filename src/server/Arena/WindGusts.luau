--!strict
--[[
	The Windswept Cliffs' Wind Tunnel rooms (docs/WINDSWEPT-CLIFFS.md,
	Levels: from 5-6 on, one fight in three, `Balance.RoomConfig.gust`).
	Every `Balance.WindGust.every` seconds of the fight a gust crosses the
	room, one way and then the other. Every client is told `warn` seconds
	first (`Remotes.WindGust`, `Fx/WindGustFx` draws the streaks), then each
	living player is pushed `push` studs along it, as an enemy's shove
	pushes them (`Remotes.PlayerShoved`): walls and cover stop them, and a
	push over an edge is a fall (`Arena/CliffFalls`). Enemies are not moved.
	`Run/RoomController` starts it as a room goes live, steps it while the
	fight is on and stops it when the room is cleared away.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CliffFalls = require(script.Parent.CliffFalls)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

local WindGusts = {}

local windGust = Remotes.event(Remotes.WindGust)
local playerShoved = Remotes.event(Remotes.PlayerShoved)

local on = false
local nextAt = 0
local strikeAt: number? = nil
local side = 1

--[[ A room goes live at `now`: gusts if it is a Wind Tunnel room. ]]
function WindGusts.start(gust: boolean, now: number)
	on = gust
	nextAt = now + Balance.WindGust.every
	strikeAt = nil
	side = 1
end

function WindGusts.stop()
	on = false
	strikeAt = nil
end

--[[ Whether a gust is on its way (for the specs). ]]
function WindGusts.pending(): boolean
	return strikeAt ~= nil
end

function WindGusts.step(now: number, fighting: boolean)
	if not on then
		return
	end
	--[[ Held while the fight is not on (a card being picked, the room
	     cleared): no gust lands on a player who cannot move. ]]
	if not fighting or RunSession.anyChoosing() then
		strikeAt = nil
		nextAt = math.max(nextAt, now + Balance.WindGust.warn)
		return
	end
	local config = Balance.WindGust
	if strikeAt and now >= strikeAt then
		strikeAt = nil
		local along = Vector3.new(side, 0, 0)
		for _, session in RunSession.all() do
			--[[ Colossus: nothing moves him, a gust neither. ]]
			if session.alive and session.root and session.melee.colossus <= 0 then
				playerShoved:FireClient(session.player, along, config.push)
				CliffFalls.pushed(session, along, config.push)
			end
		end
	end
	if not strikeAt and now >= nextAt then
		side = -side
		nextAt = now + config.every
		strikeAt = now + config.warn
		windGust:FireAllClients(Vector3.new(side, 0, 0), config.warn)
	end
end

return WindGusts
