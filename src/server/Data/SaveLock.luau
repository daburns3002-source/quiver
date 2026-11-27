--!strict
--[[
	The session lock on a player's stored record (`Data/PlayerData`): which
	server may load it, and which may write over it.

	A server takes the lock as it loads the record, keeps it fresh with every
	save, and lets it go (writes it empty) as the player leaves. Another
	server loads only a record nobody holds, or one whose lock has gone
	stale (`STALE` seconds without a save: its server died).

	A save writes only over a record this server holds. An empty lock is
	not this server's: it let it go, and a save that lands after that must
	not take it back. On live 2026-11-25 a run server's autosave, queued
	behind the release as the player went back to the lobby, landed after
	it and took the lock again with nobody left to let it go; the lobby
	waited, then sent the player away ("Your progress is still saving
	from your last server").
]]

local SaveLock = {}

--[[ Seconds after a lock's last save that another server may take it. ]]
SaveLock.STALE = 600

export type Lock = { job: string, time: number }

--[[ Whether server `job` may load the record (taking its lock) at `now`. ]]
function SaveLock.mayTake(lock: Lock?, job: string, now: number): boolean
	return lock == nil or lock.job == job or now - (lock.time or 0) >= SaveLock.STALE
end

--[[ Whether server `job` may write its profile over the record: only while
     it holds the lock. ]]
function SaveLock.mayWrite(lock: Lock?, job: string): boolean
	return lock ~= nil and lock.job == job
end

return SaveLock
