--!strict
--[[
	The trails on the server (`Config/Trails`): the gear sheet's BUY and
	EQUIP, and the trails a profile has earned given as it loads.

	- `Remotes.TrailBuy(key)`: pays a bought trail's gems
	  (`TrailRules.price`) once its area is on sale, and gives it.
	- `Remotes.TrailEquip(key | nil)`: wears a held trail, or none.

	Boss trails and Starfall are never bought: `Data/Wallet` gives them as
	the boss falls and as a class reaches its floor (`Wallet.settleTrails`).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)

local PlayerData = require(script.Parent.PlayerData)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Trails")

local TrailsServer = {}

--[[ Seconds between one player's asks, as the shop's (`Data/Shop`). ]]
local GAP = 0.35
local lastAsk: { [Player]: number } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastAsk[player] or -math.huge) < GAP then
		return false
	end
	lastAsk[player] = now
	return PlayerData.get(player) ~= nil
end

local function buy(player: Player, key: unknown)
	if type(key) ~= "string" or not allowed(player) then
		return
	end
	local profile = PlayerData.get(player)
	local price = TrailRules.price(key)
	if
		not profile
		or not price
		or profile.trails[key]
		or not TrailRules.onSale(key, profile.bossesBeaten)
	then
		return
	end
	if Wallet.pay(player, { gems = price }) then
		Wallet.grantTrail(player, key)
		log.info("%s bought the %s trail for %d gems", player.Name, key, price)
	end
end

local function equip(player: Player, key: unknown)
	if (key ~= nil and type(key) ~= "string") or not allowed(player) then
		return
	end
	Wallet.equipTrail(player, key :: string?)
end

function TrailsServer.start()
	Remotes.event(Remotes.TrailBuy).OnServerEvent:Connect(buy)
	Remotes.event(Remotes.TrailEquip).OnServerEvent:Connect(equip)
	PlayerData.onLoaded(function(player)
		Wallet.settleTrails(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
end

return TrailsServer
