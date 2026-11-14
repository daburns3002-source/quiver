--!strict
--[[
	Robux developer products (`Config/RobuxStore.products`), granted here and
	nowhere else.

	**Every receipt is granted exactly once.** `MarketplaceService.
	ProcessReceipt` is this module's `processReceipt`: it finds the player and
	the product, waits for the profile, and looks the receipt's `PurchaseId`
	up in the save (`SaveSchema` v15 `purchases.receipts`). A new one is
	granted and written down in the same change, then the profile is saved at
	once (`PlayerData.saveNow`); only a save that landed answers
	`PurchaseGranted`. A failed save answers `NotProcessedYet`, Roblox asks
	again, the id is found and only the save is tried again, so nothing is
	given twice. A player whose profile cannot be saved here (a newer game's
	record) is answered `NotProcessedYet` and granted on a server that can.
	In Studio without DataStores the grant lives in memory, as everything
	there does.

	**Prompts are the server's.** The STORE, the revive and the starter offer
	send `Remotes.StoreBuy` with a key and where it was offered; the server
	checks that it may be sold to this player (`Util/StoreRules.canPrompt`)
	and opens Roblox's prompt. A pass goes to `Data/Passes`.

	**The revive** (DEFEAT only, Robux only): the receipt adds one revive to
	the save and it is spent at once on the run that is waiting
	(`RoomController.revive`, through `Purchases.revive`, the hooks `Main`
	sets). If the run has moved on (a teammate pressed BACK TO LOBBY), it
	stays in the save and the next DEFEAT offers it free. While its prompt
	is open, TRY AGAIN waits (`RoomController.holdForRevive`).

	**The starter pack** is offered once, after the first 1-1 clear
	(`offerStarter`), and bought once; its eggs are hatched on the spot and
	shown as a prize (`UI/EndlessPrize`).

	**VIP's 25 gems a day** are paid here too, on join, when the pass is
	bought, and every few minutes for a day that turns over mid-session.

	Every grant is logged (`Analytics.purchased`).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Analytics = require(script.Parent.Analytics)
local Hatchery = require(script.Parent.Hatchery)
local Passes = require(script.Parent.Passes)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Purchases")

local Purchases = {}

--[[ The run's side of the revive, set by `Main` (this module cannot require
     `Run/RoomController`, which requires it). ]]
export type ReviveHooks = {
	can: (Player) -> boolean,
	apply: (Player) -> boolean,
	hold: (number) -> (),
	release: () -> (),
}
Purchases.revive = nil :: ReviveHooks?

--[[ Where a prompt may say it was opened from, for analytics. ]]
local WHERE = { Store = true, Defeat = true, Starter = true, GearSlot = true }
--[[ Seconds a receipt waits for a joining player's profile. ]]
local PROFILE_WAIT = 15
--[[ Seconds between checks for VIP's next day. ]]
local DAILY_EVERY = 300

local granted = Remotes.event(Remotes.StoreGranted)
local prize = Remotes.event(Remotes.EndlessPrize)

--[[ Where each player's last product prompt was opened from. ]]
local askedFrom: { [Player]: string } = {}
--[[ Receipts whose grant has been shown this session (a retry of one is
     only saved again, never shown twice). ]]
local shown: { [string]: boolean } = {}

--[[ What DEFEAT offers this player: "use" a revive already held, "buy"
     one, or nil (`Util/StoreRules.reviveOffer`). ]]
function Purchases.reviveOffer(player: Player): ("use" | "buy")?
	local hooks = Purchases.revive
	local profile = PlayerData.get(player)
	if not hooks or not profile then
		return nil
	end
	return StoreRules.reviveOffer(profile.purchases, hooks.can(player))
end

--[[ Spends a revive the save holds on the run that is waiting. Returns
     whether the player is back in. ]]
function Purchases.useRevive(player: Player): boolean
	local hooks = Purchases.revive
	local profile = PlayerData.get(player)
	if not hooks or not profile or profile.purchases.reviveCredits <= 0 then
		return false
	end
	if not hooks.can(player) then
		-- kept for the next DEFEAT; the run has moved on and waits for nobody
		hooks.release()
		return false
	end
	-- taken first: the revive yields while the body comes back
	profile.purchases.reviveCredits -= 1
	PlayerData.touch(player)
	local back = hooks.apply(player)
	-- TRY AGAIN waits no longer either way
	hooks.release()
	if back then
		return true
	end
	profile.purchases.reviveCredits += 1
	PlayerData.touch(player)
	return false
end

--[[ What a product gives, into the profile (`Config/RobuxStore`): gems,
     coins, eggs hatched on the spot, the starter pack's once, a revive held.
     Returns the pets the eggs gave, to show. ]]
local function give(
	player: Player,
	profile: SaveSchema.Profile,
	product: RobuxStore.Product
): { any }
	local pets: { any } = {}
	if product.gems then
		Wallet.addGems(player, product.gems)
	end
	if product.coins then
		Wallet.addCoins(player, product.coins)
	end
	local eggs: { RobuxStore.Egg } = product.eggs or {}
	for _, egg in eggs do
		for _, result in Hatchery.grantMany(player, egg.key, egg.count) do
			table.insert(pets, result)
		end
	end
	if product.once then
		profile.purchases.starterBought = true
		profile.purchases.starterOffered = true
	end
	if product.revive then
		profile.purchases.reviveCredits += 1
	end
	return pets
end

--[[ What follows a grant once it is saved: the client is told (the STORE
     says thank you), the eggs are shown, a revive is spent. ]]
local function afterGrant(player: Player, product: RobuxStore.Product, pets: { any })
	granted:FireClient(player, product.key, product.gems or 0)
	if #pets > 0 then
		prize:FireClient(player, -1, string.upper(product.name), pets, {})
	end
	if product.revive then
		task.spawn(Purchases.useRevive, player)
	end
end

--[[ Grants `product` to `player` for receipt `id` unless it already has
     been, and saves. The answer for Roblox. ]]
function Purchases.settle(
	player: Player,
	product: RobuxStore.Product,
	id: string,
	spent: number?
): Enum.ProductPurchaseDecision
	local deadline = os.clock() + PROFILE_WAIT
	while not PlayerData.get(player) and player.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	local profile = PlayerData.get(player)
	if not profile or not player.Parent then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local saves = PlayerData.saves(player)
	if not saves and not RunService:IsStudio() then
		-- nowhere to write it down here: granted on a server that can
		log.warn("receipt %s for %s waits: this profile is not saved here", id, player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchases = profile.purchases
	local pets: { any } = {}
	if not StoreRules.granted(purchases, id) then
		pets = give(player, profile, product)
		StoreRules.keep(purchases, id)
		PlayerData.touch(player)
		log.info("%s bought %s (receipt %s)", player.Name, product.key, id)
		Analytics.purchased(
			player,
			product.key,
			"Product",
			spent or product.robux,
			askedFrom[player]
		)
	end
	if saves and not PlayerData.saveNow(player) then
		log.warn(
			"receipt %s for %s granted but not saved yet: Roblox will ask again",
			id,
			player.Name
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not shown[id] then
		shown[id] = true
		afterGrant(player, product, pets)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[[ `MarketplaceService.ProcessReceipt`. ]]
function Purchases.processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = StoreRules.productById(receipt.ProductId)
	if not product then
		log.warn("receipt for a product not in Config/RobuxStore: %s", tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not player then
		-- gone: Roblox asks again when they are next in a server
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local spent = receipt.CurrencySpent
	return Purchases.settle(
		player,
		product,
		tostring(receipt.PurchaseId),
		if type(spent) == "number" then spent else nil
	)
end

local function promptProduct(player: Player, product: RobuxStore.Product, from: string)
	askedFrom[player] = from
	local ok, problem = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.id)
	end)
	if not ok then
		log.warn("prompt for %s failed: %s", product.key, tostring(problem))
	end
end

--[[ `Remotes.StoreBuy`: the player pressed BUY on `key`, offered `from`.
     The server decides whether to open Roblox's prompt. ]]
function Purchases.ask(player: Player, key: unknown, from: unknown)
	if type(key) ~= "string" then
		return
	end
	local where = if type(from) == "string" and WHERE[from] then from else "Store"
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local product = StoreRules.product(key)
	if product and product.revive then
		local offer = Purchases.reviveOffer(player)
		if offer == "use" then
			task.spawn(Purchases.useRevive, player)
		elseif offer == "buy" then
			local hooks = Purchases.revive
			if hooks then
				hooks.hold(RobuxStore.reviveHold)
			end
			promptProduct(player, product, "Defeat")
		end
		return
	end
	if StoreRules.pass(key) then
		Passes.prompt(player, key, where)
		return
	end
	if product and StoreRules.canPrompt(key, profile.purchases, Passes.owned(player)) then
		promptProduct(player, product, where)
	end
end

--[[ The run's level `level` was just won (`firstClear` the first time):
     whether this is when the starter pack is offered, its one time. Marks
     it offered. ]]
function Purchases.offerStarter(player: Player, level: string?, firstClear: boolean): boolean
	local profile = PlayerData.get(player)
	local product = StoreRules.product("StarterPack")
	if not profile or not product or not StoreRules.live(product) then
		return false
	end
	if not StoreRules.starterDue(profile.purchases, level, firstClear, Tutorial.untilBeaten) then
		return false
	end
	profile.purchases.starterOffered = true
	PlayerData.touch(player)
	return true
end

--[[ VIP's gems for today, if owed. ]]
local function payDaily(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local owned = Passes.owned(player)
	local today = Rewards.today(player)
	if not StoreRules.dailyDue(profile.purchases, today, owned) then
		return
	end
	local gems = StoreRules.dailyGems(owned)
	profile.purchases.vipDay = today
	Wallet.addGems(player, gems)
	granted:FireClient(player, "VIPDaily", gems)
	log.info("%s was paid VIP's %d gems for day %d", player.Name, gems, today)
end

--[[ Studio only (`Remotes.DebugReceipt`): a receipt for `key` as Roblox
     would send it, with purchase id `id` (send the same id twice to see it
     granted once). ]]
local function debugReceipt(player: Player, key: unknown, id: unknown)
	local product = StoreRules.product(key)
	if not product or (type(id) ~= "string" and type(id) ~= "number") then
		return
	end
	local answer = Purchases.settle(player, product, "debug-" .. tostring(id), product.robux)
	log.info("debug receipt %s for %s: %s", tostring(id), product.key, tostring(answer))
end

function Purchases.start()
	MarketplaceService.ProcessReceipt = Purchases.processReceipt
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			local product = StoreRules.productById(productId)
			-- a revive's prompt turned down: TRY AGAIN need not wait on it
			if product and product.revive and not purchased then
				local hooks = Purchases.revive
				if hooks then
					hooks.release()
				end
			end
			local player = Players:GetPlayerByUserId(userId)
			if player and not purchased then
				askedFrom[player] = nil
			end
		end
	)
	Inbound.on(Remotes.StoreBuy, Purchases.ask)
	Inbound.debug(Remotes.DebugReceipt, debugReceipt)
	Inbound.debug(Remotes.DebugPass, Passes.debugSet)
	PlayerData.onLoaded(payDaily)
	Passes.onChanged(function(player)
		-- the third pet slot opens (or shuts) with the pass
		Hatchery.apply(player)
		payDaily(player)
		-- and the open screens redraw (the gear sheet's PET 3)
		Wallet.send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		askedFrom[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(DAILY_EVERY)
			for _, player in Players:GetPlayers() do
				payDaily(player)
			end
		end
	end)
end

return Purchases
