--!strict
--[[
	Each player's saved data (`Shared/Util/SaveSchema`): loaded as they
	join, saved every minute, as they leave and as the server shuts down.

	CLAUDE.md non-negotiable 7, saved data is sacred:

	- **Session locked.** The stored record carries the server that holds
	  it. A server only loads a record no other live server holds (a lock
	  goes stale after `LOCK_STALE` seconds without a save, for a server
	  that died), and only saves over a record it holds. A player who
	  rejoins faster than their last server saved waits for the lock; if it
	  never comes free they are asked to rejoin rather than handed an empty
	  profile that would overwrite their real one.
	- **Versioned.** Every load goes through `SaveSchema.migrate`; a record
	  from a newer version of the game is never written over (the player
	  plays, but nothing saves).
	- **Never a partial write.** Every write is one `UpdateAsync` of the
	  whole record.

	In Studio a separate store is used, so playtests never touch live
	saves, and when the place cannot reach DataStores at all (API access
	off) profiles live in memory only, and say so in the log.

	Changes go through `Data/Wallet`, never straight into a profile.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local log = Log.forTag("Data")

local PlayerData = {}

local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"
--[[ Seconds between saves of every loaded profile. ]]
local AUTOSAVE = 60
--[[ Seconds within which a changed profile is saved. ]]
local SOON = 6
--[[ Seconds after a lock's last save that another server may take it. ]]
local LOCK_STALE = 600
--[[ Tries at taking the lock before the player is asked to rejoin. ]]
local LOAD_TRIES = 6
local LOAD_WAIT = 4

type Lock = { job: string, time: number }
type Record = { profile: SaveSchema.Profile, lock: Lock? }

type Entry = {
	profile: SaveSchema.Profile,
	--[[ False for a record from a newer game version: played, never saved. ]]
	saving: boolean,
	dirty: boolean,
}

local entries: { [Player]: Entry } = {}
local loaded = Instance.new("BindableEvent")
local store: DataStore? = nil
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1e9))

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		log.warn("DataStores unavailable (%s): profiles will not save", tostring(result))
		return
	end
	-- a read proves the place can reach DataStores (Studio needs API access on)
	local reachable = pcall(function()
		(result :: DataStore):GetAsync("probe")
	end)
	if reachable then
		store = result
	else
		log.warn("DataStores unreachable: profiles live in memory only (Studio API access off?)")
	end
end

--[[ Takes the lock and reads the record in one write. Returns the profile,
     whether it may be saved, and false when another live server holds it. ]]
local function tryLoad(player: Player): (SaveSchema.Profile?, boolean)
	local current = store
	if not current then
		return SaveSchema.default(), false
	end
	local profile: SaveSchema.Profile? = nil
	local saving = true
	local ok, problem = pcall(function()
		current:UpdateAsync(key(player), function(old: any): any
			local lock = old and old.lock
			if lock and lock.job ~= jobId and os.time() - (lock.time or 0) < LOCK_STALE then
				profile = nil
				return nil -- held elsewhere: write nothing
			end
			local raw = old and old.profile
			saving = SaveSchema.readable(raw)
			profile = SaveSchema.migrate(raw)
			if not saving then
				return nil -- a newer game's record: leave it as it is
			end
			return { profile = profile, lock = { job = jobId, time = os.time() } }
		end)
	end)
	if not ok then
		log.warn("load of %s failed: %s", player.Name, tostring(problem))
		return nil, false
	end
	return profile, saving
end

local function load(player: Player)
	if not store then
		entries[player] = { profile = SaveSchema.default(), saving = false, dirty = false }
		loaded:Fire(player)
		return
	end
	for _ = 1, LOAD_TRIES do
		local profile, saving = tryLoad(player)
		if not player.Parent then
			return
		end
		if profile then
			entries[player] = { profile = profile, saving = saving, dirty = false }
			if not saving then
				log.warn("%s's save is from a newer version: playing without saving", player.Name)
			end
			loaded:Fire(player)
			return
		end
		task.wait(LOAD_WAIT)
	end
	log.warn("%s's save stayed locked by another server", player.Name)
	player:Kick("Your progress is still saving from your last server. Please rejoin in a minute.")
end

--[[ Writes the profile over the record this server holds; `release`
     lets the lock go (the player left, the server is closing). ]]
local function save(player: Player, release: boolean)
	local entry = entries[player]
	local current = store
	if not entry or not entry.saving or not current then
		return
	end
	local profile = entry.profile
	local ok, problem = pcall(function()
		current:UpdateAsync(key(player), function(old: any): any
			local lock = old and old.lock
			if lock and lock.job ~= jobId and os.time() - (lock.time or 0) < LOCK_STALE then
				return nil -- another server took it: never write over it
			end
			if old and not SaveSchema.readable(old.profile) then
				return nil
			end
			local record: Record = {
				profile = profile,
				lock = if release then nil else { job = jobId, time = os.time() },
			}
			return record
		end)
	end)
	if not ok then
		entry.dirty = true -- tried again on the next pass
		log.warn("save of %s failed: %s", player.Name, tostring(problem))
	end
end

--[[ The player's profile, or nil until it has loaded. Read-only: change it
     through `Data/Wallet`. ]]
function PlayerData.get(player: Player): SaveSchema.Profile?
	local entry = entries[player]
	return entry and entry.profile
end

--[[ Marks the profile changed, for the next save. ]]
function PlayerData.touch(player: Player)
	local entry = entries[player]
	if entry then
		entry.dirty = true
	end
end

--[[ Calls back once the player's profile is in (at once if it already is). ]]
function PlayerData.onLoaded(callback: (Player) -> ())
	loaded.Event:Connect(callback)
	for player in entries do
		task.spawn(callback, player)
	end
end

function PlayerData.start()
	openStore()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		entries[player] = nil
	end)
	game:BindToClose(function()
		local waiting = 0
		for player in entries do
			waiting += 1
			task.spawn(function()
				save(player, true)
				waiting -= 1
			end)
		end
		local deadline = os.clock() + 25
		while waiting > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
	--[[ A changed profile is saved within `SOON` seconds (a purchase is not
	     lost to a crash), and every profile every `AUTOSAVE`, changed or not,
	     to keep its lock fresh. ]]
	task.spawn(function()
		local lastAll = os.clock()
		while true do
			task.wait(SOON)
			local all = os.clock() - lastAll >= AUTOSAVE
			if all then
				lastAll = os.clock()
			end
			for player, entry in entries do
				if all or entry.dirty then
					entry.dirty = false
					task.spawn(save, player, false)
				end
			end
		end
	end)
end

return PlayerData
