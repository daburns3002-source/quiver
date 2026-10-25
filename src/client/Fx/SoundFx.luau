--!strict
--[[
	Plays the game's sound effects (`Config/Sounds`) on this client.

	Each sound is one `Sound` in SoundService, played with
	`SoundService:PlayLocalSound`, so plays overlap rather than cut each
	other off. A sound cut from a sprite (`region`) plays its own slice of
	the shared file with `Sound:Play()` instead, which keeps to its playback
	region, so a replay restarts it. A sound with no id yet is silent, so every hook is wired
	before the audio is uploaded. Presentation only.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundFx = {}

local log = Log.forTag("SoundFx")
local instances: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local random = Random.new()

local function instanceFor(name: string, config: Sounds.Sound): Sound
	local existing = instances[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. name
	sound.SoundId = config.id
	sound.Volume = config.volume
	local region = config.region
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
	end
	sound.Parent = SoundService
	instances[name] = sound
	return sound
end

--[[ Plays `name` once, unless it has no id yet or played less than its
     `minGap` ago. ]]
function SoundFx.play(name: string)
	local config = Sounds[name]
	if not config then
		log.warn("no sound named %s", name)
		return
	end
	if config.id == "" then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < config.minGap then
		return
	end
	lastPlayed[name] = now

	local sound = instanceFor(name, config)
	sound.PlaybackSpeed = (config.speed or 1)
		* (1 + random:NextNumber(-config.pitchJitter, config.pitchJitter))
	if config.region then
		sound:Play()
	else
		SoundService:PlayLocalSound(sound)
	end
end

--[[ Loads every sound with an id now, so the first play is not late. ]]
function SoundFx.preload()
	local list = {}
	for name, config in Sounds do
		if config.id ~= "" then
			table.insert(list, instanceFor(name, config))
		end
	end
	if #list > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(list)
		end)
	end
end

return SoundFx
