--!strict
--[[
	The pure rules behind `Data/Analytics`'s recurring funnels and economy
	events (the launch's, owner 2026-11-20: "i also need funnels set up for
	the launch as well"), so `tests/AnalyticsRules.spec` pins them without
	Roblox. Nothing here sends anything.

	- **Recurring funnels** (`LogFunnelStepEvent`, `FUNNELS`): each visit is
	  its own traversal, a fresh `funnelSessionId` the server makes. Roblox
	  allows 10 funnels a game, the onboarding one among them.
	- **Screens** (`SCREENS`): what a client may say it opened
	  (`Remotes.ScreenOpened`), the one thing the server cannot see. A
	  funnel's screen starts its traversal; any other is a "ScreenOpen"
	  custom event.
	- **Economy** (`LogEconomyEvent`, `economy`): every coin, gem and
	  Soulstone the server gives or takes names why (`SOURCES`, `SINKS`),
	  which is its transaction type; its `sku` says which (the egg, the
	  product, the level). A change with no why (a Studio test wallet) is
	  not logged. Coins picked up in a run and Endless's Soulstones are
	  many small grants, so they are summed and sent once as the run ends
	  (`BATCHED`), well under Roblox's rate limit.
]]

local AnalyticsRules = {}

--[[ Each recurring funnel's steps, in order: a step's number is its place. ]]
AnalyticsRules.FUNNELS = table.freeze({
	-- the STORE screen: opened, BUY pressed and Roblox's prompt up, bought
	RobuxStore = table.freeze({ "Opened", "Prompted", "Bought" }),
	-- a Robux prompt anywhere else (DEFEAT's revive, the starter pack, a
	-- gear slot, the season pass, the egg screen's coins): one traversal each
	RobuxOffer = table.freeze({ "Prompted", "Bought" }),
	-- the egg hatchery: walked up and opened, hatched, hatched again
	EggHatch = table.freeze({ "Opened", "Hatched", "HatchedAgain" }),
	-- the Blacksmith's crates: opened, pulled, pulled again
	CratePull = table.freeze({ "Opened", "Pulled", "PulledAgain" }),
})

--[[ The screens a client may report, each to its funnel, or `false` for a
     "ScreenOpen" custom event (which screens are used at all). Station
     names are `UI/StationScreen`'s; the STORE is "Store". ]]
AnalyticsRules.SCREENS = table.freeze({
	Store = "RobuxStore",
	EggHatchery = "EggHatch",
	Blacksmith = "CratePull",
	GearStation = false,
	Rewards = false,
	DexHall = false,
	Badges = false,
	Settings = false,
} :: { [string]: string | false })

--[[ The currencies, by profile field, as the dashboard names them. Roblox
     allows 10; boss items are not one (they are items, many kinds). ]]
AnalyticsRules.CURRENCIES = table.freeze({
	table.freeze({ key = "coins", name = "Coins" }),
	table.freeze({ key = "gems", name = "Gems" }),
	table.freeze({ key = "soulstones", name = "Soulstones" }),
})

--[[ Why the server gives currency, each to its transaction type
     (`Enum.AnalyticsEconomyTransactionType` names where one fits). ]]
AnalyticsRules.SOURCES = table.freeze({
	Run = "Gameplay", -- coins picked up in a run (batched)
	Chest = "Gameplay", -- a Victory chest
	HardClear = "Gameplay", -- a level's first Hard clear
	ClassLevel = "Gameplay", -- a class level's gift
	Boss = "Gameplay", -- a boss win
	Endless = "Gameplay", -- Endless floors and checkpoints (batched)
	Milestone = "Gameplay", -- an Endless milestone, once per account
	Tournament = "Gameplay", -- a weekly tournament's prize
	Pick = "Gameplay", -- gems for a set weapon pick with nothing left to pick
	Swap = "Gameplay", -- gems for an egg or crate that cannot be opened yet
	Quest = "Gameplay", -- a daily quest, the quests' chest
	Goal = "Gameplay", -- a goal's step
	Stars = "Gameplay", -- an area's star chest
	Dex = "Gameplay", -- a new Dex entry, a Dex page's chest
	Season = "Gameplay", -- season pass tiers
	Login = "TimedReward", -- the daily login gift
	Playtime = "TimedReward", -- a playtime gift
	Rewards = "TimedReward", -- CLAIM ALL on the rewards board
	VIP = "TimedReward", -- VIP's gems a day
	Starter = "Onboarding", -- a starter quest
	Invite = "Invite", -- a friend invite's reward
	Code = "Code", -- a code redeemed (sku: the code)
	Robux = "IAP", -- a developer product (sku: its `Config/RobuxStore` key)
})

--[[ Why the server takes currency, each to its transaction type. ]]
AnalyticsRules.SINKS = table.freeze({
	Egg = "Shop", -- eggs hatched (sku: the egg)
	Crate = "Shop", -- a crate pulled (sku: the crate)
	Weapon = "Shop", -- a store weapon bought outright
	Trail = "Shop", -- a trail bought
	SoulstoneShop = "Shop", -- the Endless Soulstone shop
})

--[[ The sources summed per run and sent once as it ends. ]]
AnalyticsRules.BATCHED = table.freeze({ Run = true, Endless = true })

--[[ A rewards board claim's kind (`Data/Rewards`) to why it pays. ]]
AnalyticsRules.CLAIMS = table.freeze({
	all = "Rewards",
	login = "Login",
	quest = "Quest",
	starter = "Starter",
	goal = "Goal",
	page = "Dex",
	stars = "Stars",
	playtime = "Playtime",
})

--[[ The longest a sku is sent. ]]
local SKU_LENGTH = 40

export type Amounts = { coins: number?, gems: number?, soulstones: number? }
export type Balances = { coins: number, gems: number, soulstones: number }
export type Entry = {
	flow: string,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string,
}

--[[ A step's number in `funnel`, or nil for a funnel or a step that is not
     one. ]]
function AnalyticsRules.stepOf(funnel: string, name: string): number?
	local steps = (AnalyticsRules.FUNNELS :: any)[funnel]
	if not steps then
		return nil
	end
	return table.find(steps, name)
end

--[[ Whether `name` is a screen a client may report, and the funnel it
     opens (nil for a "ScreenOpen" one). ]]
function AnalyticsRules.screen(name: unknown): (boolean, string?)
	if type(name) ~= "string" then
		return false, nil
	end
	local funnel = AnalyticsRules.SCREENS[name]
	if funnel == nil then
		return false, nil
	end
	if type(funnel) == "string" then
		return true, funnel
	end
	return true, nil
end

--[[ The funnel a Robux prompt offered `where` is a step of. ]]
function AnalyticsRules.promptFunnel(where: string?): string
	return if where == nil or where == "Store" then "RobuxStore" else "RobuxOffer"
end

--[[ The step a repeatable action is in its traversal: `first` the first
     time, `again` once `first` is done. ]]
function AnalyticsRules.repeatStep(
	done: { [number]: boolean }?,
	funnel: string,
	first: string,
	again: string
): string
	local n = AnalyticsRules.stepOf(funnel, first)
	if done and n and done[n] then
		return again
	end
	return first
end

--[[ The economy events for `amounts` given ("Source") or taken ("Sink")
     for `why`, in `CURRENCIES` order, one per currency that moved, with
     the balance after it. None for an unknown why or flow: an untagged
     change is not logged. Amounts are whole and positive, as Roblox wants
     even for a sink. ]]
function AnalyticsRules.economy(
	flow: string,
	why: string,
	sku: string?,
	amounts: Amounts,
	balances: Balances
): { Entry }
	local types: { [string]: string }? = if flow == "Source"
		then AnalyticsRules.SOURCES :: any
		elseif flow == "Sink" then AnalyticsRules.SINKS :: any
		else nil
	local transaction = types and types[why]
	local out: { Entry } = {}
	if not transaction then
		return out
	end
	local name = string.sub(if sku and sku ~= "" then sku else why, 1, SKU_LENGTH)
	for _, currency in AnalyticsRules.CURRENCIES do
		local amount = tonumber((amounts :: any)[currency.key])
		if amount and amount == amount then
			amount = math.floor(amount)
			if amount > 0 and amount < math.huge then
				local balance = tonumber((balances :: any)[currency.key]) or 0
				table.insert(out, {
					flow = flow,
					currency = currency.name,
					amount = amount,
					balance = math.max(math.floor(balance), 0),
					transaction = transaction,
					sku = name,
				})
			end
		end
	end
	return out
end

--[[ Adds `more` into `into`, currency by currency (a batched source). ]]
function AnalyticsRules.add(into: Amounts, more: Amounts): Amounts
	for _, currency in AnalyticsRules.CURRENCIES do
		local amount = tonumber((more :: any)[currency.key])
		if amount and amount == amount and amount > 0 then
			local sum = ((into :: any)[currency.key] or 0) + amount;
			(into :: any)[currency.key] = sum
		end
	end
	return into
end

--[[ What a code try sends as the code: the code itself only once it is
     redeemed, since a word that is not a code is whatever was typed. ]]
function AnalyticsRules.codeWord(result: string, word: string?): string?
	if result == "Ok" and type(word) == "string" then
		return word
	end
	return nil
end

return AnalyticsRules
