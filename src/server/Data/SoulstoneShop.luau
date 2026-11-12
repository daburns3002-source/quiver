--!strict
--[[
	The Soulstone shop, server side (`Config/SoulstoneShop`,
	`Util/SoulstoneShopRules`; owner, 2026-11-11): eggs and crates for
	Soulstones, the Endless currency.

	`Remotes.SoulstoneBuy` is a request and nothing more. Everything in it
	comes from the client, so everything is checked here against the same
	rules the screen drew from: the offer exists for this player (the egg is
	open to them, the crate has weapons for the class they play), the count
	is one a press may buy, and the Soulstones are there, taken whole or not
	at all (`Wallet.pay`). What comes out is rolled here, as a bought egg or
	crate is (`Data/Hatchery.grantMany`, `Data/EndlessPrizes.crates`), and
	the client is only told what it was (`Remotes.EndlessPrize`, floor 0).
	Asks are spaced `GAP` apart a player, as the hatchery's are.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoulstoneShopRules = require(ReplicatedStorage.Shared.Util.SoulstoneShopRules)

local EndlessPrizes = require(script.Parent.EndlessPrizes)
local Hatchery = require(script.Parent.Hatchery)
local PlayerData = require(script.Parent.PlayerData)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("SoulstoneShop")

local SoulstoneShop = {}

local GAP = 0.35
local lastAsk: { [Player]: number } = {}

local function buy(player: Player, kind: unknown, key: unknown, count: unknown)
	local now = os.clock()
	if now - (lastAsk[player] or -math.huge) < GAP then
		return
	end
	lastAsk[player] = now
	local profile = PlayerData.get(player)
	if not profile or not SoulstoneShopRules.countAllowed(count) then
		return
	end
	local n = count :: number
	local session = RunSession.get(player)
	local class = if session then session.loadout.class else nil
	local offer = SoulstoneShopRules.find(profile.bossesBeaten, class, kind, key)
	if not offer or not Wallet.pay(player, { soulstones = offer.price * n }) then
		return
	end
	local pets, weapons = {}, {}
	if offer.kind == "Egg" then
		pets = Hatchery.grantMany(player, offer.key, n)
	else
		weapons = EndlessPrizes.crates(player, tonumber(offer.key) or 1, n)
	end
	log.info("%s bought %d %s for %d Soulstones", player.Name, n, offer.name, offer.price * n)
	Remotes.event(Remotes.EndlessPrize):FireClient(player, 0, `{n} x {offer.name}`, pets, weapons)
end

function SoulstoneShop.start()
	Remotes.event(Remotes.SoulstoneBuy).OnServerEvent:Connect(buy)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
end

return SoulstoneShop
