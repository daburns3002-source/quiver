--!strict
--[[
	A player's own settings (`Config/Settings`; the 2026-11-11 loop and UI
	review found no music or sound volume and no way to turn vibration off):
	what each may be set to, and reading them back out of a save.

	The server cleans every value with this before it keeps it
	(`Server/Data/Settings`), since `Remotes.SettingSet` comes from the
	client, and `Util/SaveSchema` reads a stored copy through it, so nothing
	but a volume step or a yes/no is ever held.
]]

local Config = require(script.Parent.Parent.Config.Settings)

local SettingsRules = {}

export type Settings = { music: number, sound: number, haptics: boolean }

function SettingsRules.default(): Settings
	return {
		music = Config.defaults.music,
		sound = Config.defaults.sound,
		haptics = Config.defaults.haptics,
	}
end

--[[ A volume snapped to one of the steps the screen offers, 0 to 1; nil
     for anything that is not a number. ]]
local function volume(value: unknown): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	local steps = Config.steps
	return math.clamp(math.floor(value * steps + 0.5), 0, steps) / steps
end

--[[ The setting `name` as it may be kept, from whatever was sent: its name
     and its cleaned value, or nil for a setting that does not exist or a
     value of the wrong kind. ]]
function SettingsRules.clean(name: unknown, value: unknown): (string?, (number | boolean)?)
	if name == "music" or name == "sound" then
		local level = volume(value)
		if level == nil then
			return nil, nil
		end
		return name :: string, level
	elseif name == "haptics" then
		if type(value) ~= "boolean" then
			return nil, nil
		end
		return "haptics", value
	end
	return nil, nil
end

--[[ A stored copy as settings: each field cleaned, its default where it is
     missing or broken. Nothing stored (an older save) is the defaults. ]]
function SettingsRules.read(raw: unknown): Settings
	local out = SettingsRules.default()
	if type(raw) ~= "table" then
		return out
	end
	local data = raw :: any
	local music, sound = volume(data.music), volume(data.sound)
	if music ~= nil then
		out.music = music
	end
	if sound ~= nil then
		out.sound = sound
	end
	if type(data.haptics) == "boolean" then
		out.haptics = data.haptics
	end
	return out
end

return SettingsRules
