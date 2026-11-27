--!strict
--[[
	Roblox's own favourite prompt, once ever, after a boss win
	(`Util/FavouriteRules`, `Data/Favourite`; owner, 2026-11-18). The server
	sets the player's `FavouriteOwed` attribute; this waits until the player
	is back in the lobby with nothing else on screen (no end screen, story
	beat, reveal or menu), lets the lobby settle for `SETTLE` seconds, and
	shows `AvatarEditorService:PromptSetFavorite` for this experience
	(its place id, as an Asset). Then it tells the server, which saves that
	it was asked.

	No reward and no words of our own: Roblox's prompt is the whole of it.
]]

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FavouriteRules = require(ReplicatedStorage.Shared.Util.FavouriteRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Reveal = require(script.Parent.Reveal)
local RunPaused = require(script.Parent.Parent.RunPaused)

local log = Log.forTag("FavouritePrompt")

local FavouritePrompt = {}

local ATTRIBUTE = "FavouriteOwed"
--[[ Seconds the lobby must stay clear before the prompt comes up. ]]
local SETTLE = 2.5

local waiting = false

local function clear(player: Player): boolean
	return FavouriteRules.ready(
		player:GetAttribute(ATTRIBUTE) == true,
		Workspace:GetAttribute("InLobby") == true,
		RunPaused.covered() or Reveal.busy()
	)
end

local function prompt()
	-- (no GetFavoriteAsync first: it needs Roblox's inventory-access prompt)
	local shown, err = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not shown then
		log.warn("the favourite prompt did not open: %s", tostring(err))
	end
	Remotes.event(Remotes.FavouriteAsked):FireServer()
end

local function watch(player: Player)
	if waiting or player:GetAttribute(ATTRIBUTE) ~= true then
		return
	end
	waiting = true
	task.spawn(function()
		local since: number? = nil
		while player:GetAttribute(ATTRIBUTE) == true do
			if clear(player) then
				local start = since or os.clock()
				since = start
				if os.clock() - start >= SETTLE then
					prompt()
					break
				end
			else
				since = nil
			end
			task.wait(0.5)
		end
		waiting = false
	end)
end

function FavouritePrompt.start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		watch(player)
	end)
	watch(player)
end

return FavouritePrompt
