--!strict
--[[
	A Wind Tunnel gust on its way (`Arena/WindGusts`, `Remotes.WindGust`):
	white streaks blown across the room the way it will push, in waves from
	the warning until just after the push lands, so a player sees which way
	to brace before it moves them.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WindGustFx = {}

local WIND = Color3.fromRGB(236, 246, 255)
--[[ The room's floor, a little past its walls either way. ]]
local HALF_X = 22
local HALF_Z = 28
local PER_WAVE = 7
local WAVE_GAP = 0.25
--[[ Seconds a streak takes to cross the room. ]]
local CROSS = 0.55

local rng = Random.new()

local function streak(direction: Vector3)
	local z = rng:NextNumber(-HALF_Z, HALF_Z)
	local y = rng:NextNumber(0.5, 3)
	local length = rng:NextNumber(4, 7)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = WIND
	part.Transparency = 0.35
	part.Size = Vector3.new(length, 0.12, 0.3)
	part.Position = Vector3.new(-direction.X * HALF_X, y, z)
	part.Parent = Workspace
	TweenService:Create(part, TweenInfo.new(CROSS, Enum.EasingStyle.Linear), {
		Position = Vector3.new(direction.X * HALF_X, y, z),
		Transparency = 0.8,
	}):Play()
	Debris:AddItem(part, CROSS + 0.05)
end

function WindGustFx.show(direction: Vector3, warn: number)
	local waves = math.max(1, math.floor((warn + 0.4) / WAVE_GAP))
	task.spawn(function()
		for _ = 1, waves do
			for _ = 1, PER_WAVE do
				streak(direction)
			end
			task.wait(WAVE_GAP)
		end
	end)
end

return WindGustFx
