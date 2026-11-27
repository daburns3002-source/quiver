--!strict
--[[
	What the purchase burst is told, and how big it is (`Config/PurchaseFx`,
	`UI/PurchaseFx`).

	The server sends a `Receipt` over `Remotes.Purchased` once a purchase
	has gone through: what it was paid in, how much, and the rarity of a
	thing bought outright. `Data/Wallet.pay` makes it from the price it has
	just taken, so every coin, gem and Soulstone purchase sends one and a
	refused purchase sends none; `Data/Purchases` and `Data/Passes` make
	the Robux ones. Pure, so `tests/PurchaseRules.spec` pins the sizes.
]]

local Config = require(script.Parent.Parent.Config.PurchaseFx)
local Purse = require(script.Parent.Purse)

export type Paid = "coins" | "gems" | "soulstones" | "robux"
export type Receipt = { paid: Paid, amount: number, rarity: string? }
export type Size = "small" | "big" | "huge"

local PurchaseRules = {}

local PAID: { [string]: boolean } = { coins = true, gems = true, soulstones = true, robux = true }

local function whole(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

--[[ The receipt for a price just paid: in its coins if it has any (a
     Legendary's price is coins and boss items), else its gems, else its
     Soulstones. Nil for a price of nothing, which is no purchase. ]]
function PurchaseRules.fromCost(cost: Purse.Cost, rarity: string?): Receipt?
	local function of(paid: Paid, amount: number?): Receipt?
		local n = whole(amount)
		return if n and n >= 1 then { paid = paid, amount = n, rarity = rarity } else nil
	end
	return of("coins", cost.coins) or of("gems", cost.gems) or of("soulstones", cost.soulstones)
end

--[[ The receipt for a Robux product or pass. ]]
function PurchaseRules.robux(amount: number): Receipt
	return { paid = "robux", amount = whole(amount) or 0 }
end

--[[ What came over the remote as a receipt, or nil if it is not one. ]]
function PurchaseRules.read(raw: unknown): Receipt?
	if type(raw) ~= "table" then
		return nil
	end
	local data = raw :: { [string]: unknown }
	local paid = data.paid
	if type(paid) ~= "string" or not PAID[paid] then
		return nil
	end
	local amount = whole(data.amount)
	if not amount and paid ~= "robux" then
		return nil
	end
	return {
		paid = paid :: Paid,
		amount = amount or 0,
		rarity = if type(data.rarity) == "string" then data.rarity else nil,
	}
end

function PurchaseRules.size(receipt: Receipt): Size
	if receipt.paid == "robux" or (receipt.rarity ~= nil and Config.grand[receipt.rarity]) then
		return "huge"
	end
	local big = Config.big[receipt.paid]
	return if big and receipt.amount >= big then "big" else "small"
end

function PurchaseRules.look(receipt: Receipt): Config.Look
	return Config.sizes[PurchaseRules.size(receipt)]
end

--[[ The price as it leaves the wallet, "-1,500"; nil for Robux, which the
     wallet does not hold. ]]
function PurchaseRules.tag(receipt: Receipt): string?
	if receipt.paid == "robux" then
		return nil
	end
	local text = tostring(receipt.amount)
	repeat
		local formatted, changes = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until changes == 0
	return "-" .. text
end

--[[ Where the burst comes from on a `viewW` by `viewH` screen: the button
     pressed, if a press `age` seconds old is fresh and on the screen, and
     the screen's `centre` otherwise or for Robux. ]]
function PurchaseRules.origin(
	receipt: Receipt,
	viewW: number,
	viewH: number,
	pressX: number?,
	pressY: number?,
	age: number?
): (number, number)
	if
		receipt.paid ~= "robux"
		and pressX
		and pressY
		and age
		and age >= 0
		and age <= Config.pressAge
		and pressX >= 0
		and pressX <= viewW
		and pressY >= 0
		and pressY <= viewH
	then
		return pressX, pressY
	end
	return viewW * Config.centre[1], viewH * Config.centre[2]
end

--[[ Screen points to a sheet pixel on a `viewW` by `viewH` screen: the
     sheet is 1920 x 1080, or 1080 x 1920 held upright (`Chunky.sheet`). ]]
function PurchaseRules.unit(viewW: number, viewH: number): number
	local w, h = if viewH > viewW then 1080 else 1920, if viewH > viewW then 1920 else 1080
	return math.max(math.min(viewW / w, viewH / h), 0.05)
end

--[[ A box `w` by `h` centred on (x, y), moved the least it takes to sit
     inside the screen with `margin` to spare: the word never hangs off an
     edge when the button pressed is near one. Returns its centre. ]]
function PurchaseRules.keepIn(
	x: number,
	y: number,
	w: number,
	h: number,
	viewW: number,
	viewH: number,
	margin: number
): (number, number)
	local function fit(at: number, size: number, view: number): number
		local low, high = margin + size / 2, view - margin - size / 2
		if low > high then
			return view / 2
		end
		return math.clamp(at, low, high)
	end
	return fit(x, w, viewW), fit(y, h, viewH)
end

return PurchaseRules
