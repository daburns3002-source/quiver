--!strict
--[[
	What changes on the day the game opens to players.

	While it is in playtest every built area, its egg and Endless are open to
	a brand-new player, at the owner's word (2026-10-27: "the mossy glade egg
	and thornwood egg should be unlocked for now"; 2026-10-28: "since its
	still in playtest phase, that should just be unlocked for now"). A real
	new player must not be offered the fourth area and Endless on their
	first visit (the 2026-11-11 loop and UI review): each should wait on the
	boss before it and say so.

	`locks` is that one switch. **It is off**, so playtesting is exactly as
	it was. Turning it on is the whole of locking the game for launch: what
	each portal and each egg then waits on is written beside it, as
	`atLaunch` in `Config/Lobby` and `Config/Eggs`, and read through
	`Util/LaunchLocks`, on the server and on the screens alike.
	`tests/LaunchLocks.spec` holds both states.
]]

return table.freeze({
	locks = false,
})
