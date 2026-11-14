--!strict
--[[
	Which game passes each player owns (`Config/RobuxStore.passes`), decided
	on the server only: `MarketplaceService.UserOwnsGamePassAsync` as they
	join, and `PromptGamePassPurchaseFinished` when they buy one here. A pass
	is never saved: Roblox is its record.

	The answer is this module's own table; the `Pass<Key>` Player attributes
	only tell the screens (the STORE's OWNED, the gear sheet's PET 3, the
	gold name tag). What a pass does is read through `Util/StoreRules` with
	`Passes.owned(player)`: `Run/RunSession`'s coins, `Data/Wallet`'s pet
	slots, `Data/Purchases`' daily gems.

	A pass still at id 0 (not created on the dashboard yet) is owned by
	nobody. In Studio, `Remotes.DebugPass` sets one on or off for a test.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)

local Analytics = require(script.Parent.Analytics)

local log = Log.forTag("Passes")

local Passes = {}

local owned: { [Player]: StoreRules.Owned } = {}
local listeners: { (Player) -> () } = {}
--[[ Where each player's last pass prompt was opened from, for analytics. ]]
local askedFrom: { [Player]: string } = {}

local function publish(player: Player)
	local mine = owned[player] or {}
	for _, pass in RobuxStore.passes do
		player:SetAttribute(RobuxStore.passAttribute .. pass.key, mine[pass.key] == true)
	end
	for _, listener in listeners do
		task.spawn(listener, player)
	end
end

--[[ This player's passes, by key. Read-only. ]]
function Passes.owned(player: Player): StoreRules.Owned
	return owned[player] or {}
end

function Passes.owns(player: Player, key: string): boolean
	local mine = owned[player]
	return mine ~= nil and mine[key] == true
end

--[[ Called with the player whenever what they own is known or changes. ]]
function Passes.onChanged(listener: (Player) -> ())
	table.insert(listeners, listener)
end

--[[ Asks Roblox for every live pass. A failed ask counts as not owned for
     now and is asked once more a little later. ]]
local function check(player: Player, retry: boolean?)
	local mine = owned[player] or {}
	owned[player] = mine
	local failed = false
	for _, pass in RobuxStore.passes do
		if not StoreRules.live(pass) or mine[pass.key] then
			continue
		end
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok then
			mine[pass.key] = has == true or nil
		else
			failed = true
			log.warn("could not check %s for %s: %s", pass.key, player.Name, tostring(has))
		end
	end
	if not player.Parent then
		return
	end
	publish(player)
	if failed and not retry then
		task.delay(20, function()
			if player.Parent then
				check(player, true)
			end
		end)
	end
end

--[[ Opens Roblox's prompt for a pass not owned; `from` is where it was
     offered, for analytics. ]]
function Passes.prompt(player: Player, key: string, from: string)
	local pass = StoreRules.pass(key)
	if not pass or not StoreRules.canPrompt(key, nil, Passes.owned(player)) then
		return
	end
	askedFrom[player] = from
	local ok, problem = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end)
	if not ok then
		log.warn("prompt for %s failed: %s", key, tostring(problem))
	end
end

--[[ Studio only (`Remotes.DebugPass`): owns `key` or not, without Roblox. ]]
function Passes.debugSet(player: Player, key: unknown, on: unknown)
	local pass = StoreRules.pass(key)
	if not pass then
		return
	end
	local mine = owned[player] or {}
	owned[player] = mine
	mine[pass.key] = on == true or nil
	log.info("debug: %s %s %s", player.Name, if on == true then "owns" else "drops", pass.key)
	publish(player)
end

function Passes.start()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		askedFrom[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		if not purchased then
			return
		end
		local pass = StoreRules.passById(id)
		if not pass or Passes.owns(player, pass.key) then
			return
		end
		local mine = owned[player] or {}
		owned[player] = mine
		mine[pass.key] = true
		log.info("%s bought %s", player.Name, pass.key)
		Analytics.purchased(player, pass.key, "Pass", pass.robux, askedFrom[player])
		askedFrom[player] = nil
		publish(player)
	end)
end

return Passes
