--!strict
--[[
	The tutorial's prompts (owner, 2026-11-11: redone; "highlight the important
	words and have the tutorial clearly explain the controls"): the words
	(`Config/Tutorial.prompts`), their marks and colours (`Util/PromptText`),
	and which one shows when (`Util/TutorialSteps`).

	Rules, not wording: a prompt can be rewritten freely, but it must keep its
	control and its action highlighted, stay short, speak to the device it is
	for, and the six things a new player needs must each keep a prompt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PromptText = require(ReplicatedStorage.Shared.Util.PromptText)
local TestRunner = require(script.Parent.TestRunner)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local TutorialSteps = require(ReplicatedStorage.Shared.Util.TutorialSteps)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local DEVICES = { "keyboard", "touch", "gamepad" }

--[[ Words a device must never be told: another device's controls. ]]
local FOREIGN: { [string]: { string } } = {
	keyboard = { "TAP", "THUMB", "STICK", "DRAG" },
	touch = { "SPACE", "W A S D", "ARROW", "CLICK", "KEYS", "STICK", "PRESS" },
	gamepad = { "TAP", "THUMB", "CLICK", "SPACE", "KEYS", "DRAG" },
}

--[[ What each prompt is about: the word that has to be in it. ]]
local ABOUT: { [string]: { string } } = {
	move = { "MOVE" },
	shoot = { "STAND STILL", "SHOOT" },
	crystals = { "CRYSTALS", "XP" },
	dash = { "DASH", "DANGER" },
	gate = { "GATE" },
	card = { "PICK ONE", "CARD" },
}

--[[ Grounds a prompt may be read on: the kit's panel (top and bottom of its
     light, `Config/UiPalette`) and a dark one. ]]
local PANEL = { UiPalette.panelTop, UiPalette.panelBottom }
local BLUE = Color3.fromRGB(34, 70, 186)

local function world(overrides: { [string]: any }?): TutorialSteps.World
	local w: any = {
		room = 1,
		fighting = true,
		cleared = false,
		paused = false,
		walked = 0,
		dashing = false,
	}
	if overrides then
		for key, value in overrides do
			w[key] = value
		end
	end
	return w
end

--[[ Steps `seconds` on in small frames; returns the last prompt shown. ]]
local function run(
	state: TutorialSteps.State,
	w: TutorialSteps.World,
	seconds: number
): TutorialSteps.Id?
	local id: TutorialSteps.Id? = nil
	local dt = 1 / 30
	for _ = 1, math.ceil(seconds / dt) do
		id = TutorialSteps.step(state, w, dt, Tutorial)
	end
	return id
end

--[[ A state with the move prompt already behind it. ]]
local function moved(): TutorialSteps.State
	local state = TutorialSteps.new()
	run(state, world({ walked = Tutorial.moveDistance }), Tutorial.minShow + 0.2)
	return state
end

return function(t: TestRunner.Helper)
	t.test("every step has its prompt, for every device, and no prompt is spare", function()
		local known: { [string]: boolean } = {}
		for _, id in TutorialSteps.ids do
			known[id] = true
			local prompt = Tutorial.prompts[id]
			t.notNil(prompt, id .. " has no words")
			t.isTrue(#prompt.title > 0, id .. " has no heading")
			for _, device in DEVICES do
				t.isTrue(#(prompt :: any)[device] > 0, id .. " says nothing on " .. device)
			end
		end
		for id in Tutorial.prompts do
			t.isTrue(known[id] == true, id .. " is never shown")
		end
	end)

	t.test("every prompt highlights a control and an action, and is short", function()
		for id, prompt in Tutorial.prompts do
			for _, device in DEVICES do
				local text: string = (prompt :: any)[device]
				local where = id .. " (" .. device .. ")"
				t.isTrue(PromptText.valid(text), where .. " has a mark left open")
				local controls, actions = 0, 0
				for _, part in PromptText.runs(text) do
					if part.kind == "control" then
						controls += 1
					elseif part.kind == "action" then
						actions += 1
					end
				end
				t.isTrue(controls >= 1, where .. " highlights no control")
				t.isTrue(actions >= 1, where .. " highlights no action")
				local plain = PromptText.plain(text)
				t.isTrue(
					#plain <= Tutorial.maxLetters,
					where .. " runs to " .. #plain .. " letters"
				)
				t.equal(plain, string.upper(plain), where .. " is not in capitals")
			end
		end
	end)

	t.test("each prompt says the one thing it is for", function()
		for id, words in ABOUT do
			for _, device in DEVICES do
				local plain = PromptText.plain((Tutorial.prompts[id] :: any)[device])
				for _, word in words do
					t.isTrue(
						string.find(plain, word, 1, true) ~= nil,
						id .. " (" .. device .. ") never says " .. word
					)
				end
			end
		end
	end)

	t.test("no device is told another device's controls", function()
		for id, prompt in Tutorial.prompts do
			for _, device in DEVICES do
				local plain = PromptText.plain((prompt :: any)[device])
				for _, word in FOREIGN[device] do
					t.isTrue(
						string.find(plain, word, 1, true) == nil,
						id .. " tells a " .. device .. " player " .. word
					)
				end
			end
		end
	end)

	t.test("marks become colours, and nothing of them is left to read", function()
		local palette = PromptText.palette(BLUE)
		local rich = PromptText.rich("PRESS [SPACE] TO *DASH* <NOW> & GO", palette)
		local _, fonts = string.gsub(rich, "<font color=", "")
		t.equal(fonts, 2)
		t.isTrue(string.find(rich, "[%[%]%*]") == nil, "a mark is still in the text")
		t.isTrue(string.find(rich, "&lt;NOW&gt; &amp; GO", 1, true) ~= nil, "not escaped")
		t.equal(PromptText.plain("PRESS [SPACE] TO *DASH*"), "PRESS SPACE TO DASH")
		t.isFalse(PromptText.valid("PRESS [SPACE TO DASH"))
		t.isFalse(PromptText.valid("PRESS [] TO DASH"))
	end)

	t.test("the highlights and the words stand out on the panel they are read on", function()
		for _, ground in PANEL do
			local palette = PromptText.palette(ground)
			t.isTrue(PromptText.isLight(ground))
			-- no outline on a light panel: the colours carry it alone
			t.isTrue(PromptText.contrast(palette.words, ground) >= 7, "words on the panel")
			t.isTrue(PromptText.contrast(palette.control, ground) >= 4.5, "control on the panel")
			t.isTrue(PromptText.contrast(palette.action, ground) >= 4.5, "action on the panel")
		end
		local dark = PromptText.palette(BLUE)
		t.isFalse(PromptText.isLight(BLUE))
		t.isTrue(PromptText.contrast(dark.words, BLUE) >= 4.5, "words on blue")
		t.isTrue(PromptText.contrast(dark.control, BLUE) >= 4.5, "control on blue")
		t.isTrue(PromptText.contrast(dark.action, BLUE) >= 4.5, "action on blue")
		-- the two highlights must not be mistaken for each other
		for _, palette in { PromptText.palette(PANEL[1]), dark } do
			t.isTrue(palette.control ~= palette.action)
		end
	end)

	t.test("nothing shows before the first room, or while the run is held", function()
		local state = TutorialSteps.new()
		t.isNil(run(state, world({ room = 0 }), 2))
		t.isNil(run(state, world({ paused = true, walked = 5 }), 2))
		-- and a held prompt uses up none of its time, nor counts the walk
		t.equal(state.shown.move, nil)
		t.equal(state.walked, 0)
	end)

	t.test("moving is taught first, until the player has walked and had time to read", function()
		local state = TutorialSteps.new()
		-- walked at once: it still stays its minimum
		t.equal(
			run(state, world({ walked = Tutorial.moveDistance }), Tutorial.minShow * 0.5),
			"move"
		)
		t.isTrue(run(state, world(), Tutorial.minShow) ~= "move")
		-- never walked: it stays, even in a cleared room (the walk to the gate counts)
		local still = TutorialSteps.new()
		t.equal(run(still, world(), Tutorial.minShow * 4), "move")
		t.equal(run(still, world({ fighting = false, cleared = true }), 2), "move")
	end)

	t.test("then shooting, the crystals and the dash, one at a time", function()
		local state = moved()
		t.equal(run(state, world(), 0.5), "shoot")
		-- its time runs only in a fight
		t.isNil(run(state, world({ fighting = false }), Tutorial.shootFor * 2))
		t.equal(run(state, world(), 0.5), "shoot")
		run(state, world(), Tutorial.shootFor)
		-- no crystal yet: on to the dash, and back to the crystals once one drops
		t.equal(run(state, world(), 0.5), "dash")
		TutorialSteps.sawCrystal(state)
		t.equal(run(state, world(), 0.5), "crystals")
		run(state, world(), Tutorial.crystalsFor)
		t.equal(run(state, world(), 0.5), "dash")
		-- a dash sends it away, once it has been up long enough to read
		t.isNil(run(state, world({ dashing = true }), Tutorial.minShow + 0.5))
		t.isNil(run(state, world(), 5))
	end)

	t.test("the first cleared room points at its gate, until the player is through", function()
		local state = moved()
		t.equal(run(state, world({ fighting = false, cleared = true }), 1), "gate")
		t.equal(run(state, world({ fighting = false, cleared = true }), 10), "gate")
		-- the next room: on with the rest, and later clears say nothing of gates
		t.equal(run(state, world({ room = 2 }), 0.5), "shoot")
		local id = run(state, world({ room = 2, fighting = false, cleared = true }), 1)
		t.isTrue(id ~= "gate", "the gate prompt came back")
	end)

	t.test("picking a card is explained over the first hand only", function()
		local state = TutorialSteps.new()
		t.isTrue(TutorialSteps.offer(state))
		t.isFalse(TutorialSteps.offer(state))
	end)
end
