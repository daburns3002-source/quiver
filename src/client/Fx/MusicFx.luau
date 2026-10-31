--!strict
--[[
	Plays the background music (`Config/Music`) on this client: the Rooms
	playlist, and the Boss playlist while a boss is in the room, fading
	from one to the other. Each playlist plays its tracks in turn, looping.
	A track with a loop region (a boss's battle intro, then its loop) starts
	from the top at full volume each time its playlist comes in, so the
	intro lands like a trainer battle's, then loops round its region.

	Presentation only: whether a boss is there comes from `Fx/BossWatch`,
	which the entry banner shares, so both land on the same tick.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local BossWatch = require(script.Parent.BossWatch)
local Music = require(ReplicatedStorage.Shared.Config.Music)

--[[ The share of its volume the music keeps while a lobby screen is open. ]]
local DUCK = 0.12
local duck = 1

local MusicFx = {}

type Player = { sound: Sound, list: { Music.Track }, index: number, level: number }

local players: { [string]: Player } = {}
local current = "Rooms"
--[[ Everything faded out: the intro's title plays its own music. ]]
local quiet = false

local function load(p: Player, index: number)
	local track = p.list[index]
	p.index = index
	p.sound.SoundId = track.id
	local start, finish = track.loopStart, track.loopEnd
	p.sound.PlaybackRegionsEnabled = start ~= nil and finish ~= nil
	if start and finish then
		p.sound.LoopRegion = NumberRange.new(start, finish)
	end
	-- a lone track (ours are made to loop) or a looping region loops in the engine, with no gap
	p.sound.Looped = p.sound.PlaybackRegionsEnabled or #p.list == 1
end

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
	-- each track plays through, then the next (a looping one never ends)
	sound.Ended:Connect(function()
		load(made, made.index % #made.list + 1)
		sound:Play()
	end)
	players[name] = made
	return made
end

-- A playlist coming in whose track has an intro restarts it at full volume.
local function enter(name: string)
	local p = playerFor(name)
	if not p then
		return
	end
	if p.index == 0 then
		load(p, 1)
	end
	if p.list[p.index].loopStart == nil then
		return
	end
	p.level = 1
	p.sound.TimePosition = 0
	p.sound:Play()
end

local function step(dt: number)
	local rate = dt / math.max(Music.fade, 1e-3)
	-- way down while a lobby screen (Blacksmith, Hatchery, Gear) is open
	-- (owner, 2026-10-26), back up as it closes; the player's `InStation`
	-- and silent under the class select screen (owner, 2026-10-27: "the
	-- music should cut out"), its `ClassSelecting`
	local player = Players.LocalPlayer
	local ducked = player:GetAttribute("InStation") == true
	local duckTo = if player:GetAttribute("ClassSelecting") == true
		then 0
		elseif ducked then DUCK
		else 1
	duck += (duckTo - duck) * math.min(1, dt * 6)
	for name: string in Music.playlists :: { [string]: any } do
		local p = playerFor(name)
		if not p then
			continue
		end
		local target = if name == current and not quiet then 1 else 0
		p.level = math.clamp(p.level + (if target > p.level then rate else -rate), 0, 1)
		if p.level > 0 and not p.sound.IsPlaying then
			if p.index == 0 then
				load(p, 1)
			end
			p.sound:Resume()
			if not p.sound.IsPlaying then
				p.sound:Play()
			end
		elseif p.level <= 0 and p.sound.IsPlaying then
			-- paused, so a room's music picks up where it left off
			p.sound:Pause()
		end
		p.sound.Volume = Music.volume * p.level * duck
	end
end

--[[ While the intro cutscene plays its own music (`UI/IntroCutscene`):
     the run's music waits, then fades in when it ends. ]]
function MusicFx.setQuiet(value: boolean)
	quiet = value
end

function MusicFx.start()
	--[[ The lobby's own (Mossy Glade), before a run; a boss's or the rooms'
	     in a run. ]]
	local boss: string? = nil
	local function choose()
		local was = current
		current = if Workspace:GetAttribute("InLobby") == true
			then "Lobby"
			elseif boss then "Boss"
			else "Rooms"
		if current ~= was then
			enter(current)
		end
	end
	BossWatch.onChange(function(title: string?)
		boss = title
		choose()
	end)
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(choose)
	choose()
	BossWatch.start()
	RunService.Heartbeat:Connect(step)
end

return MusicFx
