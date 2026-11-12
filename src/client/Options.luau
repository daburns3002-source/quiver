--!strict
--[[
	This player's settings, on the client (`Config/Settings`): the music and
	sound volume and whether the device shakes.

	Read from the Player attributes the server sets from the save
	(`Server/Data/Settings`); a setting not there yet reads as its default,
	so nothing waits on the profile. `Options.set` writes the attribute here
	at once, so a slider answers under the thumb, and asks the server to
	keep it (`Remotes.SettingSet`); the server's cleaned value then replaces
	the local one. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SettingsRules = require(ReplicatedStorage.Shared.Util.SettingsRules)

local Options = {}

local attributes = Config.attributes :: { [string]: string }

local function volume(name: string): number
	local value = Players.LocalPlayer:GetAttribute(attributes[name])
	return if type(value) == "number"
		then math.clamp(value, 0, 1)
		else (Config.defaults :: any)[name]
end

--[[ The share of the music's own volume to play it at, 0 to 1. ]]
function Options.music(): number
	return volume("music")
end

--[[ The share of each sound effect's own volume to play it at. ]]
function Options.sound(): number
	return volume("sound")
end

--[[ Whether the device may shake. ]]
function Options.haptics(): boolean
	local value = Players.LocalPlayer:GetAttribute(attributes.haptics)
	return if type(value) == "boolean" then value else Config.defaults.haptics
end

--[[ Changes a setting: here at once, and kept by the server if it is one. ]]
function Options.set(name: string, value: number | boolean)
	local key, clean = SettingsRules.clean(name, value)
	if not key or clean == nil then
		return
	end
	Players.LocalPlayer:SetAttribute(attributes[key], clean)
	Remotes.event(Remotes.SettingSet):FireServer(key, clean)
end

--[[ Calls `changed` whenever the setting `name` does. ]]
function Options.watch(name: string, changed: () -> ())
	Players.LocalPlayer:GetAttributeChangedSignal(attributes[name]):Connect(changed)
end

return Options
