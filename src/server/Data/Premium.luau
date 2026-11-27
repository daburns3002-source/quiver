--!strict
--[[
	Roblox Premium's perk (`Config/Rewards.premium`, `Util/PremiumRules`;
	owner, 2026-11-18): a tenth more coins on a run's kills and clears
	(added in `Run/RunSession.payEarned` beside VIP's, nothing multiplies)
	and a free egg once a reward day, the best open to the player.

	Whether a player has Premium is Roblox's word, read here only:
	`Player.MembershipType`, again whenever `PlayerMembershipChanged` says
	it moved (Premium bought in the game). The `Premium` Player attribute
	only tells the screens: the name tag's mark (`UI/NameTags`) and the
	GIFTS tab's panel, whose GET PREMIUM is Roblox's own prompt
	(`MarketplaceService:PromptPremiumPurchase`, `UI/RewardsScreen`).

	**The egg is paid as the player reaches the lobby** (`Arrived`, on a
	lobby server only), not the moment the profile loads: its reveal would
	otherwise play over the title screen or in a run. Marked in the save
	(`premiumDay`) before it is given, so it is given once a day.

	Studio: `Remotes.DebugPremium(on)` treats the player as Premium or not.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PremiumRules = require(ReplicatedStorage.Shared.Util.PremiumRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardConfig = require(ReplicatedStorage.Shared.Config.Rewards)

local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Premium")

local Premium = {}

--[[ Seconds between looks for a new reward day while people play. ]]
local DAY_EVERY = 300
--[[ The Player attribute `RunSession` sets as a player stands in the
     lobby (`RunSession.ARRIVED`; not required here, which would loop). ]]
local ARRIVED = "Arrived"

--[[ Studio's stand-ins, by player; never set on a live server. ]]
local overrides: { [Player]: boolean } = {}

--[[ Whether `player` has Roblox Premium. ]]
function Premium.has(player: Player): boolean
	local override = overrides[player]
	if override ~= nil then
		return override
	end
	return player.MembershipType == Enum.MembershipType.Premium
end

local function publish(player: Player)
	player:SetAttribute(PremiumRules.ATTRIBUTE, Premium.has(player))
end

--[[ Today's free egg, if owed and the player stands in the lobby. ]]
local function payEgg(player: Player)
	local profile = PlayerData.get(player)
	if not profile or player:GetAttribute(ARRIVED) ~= true then
		return
	end
	local today = Rewards.today(player)
	if not PremiumRules.eggDue(profile.premiumDay, today, Premium.has(player)) then
		return
	end
	profile.premiumDay = today
	log.info("%s is paid Premium's egg for day %d", player.Name, today)
	Rewards.say(player, "PREMIUM: A FREE EGG FOR TODAY!")
	Rewards.pay(player, { eggs = RewardConfig.premium.eggs })
end

local function watch(player: Player)
	publish(player)
	player:GetAttributeChangedSignal(ARRIVED):Connect(function()
		payEgg(player)
	end)
end

function Premium.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerMembershipChanged:Connect(function(player)
		publish(player)
		payEgg(player)
		-- the GIFTS tab's panel redraws
		Wallet.send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		overrides[player] = nil
	end)
	PlayerData.onLoaded(payEgg)
	task.spawn(function()
		while true do
			task.wait(DAY_EVERY)
			for _, player in Players:GetPlayers() do
				payEgg(player)
			end
		end
	end)
	Inbound.debug(Remotes.DebugPremium, function(player, on)
		overrides[player] = on == true
		publish(player)
		payEgg(player)
		Wallet.send(player)
		log.info("%s is %s Premium (Studio)", player.Name, if on == true then "now" else "not")
	end)
end

return Premium
