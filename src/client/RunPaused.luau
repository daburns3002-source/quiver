--!strict
--[[
	Whether the run is stopped: for a draft, a boss's entry banner, the
	title screen, the story cutscene, a NEW ENEMY! screen or an Endless
	checkpoint.

	One flag, read by everything the client drives itself: movement, firing
	prediction and the dash. It exists as its own module rather than as a
	field on any of them because the failure mode of two copies is that one
	gets cleared and the other does not — and a player who can still walk
	behind the card screen, or who can never shoot again after it, has hit
	exactly that.

	The server stops the world independently; this is the client half. Neither
	trusts the other, and the server's pause is the one that decides outcomes.
]]

local RunPaused = {}

local paused = false
--[[ Held apart from the draft's flag, so the banner ending never clears a
     card screen's pause, nor a pick the banner's. ]]
local intro = false
--[[ And apart again: the title screen (`UI/IntroCutscene`), until BEGIN
     ADVENTURE is pressed. ]]
local title = false
--[[ And again: a NEW ENEMY! screen (`UI/NewEnemyScreen`), until GOT IT!. ]]
local meeting = false
--[[ And again: the story cutscene after BEGIN ADVENTURE (`UI/StoryCutscene`),
     until its black screen has held. ]]
local story = false
--[[ And again: an Endless checkpoint (`UI/EndlessCheckpoint`), until a pick
     (`docs/ENDLESS.md`). ]]
local checkpoint = false
local changed = Instance.new("BindableEvent")

function RunPaused.get(): boolean
	return paused or intro or title or meeting or story or checkpoint
end

--[[ Idempotent, so callers can set it from several places without having to
     know whether it was already set — which they do: a draft opens from an
     offer and closes from either a grant or a death. ]]
function RunPaused.set(value: boolean)
	if paused == value then
		return
	end

	local was = RunPaused.get()
	paused = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ While a boss's entry banner plays (`UI/BossBanner`): nobody moves or
     attacks until it has gone. The server holds the world for the same
     banner (`EnemyManager.introHolding`). ]]
function RunPaused.setIntro(value: boolean)
	if intro == value then
		return
	end

	local was = RunPaused.get()
	intro = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ While the intro's title screen waits for BEGIN ADVENTURE. The server
     holds the world for it too (`RunSession.anyAtTitle`). ]]
function RunPaused.setTitle(value: boolean)
	if title == value then
		return
	end

	local was = RunPaused.get()
	title = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ While a NEW ENEMY! screen is up. The server holds the world for it too
     (`RunSession.anyMeeting`). ]]
function RunPaused.setMeeting(value: boolean)
	if meeting == value then
		return
	end

	local was = RunPaused.get()
	meeting = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ While the story cutscene plays. The server holds the world for it too:
     the player stays on the title (`RunSession.anyAtTitle`) until it ends. ]]
function RunPaused.setStory(value: boolean)
	if story == value then
		return
	end

	local was = RunPaused.get()
	story = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ While an Endless checkpoint's screen is up. The server holds the world
     for it too (`RoomController.atCheckpoint`). ]]
function RunPaused.setCheckpoint(value: boolean)
	if checkpoint == value then
		return
	end

	local was = RunPaused.get()
	checkpoint = value
	if RunPaused.get() ~= was then
		changed:Fire(RunPaused.get())
	end
end

--[[ Fired on every change, so a listener can clear the state that only makes
     sense while the run is moving — a settle timer, say. ]]
function RunPaused.onChanged(callback: (boolean) -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

return RunPaused
