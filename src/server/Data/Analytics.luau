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
	- **Robux purchases** (`Data/Purchases`, `Data/Passes`): custom
	  "Purchase", the price in Robux as its value; fields: what was bought
	  (`Config/RobuxStore` key), "Product" or "Pass", and where it was
	  offered (Store, Defeat, Starter, GearSlot). Sent once a receipt is
	  granted or a pass is bought, never on a prompt. A revive reopens the
	  run its DEFEAT closed (`runRevived`), so the run's real end is still
	  logged.

	- **Recurring funnels** (`LogFunnelStepEvent`, `Util/AnalyticsRules.
	  FUNNELS`), each visit its own traversal with a fresh GUID for its
	  `funnelSessionId`: RobuxStore (Opened, Prompted, Bought), RobuxOffer
	  (Prompted, Bought: a prompt offered anywhere but the STORE), EggHatch
	  (Opened, Hatched, HatchedAgain) and CratePull (Opened, Pulled,
	  PulledAgain). A screen's opening is the client's to say
	  (`Remotes.ScreenOpened`, `opened`), checked against
	  `AnalyticsRules.SCREENS`; every later step is the server's. Other
	  screens (the gear sheet, rewards, the Dex, badges, settings) are a
	  custom "ScreenOpen", the screen as field 1.
	- **Economy** (`LogEconomyEvent`, `earned`, `spent`): every coin, gem
	  and Soulstone given or taken through `Data/Wallet` with a why
	  (`AnalyticsRules.SOURCES`, `SINKS`), with the balance after it. A
	  run's picked-up coins and Endless's Soulstones are summed and sent
	  once as the run ends (`AnalyticsRules.BATCHED`).
	- **Codes**: custom "CodeTry" on every try; fields: the result (Ok,
	  Unknown, Used, ...) and, once redeemed, the code.

	In Studio each event is also written to the log ("[Analytics] ..."), so
	a playtest can see what would be sent; Roblox records nothing from
	Studio. A failed call is logged once per kind and never stops the game.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnalyticsService = game:GetService("AnalyticsService")

local AnalyticsRules = require(ReplicatedStorage.Shared.Util.AnalyticsRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlayerData = require(script.Parent.PlayerData)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local log = Log.forTag("Analytics")

local Analytics = {}

--[[ Coins, gems and Soulstones moved (`earned`, `spent`). ]]
export type Amounts = AnalyticsRules.Amounts

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

--[[ A recurring funnel's traversal: its `funnelSessionId` and the steps
     sent in it (Roblox counts each once per traversal, so a repeat is not
     sent at all). ]]
type Traversal = { id: string, done: { [number]: boolean } }
local traversals: { [Player]: { [string]: Traversal } } = {}
--[[ The Robux prompt last opened for a player: its funnel and key, for
     the Bought step when it is granted. ]]
local prompts: { [Player]: { funnel: string, key: string } } = {}

--[[ A new traversal of `funnel` for `player`, replacing any open one. ]]
local function begin(player: Player, funnel: string): Traversal
	local mine = traversals[player] or {}
	traversals[player] = mine
	local traversal = { id = HttpService:GenerateGUID(false), done = {} }
	mine[funnel] = traversal
	return traversal
end

--[[ Step `name` of `funnel` in `player`'s open traversal (a new one if
     none is open, which counts the steps before it as Roblox does). ]]
local function funnelStep(
	player: Player,
	funnel: string,
	name: string,
	fields: { [string]: string }?
)
	local step = AnalyticsRules.stepOf(funnel, name)
	if not step then
		return
	end
	local mine = traversals[player]
	local traversal = (mine and mine[funnel]) or begin(player, funnel)
	if traversal.done[step] then
		return
	end
	traversal.done[step] = true
	send("LogFunnelStepEvent", player, funnel, traversal.id, step, name, fields or {})
end

--[[ A step that repeats (a hatch, a crate): `first` the first time in the
     traversal, `again` after. ]]
local function repeatStep(
	player: Player,
	funnel: string,
	first: string,
	again: string,
	fields: { [string]: string }
)
	local mine = traversals[player]
	local traversal = mine and mine[funnel]
	funnelStep(
		player,
		funnel,
		AnalyticsRules.repeatStep(traversal and traversal.done, funnel, first, again),
		fields
	)
end

--[[ `Remotes.ScreenOpened`: the client says `screen` is now open. Only an
     `AnalyticsRules.SCREENS` one: a funnel's starts a new traversal, any
     other is a "ScreenOpen" custom event. ]]
function Analytics.opened(player: Player, screen: unknown)
	local known, funnel = AnalyticsRules.screen(screen)
	if not known then
		return
	end
	if funnel then
		begin(player, funnel)
		funnelStep(player, funnel, AnalyticsRules.FUNNELS[funnel][1])
	else
		send("LogCustomEvent", player, "ScreenOpen", 1, Analytics.fields(screen))
	end
end

--[[ Roblox's prompt for `key` (`Config/RobuxStore`) is open for `player`,
     offered `where`: the STORE's traversal's Prompted step, or a
     RobuxOffer traversal of its own. ]]
function Analytics.prompted(player: Player, key: string, where: string?)
	local funnel = AnalyticsRules.promptFunnel(where)
	if funnel ~= "RobuxStore" then
		begin(player, funnel)
	end
	prompts[player] = { funnel = funnel, key = key }
	funnelStep(player, funnel, "Prompted", Analytics.fields(key, where or "Store"))
end

--[[ Crates pulled at the Blacksmith: `n` of `crate`'s `class` chest. ]]
function Analytics.cratePulled(player: Player, crate: string, class: string, n: number)
	repeatStep(player, "CratePull", "Pulled", "PulledAgain", Analytics.fields(crate, class, n))
	Analytics.step(player, "FirstCrate")
end

--[[ A code tried: its result (`Util/CodeRules`) and, if redeemed, it. ]]
function Analytics.codeTried(player: Player, result: string, word: string?)
	send(
		"LogCustomEvent",
		player,
		"CodeTry",
		1,
		Analytics.fields(result, AnalyticsRules.codeWord(result, word))
	)
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
--[[ The run a death closed, kept until the next run starts, in case a
     revive brings it back (`runRevived`). ]]
local fallen: { [Player]: Run } = {}

--[[ The batched sources (`AnalyticsRules.BATCHED`) waiting to be sent,
     per player, by why and sku. ]]
type Batch = { why: string, sku: string?, amounts: AnalyticsRules.Amounts }
local batches: { [Player]: { [string]: Batch } } = {}

--[[ Each economy event of `amounts` moved for `why`, the balance read
     after the change (so the caller calls this once it is made). ]]
local function economy(
	player: Player,
	flow: string,
	why: string,
	sku: string?,
	amounts: AnalyticsRules.Amounts
)
	local whys: { [string]: string } = if flow == "Source"
		then AnalyticsRules.SOURCES :: any
		else AnalyticsRules.SINKS :: any
	if not whys[why] then
		-- a why the rules do not know is a typo: said once, never sent
		if not warned[why] then
			warned[why] = true
			log.warn("no %s called %s in AnalyticsRules", flow, why)
		end
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for _, entry in AnalyticsRules.economy(flow, why, sku, amounts, profile) do
		send(
			"LogEconomyEvent",
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[entry.flow],
			entry.currency,
			entry.amount,
			entry.balance,
			entry.transaction,
			entry.sku
		)
	end
end

--[[ Currency given to `player` for `why` (`AnalyticsRules.SOURCES`),
     `sku` saying which. A batched why waits for the run's end; a run's
     coins are known by its level. ]]
function Analytics.earned(
	player: Player,
	why: string,
	sku: string?,
	amounts: AnalyticsRules.Amounts
)
	if not AnalyticsRules.BATCHED[why] then
		economy(player, "Source", why, sku, amounts)
		return
	end
	local run = runs[player]
	local name = sku or (run and (run.stage.level or run.stage.name)) or nil
	local mine = batches[player] or {}
	batches[player] = mine
	local key = `{why}:{name or ""}`
	local batch = mine[key] or { why = why, sku = name, amounts = {} }
	mine[key] = batch
	AnalyticsRules.add(batch.amounts, amounts)
end

--[[ Currency taken from `player` for `why` (`AnalyticsRules.SINKS`). ]]
function Analytics.spent(player: Player, why: string, sku: string?, amounts: AnalyticsRules.Amounts)
	economy(player, "Sink", why, sku, amounts)
end

--[[ Sends what is batched for `player`, each why and sku as one event. ]]
function Analytics.flush(player: Player)
	local mine = batches[player]
	batches[player] = nil
	if not mine then
		return
	end
	for _, batch in mine do
		economy(player, "Source", batch.why, batch.sku, batch.amounts)
	end
end

--[[ A run of stage `index` starts for `player`, playing `class`. ]]
function Analytics.runStarted(player: Player, index: number, class: string?)
	local stage = Balance.Stages[index]
	if not stage then
		return
	end
	Analytics.flush(player)
	fallen[player] = nil
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
	-- the run's picked-up coins and Soulstones, one event each
	Analytics.flush(player)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	if outcome == "Died" then
		fallen[player] = run
	else
		fallen[player] = nil
	end
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
		repeatStep(player, "EggHatch", "Hatched", "HatchedAgain", Analytics.fields(egg, #results))
		Analytics.step(player, "FirstHatch")
	end
end

--[[ `area`'s boss fell for the first time: `beaten` bosses now down. ]]
function Analytics.areaUnlocked(player: Player, area: string, beaten: number)
	send("LogCustomEvent", player, "AreaUnlock", beaten, Analytics.fields(area))
end

--[[ A revive (`Data/Purchases`) puts `player` back into the run a death
     ended: it is open again, so how it really ends is logged too. ]]
function Analytics.runRevived(player: Player)
	local run = fallen[player]
	if run and not runs[player] then
		runs[player] = run
	end
	fallen[player] = nil
end

--[[ A Robux purchase is granted: `key` from `Config/RobuxStore`, `kind`
     "Product" or "Pass", for `robux`, offered `where`. ]]
function Analytics.purchased(
	player: Player,
	key: string,
	kind: string,
	robux: number,
	where: string?
)
	send("LogCustomEvent", player, "Purchase", robux, Analytics.fields(key, kind, where or "Store"))
	-- the Bought step of the prompt that sold it, if this server opened it
	local prompt = prompts[player]
	if prompt and prompt.key == key then
		prompts[player] = nil
		funnelStep(player, prompt.funnel, "Bought", Analytics.fields(key, where or "Store"))
	end
end

function Analytics.start()
	PlayerData.onLoaded(function(player)
		Analytics.step(player, "Joined")
	end)
	Players.PlayerRemoving:Connect(function(player)
		Analytics.runEnded(player, "Quit")
		Analytics.flush(player)
		fallen[player] = nil
		traversals[player] = nil
		prompts[player] = nil
	end)
end

return Analytics
