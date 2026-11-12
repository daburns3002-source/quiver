--!strict
--[[
	The device shaking: a hit taken, a dash, a level gained (the 2026-11-11
	loop and UI review: "no phone vibration on hit, dash or level-up").

	Each is one of Roblox's built-in `HapticEffect` kinds, which play on a
	phone's motor or a gamepad's and do nothing on a device with neither.
	Off when the player has turned vibration off (`Options.haptics`,
	`UI/SettingsScreen`). Presentation only.
]]

local Workspace = game:GetService("Workspace")

local Options = require(script.Parent.Parent.Options)

local Haptics = {}

export type Kind = "hit" | "dash" | "level" | "press"

local TYPES: { [string]: Enum.HapticEffectType } = {
	hit = Enum.HapticEffectType.GameplayCollision,
	dash = Enum.HapticEffectType.UIClick,
	level = Enum.HapticEffectType.UINotification,
	press = Enum.HapticEffectType.UIHover,
}

local effects: { [string]: HapticEffect } = {}

function Haptics.play(kind: Kind)
	if not Options.haptics() then
		return
	end
	local effect = effects[kind]
	if not effect then
		local made = Instance.new("HapticEffect")
		made.Name = "Haptic_" .. kind
		made.Type = TYPES[kind]
		made.Parent = Workspace
		effects[kind] = made
		effect = made
	end
	effect:Play()
end

return Haptics
