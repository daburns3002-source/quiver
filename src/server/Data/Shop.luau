--!strict
--[[
	The weapon crates and store (`Config/Shop`, `Util/ShopRules`), on the
	server: the client asks, this decides. A crate is rolled here with the
	server's own `Random` (CLAUDE.md non-negotiable 2, like a hatch); every
	price is checked and paid whole through `Data/Wallet`; nothing a client
	says sets a total, a roll or an owned weapon.

	- `Remotes.ShopOpenCrate(index)`: pays the crate, rolls, grants the
	  weapon or pays back `duplicateRefund`, and answers `ShopCrateOpened`.
	- `Remotes.ShopBuy(weapon)`: pays the store's price and grants it.
	- `Remotes.ShopEquip(weapon)`: holds an owned weapon in runs (its class
	  with it), saved; applied at once in the lobby, else from the next run.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local PlayerData = require(script.Parent.PlayerData)
local RoomController = require(script.Parent.Parent.Run.RoomController)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Shop")

local ShopServer = {}

--[[ Seconds between one player's requests: a held button cannot spend a
     wallet faster than the screen can show what happened. ]]
local GAP = 0.35
local lastAsk: { [Player]: number } = {}
local random = Random.new()
local crateOpened = Remotes.event(Remotes.ShopCrateOpened)

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastAsk[player] or -math.huge) < GAP then
		return false
	end
	lastAsk[player] = now
	return PlayerData.get(player) ~= nil
end

--[[ Puts the saved weapon in hand: its class and the weapon itself. ]]
local function hold(player: Player, weapon: string?)
	local session = RunSession.get(player)
	local entry = weapon and ShopRules.find(weapon)
	if not session or not entry then
		return
	end
	session.loadout.class = entry.class
	session.loadout.weapon = entry.weapon
	RunSession.applyLoadout(session)
end

local function openCrate(player: Player, index: unknown)
	if type(index) ~= "number" or not allowed(player) then
		return
	end
	local crate = Shop.crates[index]
	local pool = if crate then ShopRules.cratePool(index) else {}
	if not crate or #pool == 0 then
		return
	end
	if not Wallet.pay(player, { coins = crate.price }) then
		return
	end
	local entry = ShopRules.roll(pool, random:NextNumber(), random:NextNumber())
	if not entry then
		return
	end
	local new = Wallet.grantWeapon(player, entry.weapon)
	local refund = if new then 0 else ShopRules.refund(index)
	if refund > 0 then
		Wallet.addCoins(player, refund)
	end
	log.info(
		"%s opened the %s crate: %s%s",
		player.Name,
		crate.name,
		entry.weapon,
		if new then "" else " (again)"
	)
	crateOpened:FireClient(player, index, entry.weapon, new, refund)
end

local function buy(player: Player, weapon: unknown)
	if type(weapon) ~= "string" or not allowed(player) then
		return
	end
	local entry = ShopRules.find(weapon)
	local price = entry and ShopRules.price(entry)
	if not entry or not price or Wallet.owns(player, weapon) then
		return
	end
	if Wallet.pay(player, price) then
		Wallet.grantWeapon(player, weapon)
	end
end

local function equip(player: Player, weapon: unknown)
	if type(weapon) ~= "string" or not allowed(player) then
		return
	end
	if not ShopRules.find(weapon) or not Wallet.owns(player, weapon) then
		return
	end
	Wallet.equip(player, weapon)
	if RoomController.inLobby() then
		hold(player, weapon)
	end
end

function ShopServer.start()
	Remotes.event(Remotes.ShopOpenCrate).OnServerEvent:Connect(openCrate)
	Remotes.event(Remotes.ShopBuy).OnServerEvent:Connect(buy)
	Remotes.event(Remotes.ShopEquip).OnServerEvent:Connect(equip)
	-- Studio only: fill the wallet to test the shop
	Remotes.event(Remotes.DebugWallet).OnServerEvent:Connect(function(player, coins, gems, items)
		if not RunService:IsStudio() then
			return
		end
		if type(coins) == "number" then
			Wallet.addCoins(player, math.min(coins, 1e6))
		end
		if type(gems) == "number" then
			Wallet.addGems(player, math.min(gems, 1e5))
		end
		if type(items) == "number" then
			for id in Economy.items do
				Wallet.addItem(player, id, math.min(items, 100))
			end
		end
	end)
	-- the saved weapon is in hand from the start
	PlayerData.onLoaded(function(player)
		local profile = PlayerData.get(player)
		if profile and profile.equipped then
			hold(player, profile.equipped)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
end

return ShopServer
