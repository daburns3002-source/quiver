--!strict
--[[
	Roblox's favourite prompt, once ever (`Util/FavouriteRules`,
	`UI/FavouritePrompt`). A boss win sets the `FavouriteOwed` attribute on
	the player while the save says it has never been asked
	(`Favourite.bossWon`, from `Wallet.beatBoss`); the client shows Roblox's
	prompt once the lobby is clear and answers `Remotes.FavouriteAsked`,
	which is saved, so it is never shown again. Nothing is given for it.

	A player who leaves before it shows is asked after their next boss win.
	Firing the remote early only spends that player's own one prompt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FavouriteRules = require(ReplicatedStorage.Shared.Util.FavouriteRules)
local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local log = Log.forTag("Favourite")

local Favourite = {}

Favourite.ATTRIBUTE = "FavouriteOwed"

--[[ A boss has just been beaten by `player`. ]]
function Favourite.bossWon(player: Player)
	local profile = PlayerData.get(player)
	if profile and FavouriteRules.owed(profile.favouriteAsked, profile.bossesBeaten) then
		player:SetAttribute(Favourite.ATTRIBUTE, true)
	end
end

local function asked(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.favouriteAsked then
		return
	end
	profile.favouriteAsked = true
	PlayerData.touch(player)
	player:SetAttribute(Favourite.ATTRIBUTE, nil)
	log.info("%s was shown the favourite prompt", player.Name)
end

function Favourite.start()
	Inbound.on(Remotes.FavouriteAsked, asked)
end

return Favourite
