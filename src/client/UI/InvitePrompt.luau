--!strict
--[[
	Roblox's invite, sent with launch data naming the sender
	(`Util/InviteRules.launchData`; owner, 2026-11-18): a friend who joins
	by it for the first time ever, and the sender, both get a reward
	(`Server/Data/Invites`). Used by the party line's INVITE A FRIEND
	(`UI/CoopHud`) and REWARDS > GIFTS (`UI/RewardsScreen`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local InviteRules = require(ReplicatedStorage.Shared.Util.InviteRules)

local InvitePrompt = {}

local player = Players.LocalPlayer

--[[ Opens Roblox's invite, if this player may send one. ]]
function InvitePrompt.open()
	pcall(function()
		if not SocialService:CanSendGameInviteAsync(player) then
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		-- through `any`: CI's type definitions may predate these properties
		local untyped: any = options
		untyped.LaunchData = InviteRules.launchData(player.UserId)
		untyped.PromptMessage = "Come play with me! We both get a gift."
		SocialService:PromptGameInvite(player, options)
	end)
end

return InvitePrompt
