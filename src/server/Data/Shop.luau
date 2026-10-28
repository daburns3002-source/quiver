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

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local Hatchery = require(script.Parent.Hatchery)
local Lobby = require(script.Parent.Parent.Run.Lobby)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
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

local function openCrate(player: Player, index: unknown, count: unknown)
	if
		type(index) ~= "number"
		or type(count) ~= "number"
		or not table.find(Shop.counts, count)
		or not allowed(player)
	then
		return
	end
	local crate = Shop.crates[index]
	local pool = if crate then ShopRules.cratePool(index) else {}
	if not crate or #pool == 0 then
		return
	end
	local n = count :: number
	if not Wallet.pay(player, { coins = crate.price * n }) then
		return
	end
	local profile = PlayerData.get(player)
	local mythics = Pity.mythics(pool)
	local results = {}
	for _ = 1, n do
		-- the 100th crate since the last Mythic is one (`Util/Pity`)
		local since = if profile then profile.pity.crates else 0
		local entry = if Pity.forced(since) and #mythics > 0
			then mythics[random:NextInteger(1, #mythics)]
			else ShopRules.roll(pool, random:NextNumber(), random:NextNumber())
		if entry then
			if profile then
				profile.pity.crates = Pity.after(since, entry.rarity == "Mythic")
			end
			-- a duplicate is a C copy to merge (owner, 2026-10-28), so no refund
			local new = Wallet.grantWeapon(player, entry.weapon)
			log.info(
				"%s opened the %s crate: %s%s",
				player.Name,
				crate.name,
				entry.weapon,
				if new then "" else " (again)"
			)
			table.insert(results, { weapon = entry.weapon, new = new })
		end
	end
	crateOpened:FireClient(player, index, results)
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

--[[ The class the player plays: their saved weapon's, else the one in
     hand. Gear equips only within it (owner, 2026-10-27: "after the player
     chooses their class, it should load them into the game with their
     class only"); `switchClass` changes it. ]]
local function classOf(player: Player): string?
	local profile = PlayerData.get(player)
	local entry = profile and profile.equipped and ShopRules.find(profile.equipped)
	if entry then
		return entry.class
	end
	local session = RunSession.get(player)
	return session and session.loadout.class
end

local function equip(player: Player, weapon: unknown)
	if type(weapon) ~= "string" or not allowed(player) then
		return
	end
	local entry = ShopRules.find(weapon)
	if not entry or not Wallet.owns(player, weapon) or entry.class ~= classOf(player) then
		return
	end
	Wallet.equip(player, weapon)
	if RoomController.inLobby() then
		hold(player, weapon)
	end
end

--[[ The class select screen's CHOOSE: the class's own weapon in hand (the
     class with it), and the look saved. Only the playable classes. ]]
local PLAYABLE = { Ranger = true, Arcanist = true, Warden = true }
local function chooseClass(player: Player, class: unknown, look: unknown)
	if
		type(class) ~= "string"
		or not PLAYABLE[class]
		or type(look) ~= "string"
		or not allowed(player)
	then
		return
	end
	local starter = Classes[class] and Classes[class].weapon
	if not starter or not Wallet.owns(player, starter) then
		return
	end
	Wallet.setLook(player, look)
	Wallet.equip(player, starter)
	if RoomController.inLobby() then
		hold(player, starter)
		-- into the lobby fresh, at its spawn, behind the loading screen
		if player.Character then
			Lobby.place(player.Character)
		end
	end
	log.info("%s chose the %s (%s)", player.Name, class, look)
end

--[[ The gear screen's class switch (owner, 2026-10-27: "the player should
     be able to switch classes in the gear screen", then "the equipped items
     that the player has should reset when switching to a new class"): the
     class's own weapon in hand, the class with it, and both pet slots
     emptied. In the lobby only. ]]
local function switchClass(player: Player, class: unknown)
	if type(class) ~= "string" or not PLAYABLE[class] or not allowed(player) then
		return
	end
	local starter = Classes[class] and Classes[class].weapon
	if not starter or not Wallet.owns(player, starter) or not RoomController.inLobby() then
		return
	end
	if classOf(player) == class then
		return
	end
	Wallet.equip(player, starter)
	for slot = 1, SaveSchema.PET_SLOTS do
		Wallet.equipPet(player, slot, nil)
	end
	Hatchery.apply(player)
	hold(player, starter)
	log.info("%s switched to the %s", player.Name, class)
end

function ShopServer.start()
	Remotes.event(Remotes.ChooseClass).OnServerEvent:Connect(chooseClass)
	Remotes.event(Remotes.SwitchClass).OnServerEvent:Connect(switchClass)
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
