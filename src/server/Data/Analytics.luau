--!strict
--[[
	Every Roblox `AnalyticsService` event the game sends goes out from here
	(Phase 10, `docs/ROADMAP.md`). The server decides each one; the only
	thing a client says is that the title or the story is on its screen
	(`Remotes.FunnelStep`), which the server cannot see, and that is taken
	only from a player still on the title.

	- **The onboarding funnel** (`LogOnboardingFunnelStepEvent`), in
	  `FUNNEL`'s order: 1 Joined, 2 Title, 3 Story, 4 Tutorial,
	  5 ClassSelect, 6 FirstRun, 7 Cleared1-1, 8 FirstHatch, 9 FirstCrate.
	  Roblox keeps each step once per player, so a step is sent whenever it
	  happens and the first time is what counts. Steps 1 to 6 are sent only
	  for a player who has not beaten 1-1 (`counts`): a returning player
	  sees the title every join and would otherwise walk into the funnel's
	  first steps and no further.
	- **Runs** (`LogProgressionStart/Complete/FailEvent`): the path
	  "Campaign" (the level is the stage's place in `Balance.Stages`, its
	  name "1-3"), "Endless" (the floor reached) or "Tutorial". Field 1 is
	  how it ended: Won, Died, Left (BACK TO LOBBY) or Quit (left the game).
	- **Run length**: custom "RunLength", the seconds as its value; fields:
	  the stage, how it ended, the class.
	- **Deaths**: custom "Death", the room, wave or floor as its value;
	  fields: the stage, where ("Room 4", "Floor 37"), the class.
	- **Card picks**: custom "CardPick", the player's level as its value;
	  fields: the card, its rarity, what dealt it (Level, Angel, ...). Not
	  in the tutorial, whose hands are fixed.
	- **Hatches**: custom "Hatch" for each pet out of an egg; fields: the
	  egg, the pet, how (Bought; Free, a first clear's; Prize, an Endless
	  milestone's or the Soulstone shop's).
	- **Area unlocks**: custom "AreaUnlock" as a boss falls the first time,
	  how many bosses are now beaten as its value; field: the area.

	In Studio each event is also written to the log ("[Analytics] ..."), so
	a playtest can see what would be sent; Roblox records nothing from
	Studio. A failed call is logged once per kind and never stops the game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnalyticsService = game:GetService("AnalyticsService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local log = Log.forTag("Analytics")

local Analytics = {}

--[[ The onboarding funnel's steps, in order: a step's number is its place. ]]
Analytics.FUNNEL = table.freeze({
	"Joined",
	"Title",
	"Story",
	"Tutorial",
	"ClassSelect",
	"FirstRun",
	"Cleared1-1",
	"FirstHatch",
	"FirstCrate",
})
--[[ Steps up to this one are a newcomer's only (`counts`). ]]
Analytics.NEWCOMER_STEPS = 6
--[[ The steps a client may report: what is on its screen and nothing else. ]]
Analytics.CLIENT_STEPS = table.freeze({ Title = true, Story = true })
--[[ `customFields` keys (`Enum.AnalyticsCustomFieldKeys`' names). ]]
local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }
--[[ The longest a field's text is sent. ]]
local FIELD_LENGTH = 40

--[[ A step's number in `FUNNEL`, or nil for a name that is not a step. ]]
function Analytics.stepOf(name: unknown): number?
	if type(name) ~= "string" then
		return nil
	end
	return table.find(Analytics.FUNNEL, name)
end

--[[ Whether step `step` is sent for a player who has (true) or has not
     (false) beaten 1-1, or whose profile is not in yet (nil). ]]
function Analytics.counts(step: number, beaten: boolean?): boolean
	if step > Analytics.NEWCOMER_STEPS then
		return true
	end
	return beaten == false
end

--[[ Up to three custom fields, in order, each as text; nils are left out. ]]
function Analytics.fields(a: any?, b: any?, c: any?): { [string]: string }
	local out: { [string]: string } = {}
	local values: { any } = { a, b, c }
	for index = 1, #FIELD_KEYS do
		local value = values[index]
		if value ~= nil then
			out[FIELD_KEYS[index]] = string.sub(tostring(value), 1, FIELD_LENGTH)
		end
	end
	return out
end

--[[ A run as a progression: its path, level and level name, `reached`
     being the room, wave or floor it got to. ]]
function Analytics.progression(
	stage: Balance.StageConfig,
	index: number,
	reached: number
): (string, number, string)
	if stage.tutorial then
		return "Tutorial", 1, "Tutorial"
	end
	if stage.mode == "Endless" then
		local floor = math.max(1, reached)
		return "Endless", floor, `Floor {floor}`
	end
	return "Campaign", index, stage.level or stage.name
end

--[[ What `send` does instead of calling Roblox, for the spec: each call
     kept, in order. Nil sends for real again. ]]
export type Call = { method: string, player: Player, args: { any } }
local captured: { Call }? = nil

function Analytics.capture(into: { Call }?)
	captured = into
end

local warned: { [string]: boolean } = {}

local function send(method: string, player: Player, ...: any)
	local args = { ... }
	if captured then
		table.insert(captured, { method = method, player = player, args = args })
		return
	end
	local ok, problem = pcall(function()
		(AnalyticsService :: any)[method](AnalyticsService, player, table.unpack(args))
	end)
	if not ok and not warned[method] then
		warned[method] = true
		log.warn("%s failed: %s", method, tostring(problem))
	end
	if RunService:IsStudio() then
		local words = {}
		for _, arg in args do
			if type(arg) ~= "table" then
				table.insert(words, tostring(arg))
			end
		end
		log.info("%s %s: %s", method, player.Name, table.concat(words, " "))
	end
end

--[[ Funnel step `name` for `player`, if it counts for them (`counts`). ]]
function Analytics.step(player: Player, name: string)
	local step = Analytics.stepOf(name)
	if not step then
		return
	end
	local profile = PlayerData.get(player)
	local beaten = if profile then profile.levelsBeaten[Tutorial.untilBeaten] == true else nil
	if Analytics.counts(step, beaten) then
		send("LogOnboardingFunnelStepEvent", player, step, name)
	end
end

--[[ A step a client reports (`Remotes.FunnelStep`): only a `CLIENT_STEPS`
     one. The caller has checked the player is still on the title. ]]
function Analytics.clientStep(player: Player, name: unknown)
	if type(name) == "string" and Analytics.CLIENT_STEPS[name] then
		Analytics.step(player, name)
	end
end

type Run = {
	stage: Balance.StageConfig,
	index: number,
	class: string,
	startedAt: number,
	reached: number,
	place: string,
}
local runs: { [Player]: Run } = {}

--[[ A run of stage `index` starts for `player`, playing `class`. ]]
function Analytics.runStarted(player: Player, index: number, class: string?)
	local stage = Balance.Stages[index]
	if not stage then
		return
	end
	runs[player] = {
		stage = stage,
		index = index,
		class = class or "",
		startedAt = os.clock(),
		reached = 1,
		place = "",
	}
	local path, level, name = Analytics.progression(stage, index, 1)
	send("LogProgressionStartEvent", player, path, level, name, Analytics.fields(class))
end

--[[ The run has got to room, wave or floor `reached`, called `place`
     ("Room 4"). Sends nothing: it is where a death or a quit happened. ]]
function Analytics.reach(player: Player, reached: number, place: string)
	local run = runs[player]
	if run then
		run.reached = reached
		run.place = place
	end
end

--[[ `player`'s run ends: "Won", "Died", "Left" or "Quit". Nothing if no
     run is open, so every way out can call it. ]]
function Analytics.runEnded(player: Player, outcome: string)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	local path, level, name = Analytics.progression(run.stage, run.index, run.reached)
	local method = if outcome == "Won"
		then "LogProgressionCompleteEvent"
		else "LogProgressionFailEvent"
	send(method, player, path, level, name, Analytics.fields(outcome, run.place, run.class))
	local stage = run.stage.level or run.stage.name
	local seconds = math.floor(os.clock() - run.startedAt)
	send(
		"LogCustomEvent",
		player,
		"RunLength",
		seconds,
		Analytics.fields(stage, outcome, run.class)
	)
	if outcome == "Died" then
		send(
			"LogCustomEvent",
			player,
			"Death",
			run.reached,
			Analytics.fields(stage, run.place, run.class)
		)
	end
end

--[[ A card is drafted: its id and rarity, what dealt it, at `level`. ]]
function Analytics.cardPicked(
	player: Player,
	id: string,
	rarity: string,
	source: string,
	level: number
)
	send("LogCustomEvent", player, "CardPick", level, Analytics.fields(id, rarity, source))
end

--[[ Pets out of egg `egg`, `how` they came: "Bought", "Free" or "Prize". ]]
function Analytics.hatched(player: Player, egg: string, results: { any }, how: string)
	for _, result in results do
		send("LogCustomEvent", player, "Hatch", 1, Analytics.fields(egg, result.pet, how))
	end
	if how == "Bought" and #results > 0 then
		Analytics.step(player, "FirstHatch")
	end
end

--[[ `area`'s boss fell for the first time: `beaten` bosses now down. ]]
function Analytics.areaUnlocked(player: Player, area: string, beaten: number)
	send("LogCustomEvent", player, "AreaUnlock", beaten, Analytics.fields(area))
end

function Analytics.start()
	PlayerData.onLoaded(function(player)
		Analytics.step(player, "Joined")
	end)
	Players.PlayerRemoving:Connect(function(player)
		Analytics.runEnded(player, "Quit")
	end)
end

return Analytics
