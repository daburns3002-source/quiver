--!strict
--[[
	Plays the background music (`Config/Music`) on this client: the Rooms
	playlist, and the Boss playlist while a boss is in the room, fading
	from one to the other. Each playlist plays its tracks in turn, looping.

	Presentation only: whether a boss is there is read from the enemies the
	server put in the Workspace (a model with the `Boss` attribute).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Music = require(ReplicatedStorage.Shared.Config.Music)

local MusicFx = {}

type Player = { sound: Sound, list: { Music.Track }, index: number, level: number }

local players: { [string]: Player } = {}
local current = "Rooms"

local function playerFor(name: string): Player?
	local list = (Music.playlists :: any)[name] :: { Music.Track }?
	if not list or #list == 0 then
		return nil
	end
	local existing = players[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. name
	sound.Volume = 0
	sound.Parent = SoundService
	local made: Player = { sound = sound, list = list, index = 0, level = 0 }
	-- each track plays through, then the next
	sound.Ended:Connect(function()
		made.index = made.index % #made.list + 1
		sound.SoundId = made.list[made.index].id
		sound:Play()
	end)
	players[name] = made
	return made
end

local function bossHere(): boolean
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return false
	end
	for _, enemy in enemies:GetChildren() do
		if enemy:GetAttribute("Boss") ~= nil then
			return true
		end
	end
	return false
end

local polled = 0
local function step(dt: number)
	polled += dt
	if polled >= 0.5 then
		polled = 0
		current = if bossHere() then "Boss" else "Rooms"
	end
	local rate = dt / math.max(Music.fade, 1e-3)
	for name: string in Music.playlists :: { [string]: any } do
		local p = playerFor(name)
		if not p then
			continue
		end
		local target = if name == current then 1 else 0
		p.level = math.clamp(p.level + (if target > p.level then rate else -rate), 0, 1)
		if p.level > 0 and not p.sound.IsPlaying then
			if p.index == 0 then
				p.index = 1
				p.sound.SoundId = p.list[1].id
			end
			p.sound:Resume()
			if not p.sound.IsPlaying then
				p.sound:Play()
			end
		elseif p.level <= 0 and p.sound.IsPlaying then
			-- paused, so a room's music picks up where it left off
			p.sound:Pause()
		end
		p.sound.Volume = Music.volume * p.level
	end
end

function MusicFx.start()
	RunService.Heartbeat:Connect(step)
end

return MusicFx
