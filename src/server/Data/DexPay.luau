--!strict
--[[
	Gems for each new Dex entry (`Config/Rewards.dexGems`, the loop review's
	item 13). Its own small module, under `Data/Wallet`, so every grant of a
	weapon or a pet pays wherever it is granted from, and an enemy met pays
	through `Wallet.meetEnemy`.

	Each entry pays once ever (`RewardRules.payDex`, the profile's
	`rewards.dexPaid`), and only if the Dex Hall really has a slot for it
	(`Util/DexBook`): a benched enemy or a thing with no picture is in no
	book, so it pays nothing. Server only; nothing a client sends reaches it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local DexPay = {}

local toast = Remotes.event(Remotes.RewardToast)

--[[ Every slot the Dex Hall has, "Book:Key" to its name on screen. ]]
local slots: { [string]: string } = {}
local listed = false

local function inDex(book: string, key: string): string?
	if not listed then
		listed = true
		for _, name in DexBook.BOOKS do
			for _, entry in DexBook.entries(name, nil) do
				slots[RewardRules.dexKey(name, entry.key)] = entry.name
			end
		end
	end
	return slots[RewardRules.dexKey(book, key)]
end

--[[ `key` of `book` ("Enemies", "Weapons", "Pets") is this player's now.
     Adds the gems to `profile` if it is a new Dex entry and returns them
     (0 otherwise). The caller marks the profile changed. ]]
function DexPay.pay(player: Player, profile: SaveSchema.Profile, book: string, key: string): number
	local name = inDex(book, key)
	if not name or not RewardRules.payDex(profile.rewards, book, key) then
		return 0
	end
	profile.gems += Rewards.dexGems
	toast:FireClient(player, `NEW DEX ENTRY: {string.upper(name)}`, Rewards.dexGems, 0)
	return Rewards.dexGems
end

return DexPay
