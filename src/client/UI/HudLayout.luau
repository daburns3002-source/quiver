--!strict
--[[
	Where the fight's HUD goes on this screen, from `Config/Hud`: a computer's
	stack, a phone held sideways's single row, or a phone held upright's
	stack fitted to its width. Re-laid when the screen changes shape, since a
	phone can turn mid-run.

	Each HUD piece binds a function that places it; this module only works
	out where.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)

local Device = require(script.Parent.Parent.Device)

local HudLayout = {}

export type Place = { anchor: Vector2, position: UDim2, size: UDim2, maxHeight: number }

export type Layout = {
	health: Place,
	dash: Place,
	skillBarScale: number,
	skillBarPosition: UDim2,
}

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

function HudLayout.current(): Layout
	local view = viewport()

	if not Device.isPhone() then
		local d = Hud.desktop
		return {
			health = {
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -d.healthBottom),
				size = UDim2.new(d.barsWidthShare, 0, 0, d.healthHeight),
				maxHeight = 28,
			},
			dash = {
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -d.dashBottom),
				size = UDim2.new(d.barsWidthShare, 0, 0, d.dashHeight),
				maxHeight = 16,
			},
			skillBarScale = d.skillBarScale,
			skillBarPosition = UDim2.new(0.5, 0, 1, -d.skillBarBottom),
		}
	end

	if view.X >= view.Y then
		local s = Hud.phoneSideways
		return {
			health = {
				anchor = Vector2.new(1, 1),
				position = UDim2.new(0.5, s.barsRight, 1, -s.barsBottom),
				size = UDim2.fromOffset(s.barsWidth, s.healthHeight),
				maxHeight = s.healthHeight,
			},
			dash = {
				anchor = Vector2.new(1, 1),
				position = UDim2.new(
					0.5,
					s.barsRight,
					1,
					-(s.barsBottom + s.healthHeight + s.barsGap)
				),
				size = UDim2.fromOffset(s.barsWidth, s.dashHeight),
				maxHeight = s.dashHeight,
			},
			skillBarScale = s.skillBarScale,
			skillBarPosition = UDim2.new(0.5, s.skillBarShiftX, 1, -s.skillBarBottom),
		}
	end

	local u = Hud.phoneUpright
	--[[ The strip left of the dash button, where the skill bar and the
	     bars above it are centred. ]]
	local room = view.X - u.edge - u.dashClear
	local centre = u.edge + room / 2
	local scale = math.min(u.skillBarScale, room / Hud.touchTray.X)
	local barsWidth = math.min(u.barsWidth, room)
	local healthBottom = u.skillBarBottom + Hud.touchTray.Y * scale + u.barsGap
	return {
		health = {
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0, centre, 1, -healthBottom),
			size = UDim2.fromOffset(barsWidth, u.healthHeight),
			maxHeight = u.healthHeight,
		},
		dash = {
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0, centre, 1, -(healthBottom + u.healthHeight + u.barsGap)),
			size = UDim2.fromOffset(barsWidth, u.dashHeight),
			maxHeight = u.dashHeight,
		},
		skillBarScale = scale,
		skillBarPosition = UDim2.new(0, centre, 1, -u.skillBarBottom),
	}
end

--[[ Calls `place` with the layout now and whenever the screen changes
     shape. Returns the connection, or nil without a camera. ]]
function HudLayout.bind(place: (Layout) -> ()): RBXScriptConnection?
	place(HudLayout.current())
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	return camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		place(HudLayout.current())
	end)
end

return HudLayout
