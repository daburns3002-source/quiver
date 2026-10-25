--!strict
--[[
	A Mythic weapon's glow cycles through the rainbow (owner, 2026-10-24:
	"the mythic weapons need to have a rainbow glow"). The server tags each
	glow part of a Mythic `WeaponRainbow` (`Combat/HeldWeapon`); here its
	colour and its light's colour turn round the hue wheel every frame, the
	same on every part so a weapon glows one colour at a time.

	Presentation only, and only on this client.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--[[ Turns of the hue wheel a second, and the colour's saturation. ]]
local SPEED = 0.25
local SATURATION = 0.7

local WeaponGlow = {}

local connection: RBXScriptConnection? = nil

local function step()
	local colour = Color3.fromHSV((os.clock() * SPEED) % 1, SATURATION, 1)
	for _, part in CollectionService:GetTagged("WeaponRainbow") do
		if part:IsA("BasePart") then
			part.Color = colour
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = colour
			end
		end
	end
end

function WeaponGlow.start()
	if connection then
		connection:Disconnect()
	end
	connection = RunService.RenderStepped:Connect(step)
end

return WeaponGlow
