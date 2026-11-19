--!strict
--[[
	PolicyService's answer for each player, on the server: whether paid
	random items are restricted for them (`ArePaidRandomItemsRestricted`).
	Anything sold for Robux that touches random rewards (`paidRandom` in
	`Config/RobuxStore`: the Server Luck) is never offered to, and refused
	for, such a player (`StoreRules.offered`).

	**Unknown counts as restricted.** Until the answer is in, and if
	PolicyService keeps failing, the player is treated as restricted: a
	product that should have been offered and was not is a smaller harm
	than one sold where it is not allowed. The answer is shown to the
	screens on the Player (`RobuxStore.paidRandomAttribute`: true, then
	false once known not to be), and the server reads its own table.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)

local log = Log.forTag("Policy")

local Policy = {}

--[[ Tries before giving up (the player stays restricted), and the wait
     between them. ]]
local TRIES = 4
local BACKOFF = 5

local restricted: { [Player]: boolean } = {}

--[[ Whether paid random items are restricted for `player`: true until
     PolicyService has said otherwise. ]]
function Policy.restricted(player: Player): boolean
	return restricted[player] ~= false
end

local function check(player: Player)
	restricted[player] = true
	player:SetAttribute(RobuxStore.paidRandomAttribute, true)
	for try = 1, TRIES do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if not player.Parent then
			return
		end
		if ok and type(info) == "table" then
			local answer = info.ArePaidRandomItemsRestricted ~= false
			restricted[player] = answer
			player:SetAttribute(RobuxStore.paidRandomAttribute, answer)
			return
		end
		log.warn("policy for %s failed (try %d): %s", player.Name, try, tostring(info))
		task.wait(BACKOFF * try)
	end
end

function Policy.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(check, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
	end)
end

return Policy
