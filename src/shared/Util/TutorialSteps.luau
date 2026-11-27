--!strict
--[[
	Which tutorial prompt is on screen (`UI/TutorialPrompts`,
	`Config/Tutorial.prompts`; owner, 2026-11-11: the tutorial redone, one
	idea per prompt, nothing a new player needs left unsaid). Pure: the
	client feeds it what the player has done, and it answers with one prompt
	or none. `tests/TutorialPrompts.spec` pins the order.

	One at a time, each taught once:

	- `move`     from the first room until the player has walked `moveDistance`
	             (the walk to the gate counts);
	- `gate`     the first time a room is cleared, until the player has gone
	             through its gate;
	- `shoot`    while fighting, for `shootFor` seconds on screen;
	- `crystals` once a crystal has dropped, for `crystalsFor` seconds;
	- `dash`     until the player has dashed.

	Every prompt but the gate's stays at least `minShow` seconds, and none
	shows, or uses up its time, while the run is held (a NEW ENEMY! screen, a
	draft). `card`, over the first upgrade hand, is asked for apart (`offer`):
	it is up while the run is held.
]]

local TutorialSteps = {}

export type Id = "move" | "gate" | "shoot" | "crystals" | "dash" | "card"

--[[ Every prompt there is, in the order a player usually meets them. Each
     needs words in `Config/Tutorial.prompts`. ]]
TutorialSteps.ids = { "move", "shoot", "crystals", "dash", "gate", "card" } :: { Id }

export type Rules = {
	moveDistance: number,
	minShow: number,
	shootFor: number,
	crystalsFor: number,
}

export type World = {
	--[[ The room being played, 0 before the first. ]]
	room: number,
	--[[ Enemies are up, or the room is cleared and its gate open. ]]
	fighting: boolean,
	cleared: boolean,
	--[[ The run is held: a screen is asking for a press. ]]
	paused: boolean,
	--[[ Studs walked since the last step, and whether a dash is under way. ]]
	walked: number,
	dashing: boolean,
}

export type State = {
	taught: { [string]: boolean },
	--[[ Seconds each prompt has been on screen. ]]
	shown: { [string]: number },
	walked: number,
	dashed: boolean,
	crystalSeen: boolean,
	--[[ The room whose gate the gate prompt pointed at. ]]
	gateRoom: number?,
}

function TutorialSteps.new(): State
	return {
		taught = {},
		shown = {},
		walked = 0,
		dashed = false,
		crystalSeen = false,
		gateRoom = nil,
	}
end

--[[ A crystal dropped: the crystals prompt has something to point at. ]]
function TutorialSteps.sawCrystal(state: State)
	state.crystalSeen = true
end

--[[ An upgrade hand opened. True the first time: show the card prompt. ]]
function TutorialSteps.offer(state: State): boolean
	if state.taught.card then
		return false
	end
	state.taught.card = true
	return true
end

local function tick(state: State, id: Id, dt: number): number
	local total = (state.shown[id] or 0) + dt
	state.shown[id] = total
	return total
end

--[[ One frame on: the prompt to show now, or none. ]]
function TutorialSteps.step(state: State, world: World, dt: number, rules: Rules): Id?
	if world.room < 1 or world.paused then
		return nil
	end
	-- a dash at any time counts: whoever has dashed knows how
	if world.dashing then
		state.dashed = true
	end

	if not state.taught.move then
		state.walked += world.walked
		if state.walked >= rules.moveDistance and (state.shown.move or 0) >= rules.minShow then
			state.taught.move = true
		else
			tick(state, "move", dt)
			return "move"
		end
	end

	-- through the gate it pointed at: taught
	if state.gateRoom and world.room ~= state.gateRoom then
		state.taught.gate = true
	end
	if world.cleared and not state.taught.gate then
		state.gateRoom = world.room
		tick(state, "gate", dt)
		return "gate"
	end

	if not state.taught.shoot then
		-- it is about a fight: it waits for one, and its time only runs in one
		if not world.fighting then
			return nil
		end
		if tick(state, "shoot", dt) >= rules.shootFor then
			state.taught.shoot = true
		end
		return "shoot"
	end

	if not state.taught.crystals and state.crystalSeen then
		if tick(state, "crystals", dt) >= rules.crystalsFor then
			state.taught.crystals = true
		end
		return "crystals"
	end

	if not state.taught.dash then
		if state.dashed and (state.shown.dash or 0) >= rules.minShow then
			state.taught.dash = true
			return nil
		end
		tick(state, "dash", dt)
		return "dash"
	end

	return nil
end

return TutorialSteps
