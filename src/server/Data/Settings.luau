--!strict
--[[
	A player's settings, kept in their save (`Config/Settings`,
	`Util/SettingsRules`, `SaveSchema.settings`).

	Each is put on the Player as an attribute when the profile loads, which
	is how the client reads it (`client/Options`). `Remotes.SettingSet` asks
	for a change: the name and the value both come from the client, so both
	are cleaned here (`SettingsRules.clean`) and anything that is not a
	setting, or not a value one can hold, is dropped. Asks are spaced `GAP`
	apart a player. Nothing here touches the game: these are sound levels
	and a yes/no for vibration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SettingsRules = require(ReplicatedStorage.Shared.Util.SettingsRules)

local PlayerData = require(script.Parent.PlayerData)

local Settings = {}

local GAP = 0.1
local lastAsk: { [Player]: number } = {}

--[[ Puts a player's saved settings on them, for their client to read. ]]
function Settings.apply(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for name, attribute in Config.attributes :: { [string]: string } do
		player:SetAttribute(attribute, (profile.settings :: any)[name])
	end
end

local function set(player: Player, name: unknown, value: unknown)
	local now = os.clock()
	if now - (lastAsk[player] or -math.huge) < GAP then
		return
	end
	lastAsk[player] = now
	local profile = PlayerData.get(player)
	local key, clean = SettingsRules.clean(name, value)
	if not profile or not key or clean == nil then
		return
	end
	(profile.settings :: any)[key] = clean
	PlayerData.touch(player)
	player:SetAttribute((Config.attributes :: { [string]: string })[key], clean)
end

function Settings.start()
	PlayerData.onLoaded(Settings.apply)
	Remotes.event(Remotes.SettingSet).OnServerEvent:Connect(set)
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
end

return Settings
