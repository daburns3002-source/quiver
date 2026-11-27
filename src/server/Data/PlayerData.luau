--!strict
--[[
	Each player's saved data (`Shared/Util/SaveSchema`): loaded as they
	join, saved every minute, as they leave and as the server shuts down.

	CLAUDE.md non-negotiable 7, saved data is sacred:

	- **Session locked.** The stored record carries the server that holds
	  it. A server only loads a record no other live server holds (a lock
	  goes stale after `SaveLock.STALE` seconds without a save, for a server
	  that died), and only saves over a record it holds (`Data/SaveLock`),
	  never over one it let go. A player who
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
local SaveLock = require(script.Parent.SaveLock)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local log = Log.forTag("Data")

local PlayerData = {}

local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"
--[[ Seconds between saves of every loaded profile. ]]
local AUTOSAVE = 60
--[[ Seconds within which a changed profile is saved. ]]
local SOON = 6
--[[ Tries at taking the lock before the player is asked to rejoin: about
     40 s, for a last server still letting go behind a queue of saves. ]]
local LOAD_TRIES = 10
local LOAD_WAIT = 4

type Record = { profile: SaveSchema.Profile, lock: SaveLock.Lock? }

type Entry = {
	profile: SaveSchema.Profile,
	--[[ False for a record from a newer game version: played, never saved. ]]
	saving: boolean,
	dirty: boolean,
	--[[ No record existed: this player's very first join (`isNew`). ]]
	fresh: boolean,
	--[[ The player is leaving: their last save lets the lock go, and no
	     autosave may follow it. ]]
	leaving: boolean?,
}

local entries: { [Player]: Entry } = {}
local loaded = Instance.new("BindableEvent")
local leaving: { (Player, SaveSchema.Profile) -> () } = {}
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
local function tryLoad(player: Player): (SaveSchema.Profile?, boolean, boolean)
	local current = store
	if not current then
		return SaveSchema.default(), false, true
	end
	local profile: SaveSchema.Profile? = nil
	local saving = true
	local fresh = false
	local ok, problem = pcall(function()
		current:UpdateAsync(key(player), function(old: any): any
			if not SaveLock.mayTake(old and old.lock, jobId, os.time()) then
				profile = nil
				return nil -- held elsewhere: write nothing
			end
			local raw = old and old.profile
			fresh = raw == nil
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
		return nil, false, false
	end
	return profile, saving, fresh
end

local function load(player: Player)
	if not store then
		entries[player] =
			{ profile = SaveSchema.default(), saving = false, dirty = false, fresh = true }
		loaded:Fire(player)
		return
	end
	for _ = 1, LOAD_TRIES do
		local profile, saving, fresh = tryLoad(player)
		if not player.Parent then
			return
		end
		if profile then
			entries[player] = { profile = profile, saving = saving, dirty = false, fresh = fresh }
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
     lets the lock go (the player left, the server is closing). Returns
     whether the record now holds this profile. ]]
local function save(player: Player, release: boolean): boolean
	local entry = entries[player]
	local current = store
	if not entry or not entry.saving or not current then
		return false
	end
	if entry.leaving and not release then
		return false -- only the leaving save, which lets the lock go
	end
	local profile = entry.profile
	local written = false
	local ok, problem = pcall(function()
		current:UpdateAsync(key(player), function(old: any): any
			-- the transform can run more than once; only its last answer stands
			written = false
			if not SaveLock.mayWrite(old and old.lock, jobId) then
				-- not ours: let go already, or taken by another server
				return nil
			end
			if old and not SaveSchema.readable(old.profile) then
				return nil
			end
			local record: Record = {
				profile = profile,
				lock = if release then nil else { job = jobId, time = os.time() },
			}
			written = true
			return record
		end)
	end)
	if not ok then
		entry.dirty = true -- tried again on the next pass
		log.warn("save of %s failed: %s", player.Name, tostring(problem))
		return false
	end
	return written
end

--[[ Saves now and says whether the record holds the profile: what a Robux
     receipt waits on before it is called granted (`Data/Purchases`). A
     profile that is not saved at all (Studio without DataStores, a newer
     game's record) says false, and the caller decides. ]]
function PlayerData.saveNow(player: Player): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	local ok = save(player, false)
	if ok then
		entry.dirty = false
	end
	return ok
end

--[[ Whether this player's profile is written to a DataStore at all. ]]
function PlayerData.saves(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.saving and store ~= nil
end

--[[ The player's profile, or nil until it has loaded. Read-only: change it
     through `Data/Wallet`. ]]
function PlayerData.get(player: Player): SaveSchema.Profile?
	local entry = entries[player]
	return entry and entry.profile
end

--[[ Whether DataStores can be reached at all (decided as `start` runs). ]]
function PlayerData.storeReady(): boolean
	return store ~= nil
end

--[[ Whether this is the player's very first join ever: no record was
     stored for them (`Data/Invites`). In Studio without DataStores every
     join is a first. ]]
function PlayerData.isNew(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.fresh
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

--[[ Calls back as the player leaves, with the profile as it is saved:
     before it is let go, so the callback need not race the save. Called in
     its own thread; it must not change the profile. ]]
function PlayerData.onLeaving(callback: (Player, SaveSchema.Profile) -> ())
	table.insert(leaving, callback)
end

function PlayerData.start()
	openStore()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry then
			entry.leaving = true
			for _, callback in leaving do
				task.spawn(callback, player, entry.profile)
			end
		end
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
				if not entry.leaving and (all or entry.dirty) then
					entry.dirty = false
					task.spawn(save, player, false)
				end
			end
		end
	end)
end

return PlayerData
