--!strict
--[[
	The Robux store's rules (`Config/RobuxStore`), pure, so
	`tests/RobuxStore.spec` pins them: which product or pass an id is, what a
	product gives, whether a receipt has been granted already, what the passes
	add to a run's coins, how many pet slots are open, when VIP's daily gems
	are due and what may be offered to whom.

	The server (`Data/Purchases`, `Data/Passes`) and the screens read the same
	answers; only the server's count.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)

local StoreRules = {}

export type Owned = { [string]: boolean }

--[[ What a player's purchases leave in the save (`SaveSchema` version 15). ]]
export type Purchases = {
	--[[ Receipt ids granted, newest last, at most `RobuxStore.receiptsKept`. ]]
	receipts: { string },
	starterBought: boolean,
	--[[ The starter pack's one offer has been made. ]]
	starterOffered: boolean,
	--[[ Revives bought and not yet used (one bought when it could not be). ]]
	reviveCredits: number,
	--[[ The last whole UTC day VIP's gems were paid, 0 never. ]]
	vipDay: number,
}

function StoreRules.empty(): Purchases
	return {
		receipts = {},
		starterBought = false,
		starterOffered = false,
		reviveCredits = 0,
		vipDay = 0,
	}
end

function StoreRules.product(key: unknown): RobuxStore.Product?
	for _, product in RobuxStore.products do
		if product.key == key then
			return product
		end
	end
	return nil
end

function StoreRules.pass(key: unknown): RobuxStore.Pass?
	for _, pass in RobuxStore.passes do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

--[[ The product a receipt's `ProductId` names; never one still at 0. ]]
function StoreRules.productById(id: unknown): RobuxStore.Product?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	for _, product in RobuxStore.products do
		if product.id == id then
			return product
		end
	end
	return nil
end

function StoreRules.passById(id: unknown): RobuxStore.Pass?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	for _, pass in RobuxStore.passes do
		if pass.id == id then
			return pass
		end
	end
	return nil
end

--[[ Whether it can be bought at all: created on the dashboard. ]]
function StoreRules.live(item: { id: number }): boolean
	return item.id > 0
end

--[[ What the STORE's shelves sell: every product but the revive, which is
     the DEFEAT screen's. The starter pack goes once bought. ]]
function StoreRules.shelf(purchases: Purchases?): { RobuxStore.Product }
	local out = {}
	for _, product in RobuxStore.products do
		if product.revive then
			continue
		end
		if product.once and purchases and purchases.starterBought then
			continue
		end
		table.insert(out, product)
	end
	return out
end

--[[ Whether this player may be prompted for `key` now: a product or a pass
     that exists and is live, the starter pack not yet bought, a pass not yet
     owned. The revive has its own question (`reviveOffer`). ]]
function StoreRules.canPrompt(key: unknown, purchases: Purchases?, owned: Owned): boolean
	local product = StoreRules.product(key)
	if product then
		if product.revive or not StoreRules.live(product) then
			return false
		end
		return not (product.once and purchases ~= nil and purchases.starterBought)
	end
	local pass = StoreRules.pass(key)
	return pass ~= nil and StoreRules.live(pass) and owned[pass.key] ~= true
end

--[[ Whether `id` is in the granted list. ]]
function StoreRules.granted(purchases: Purchases, id: string): boolean
	return table.find(purchases.receipts, id) ~= nil
end

--[[ Writes `id` down as granted, dropping the oldest past `kept`. ]]
function StoreRules.keep(purchases: Purchases, id: string, kept: number?)
	if StoreRules.granted(purchases, id) then
		return
	end
	table.insert(purchases.receipts, id)
	local most = kept or RobuxStore.receiptsKept
	while #purchases.receipts > most do
		table.remove(purchases.receipts, 1)
	end
end

--[[ How much more a run's kill and clear coins are worth with these passes:
     each pass's bonus added to 1 (2x Coins and VIP make 2.1x). ]]
function StoreRules.coinScale(owned: Owned): number
	local scale = 1
	for _, pass in RobuxStore.passes do
		if owned[pass.key] and pass.coinBonus then
			scale += pass.coinBonus
		end
	end
	return scale
end

--[[ Pays `base` coins at `scale`, carrying the fraction to the next payment
     so VIP's tenth is never rounded away on a five-coin kill. Returns the
     whole coins to pay now and the carry left. ]]
function StoreRules.scaleCoins(base: number, scale: number, carry: number): (number, number)
	if base <= 0 then
		return 0, carry
	end
	local exact = base * scale + carry
	local whole = math.floor(exact + 1e-9)
	return whole, math.max(0, exact - whole)
end

--[[ Pet slots open with these passes. ]]
function StoreRules.petSlots(owned: Owned): number
	local slots = RobuxStore.petSlots
	for _, pass in RobuxStore.passes do
		if owned[pass.key] and pass.petSlots then
			slots += pass.petSlots
		end
	end
	return slots
end

--[[ VIP's gems a day, 0 without a pass that pays them. ]]
function StoreRules.dailyGems(owned: Owned): number
	local gems = 0
	for _, pass in RobuxStore.passes do
		if owned[pass.key] and pass.dailyGems then
			gems += pass.dailyGems
		end
	end
	return gems
end

--[[ Whether the daily gems are owed on `today` (whole UTC days since 1970). ]]
function StoreRules.dailyDue(purchases: Purchases, today: number, owned: Owned): boolean
	return StoreRules.dailyGems(owned) > 0 and purchases.vipDay < today
end

--[[ Whether these passes put the gold name tag up. ]]
function StoreRules.nameTag(owned: Owned): boolean
	for _, pass in RobuxStore.passes do
		if owned[pass.key] and pass.nameTag then
			return true
		end
	end
	return false
end

--[[ Whether this clear is the one the starter pack is offered after: the
     first win of `level` where `level` is 1-1, never offered, never bought. ]]
function StoreRules.starterDue(
	purchases: Purchases,
	level: string?,
	firstClear: boolean,
	offerAfter: string
): boolean
	return firstClear
		and level == offerAfter
		and not purchases.starterOffered
		and not purchases.starterBought
end

--[[ What DEFEAT offers: "use" for a revive already held, "buy" for one to
     pay for, nil for none (the run has spent its revive, or the stage has
     none to give). ]]
function StoreRules.reviveOffer(purchases: Purchases?, allowed: boolean): ("use" | "buy")?
	if not allowed then
		return nil
	end
	if purchases and purchases.reviveCredits > 0 then
		return "use"
	end
	local revive = StoreRules.product("Revive")
	if revive and StoreRules.live(revive) then
		return "buy"
	end
	return nil
end

--[[ Whether a run in this state can take a revive at all: lost, not the
     tutorial or the sandbox, and this player's one revive not yet spent. ]]
function StoreRules.reviveAllowed(state: string, tutorial: boolean, used: boolean): boolean
	return state == "Dead" and not tutorial and not used
end

--[[ A save's purchases, read field by field: anything broken is its
     default, and only receipt ids that are text are kept. ]]
function StoreRules.read(raw: unknown): Purchases
	local out = StoreRules.empty()
	if type(raw) ~= "table" then
		return out
	end
	local data = raw :: any
	if type(data.receipts) == "table" then
		for _, id in data.receipts do
			if type(id) == "string" and id ~= "" then
				StoreRules.keep(out, id)
			end
		end
	end
	out.starterBought = data.starterBought == true
	out.starterOffered = data.starterOffered == true or out.starterBought
	local credits = data.reviveCredits
	if type(credits) == "number" and credits == credits and credits > 0 then
		out.reviveCredits = math.floor(credits)
	end
	local day = data.vipDay
	if type(day) == "number" and day == day and day > 0 then
		out.vipDay = math.floor(day)
	end
	return out
end

return StoreRules
