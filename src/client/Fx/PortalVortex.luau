--!strict
--[[
	The area portals' vortices (`Config/Lobby.portalVortex`): each is a sheet of
	its stepped spin, moved on a frame at a time, and the white of its heart
	pulses, as the Bogheart Caverns portal does in its Claude Design build.
	Every portal steps together, and nothing is written between steps.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)

local PortalVortex = {}

function PortalVortex.start()
	local vortex = LobbyConfig.portalVortex
	local shown = -1
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local frame = math.floor(now / vortex.step) % vortex.frames
		if frame == shown then
			return
		end
		shown = frame
		local offset = Vector2.new(
			(frame % vortex.columns) * vortex.cell.X,
			math.floor(frame / vortex.columns) * vortex.cell.Y
		)
		local glow = 0.5 - 0.2 * math.sin(now * 3)
		for _, tagged in CollectionService:GetTagged(vortex.tag) do
			local image = tagged :: ImageLabel
			image.ImageRectOffset = offset
			local pulse = image:FindFirstChild("Pulse") :: ImageLabel?
			if pulse then
				pulse.ImageTransparency = glow
			end
		end
	end)
end

return PortalVortex
