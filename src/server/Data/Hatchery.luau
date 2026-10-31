--!strict
--[[
	The egg hatchery and the pets taken into runs (`Config/Eggs`,
	`Util/EggRules`), on the server: the client asks, this decides. Every
	hatch is rolled here with the server's own `Random` (CLAUDE.md
	non-negotiable 2), every egg paid whole through `Data/Wallet`.

	- `Remotes.HatchEgg(key, count)`: pays `count` eggs (1 or 3), rolls each,
	  keeps every pet (a second of one is counted, for fusing later), and
	  answers `EggHatched`.
	- `Remotes.EquipPet(slot, pet)`: an owned pet into slot 1 or 2, or nil to
	  empty it; saved.

	The pets in a player's slots are their `Pet` and `Pet2` attributes
	(`Config/Eggs.slots`), which `Combat/PetCombat` fights with and
	`Fx/PetPreview` walks at heel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)

local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local PlayerData = require(script.Parent.PlayerData)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Hatchery")

local Hatchery = {}

--[[ Seconds between one player's requests, as the shop's. ]]
local GAP = 0.35
local lastAsk: { [Player]: number } = {}
local random = Random.new()
local eggHatched = Remotes.event(Remotes.EggHatched)

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastAsk[player] or -math.huge) < GAP then
		return false
	end
	lastAsk[player] = now
	return PlayerData.get(player) ~= nil
end

--[[ The saved slots onto the Player's attributes. ]]
function Hatchery.apply(player: Player)
	local profile = PlayerData.get(player)
	for slot, attribute in Eggs.slots do
		player:SetAttribute(attribute, if profile then profile.equippedPets[slot] else nil)
	end
end

local function hatch(player: Player, key: unknown, count: unknown)
	if
		type(key) ~= "string"
		or type(count) ~= "number"
		or not table.find(Eggs.counts, count)
		or not allowed(player)
	then
		return
	end
	local n = count :: number
	local profile = PlayerData.get(player)
	local egg = EggRules.find(key)
	local pool = EggRules.pool(key)
	if not profile or not egg or #pool == 0 or not EggRules.open(egg, profile.bossesBeaten) then
		return
	end
	if not Wallet.pay(player, { coins = egg.price * n }) then
		return
	end
	local results = {}
	local firstFree = profile.equippedPets[1] == nil
	local mythics = Pity.mythics(pool)
	for _ = 1, n do
		-- the 100th egg since the last Mythic hatches one (`Util/Pity`)
		local since = profile.pity.eggs
		local entry = if Pity.forced(since) and #mythics > 0
			then mythics[random:NextInteger(1, #mythics)]
			else EggRules.roll(pool, random:NextNumber())
		if entry then
			profile.pity.eggs = Pity.after(since, entry.rarity == "Mythic")
		end
		if entry then
			local new = Wallet.grantPet(player, entry.pet)
			table.insert(results, { pet = entry.pet, new = new })
		end
	end
	-- a player's very first pet goes straight into slot 1
	if firstFree and next(profile.equippedPets) == nil and results[1] then
		Wallet.equipPet(player, 1, results[1].pet)
		Hatchery.apply(player)
	end
	log.info("%s hatched %d %s", player.Name, n, egg.name)
	eggHatched:FireClient(player, key, results)
end

local function equip(player: Player, slot: unknown, pet: unknown)
	if type(slot) ~= "number" or (pet ~= nil and type(pet) ~= "string") or not allowed(player) then
		return
	end
	Wallet.equipPet(player, slot, pet :: string?)
	Hatchery.apply(player)
end

function Hatchery.start()
	Remotes.event(Remotes.HatchEgg).OnServerEvent:Connect(hatch)
	Remotes.event(Remotes.EquipPet).OnServerEvent:Connect(equip)
	PlayerData.onLoaded(Hatchery.apply)
	--[[ Studio only: a full wallet, the areas opened to try every egg, and
	     the levels beaten that other things wait on (1-10 opens the Endless
	     portal). ]]
	local test = Sandbox.testUnlock
	if RunService:IsStudio() and test then
		PlayerData.onLoaded(function(player)
			Wallet.addCoins(player, test.coins)
			Wallet.addGems(player, test.gems)
			for _, area in test.bosses do
				Wallet.markBeaten(player, area)
			end
			for _, level in test.levels do
				Wallet.beatLevel(player, level)
			end
		end)
	end
	Remotes.event(Remotes.ProfileRequest).OnServerEvent:Connect(function(player)
		if allowed(player) then
			Wallet.send(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
end

return Hatchery
