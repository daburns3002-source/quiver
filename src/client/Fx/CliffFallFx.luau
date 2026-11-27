--!strict
--[[
	A player pushed over a Windswept Cliffs edge (`Arena/CliffFalls`,
	`Remotes.PlayerFell`): a burst of white cloud cubes where they land back
	on the floor, and for the faller a short shake.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TopDownCamera = require(script.Parent.Parent.Camera.TopDownCamera)

local CliffFallFx = {}

local CLOUD = Color3.fromRGB(244, 248, 255)

function CliffFallFx.onFell(player: Player, landing: Vector3)
	for i = 1, 10 do
		local angle = i / 10 * 2 * math.pi
		local puff = Instance.new("Part")
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = CLOUD
		puff.Size = Vector3.one * (0.8 + (i % 3) * 0.3)
		puff.Position = landing + Vector3.new(math.cos(angle), 0.6, math.sin(angle)) * 0.8
		puff.Parent = Workspace
		TweenService
			:Create(puff, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = landing + Vector3.new(math.cos(angle) * 3, 1.6, math.sin(angle) * 3),
				Transparency = 1,
				Size = puff.Size * 0.4,
			})
			:Play()
		Debris:AddItem(puff, 0.65)
	end
	if player == Players.LocalPlayer then
		TopDownCamera.shake(0.6, 0.35)
	end
end

return CliffFallFx
