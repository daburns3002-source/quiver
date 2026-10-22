--!strict
--[[
	How far the top-down camera sits from its focus, solved for a screen.

	Pure maths, out of `TopDownCamera` so a test can pin it: Studio cannot
	pretend to be a phone, and the question "does a phone see the arena up
	close" is one the gates would otherwise wave through.

	The distance is whatever makes `fitWidth` studs of ground span the screen
	side to side, from the screen's own aspect, so every phone shows the
	room's full width. On a landscape screen that would zoom right in, so it
	never shows less depth than `minVisibleDepth`. A phone has its own pair
	of numbers (`Balance.Camera.phone`): the desktop's framing shrinks the
	whole 58-stud room onto a six-inch screen.
]]

local CameraFit = {}

export type Framing = {
	pitch: number,
	fieldOfView: number,
	fitWidth: number,
	minVisibleDepth: number,
}

--[[ A phone, not a tablet or a computer: a touch screen with a short side
     under this many points. Roblox reports phone screens around 390 tall in
     landscape and tablets from about 768. ]]
CameraFit.PHONE_SHORT_SIDE = 600

function CameraFit.isPhone(viewport: Vector2, touch: boolean): boolean
	return touch and math.min(viewport.X, viewport.Y) < CameraFit.PHONE_SHORT_SIDE
end

--[[ The camera's offset from its focus, for `framing` on a `viewport`. ]]
function CameraFit.offset(viewport: Vector2, framing: Framing): Vector3
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 9 / 16

	local halfVertical = math.rad(framing.fieldOfView) / 2
	local tanHalfHorizontal = math.tan(halfVertical) * aspect

	local toFitWidth = (framing.fitWidth / 2) / tanHalfHorizontal
	local toFitDepth = (framing.minVisibleDepth / 2) / math.tan(halfVertical)
	local distance = math.max(toFitWidth, toFitDepth)

	local pitch = math.rad(framing.pitch)
	return Vector3.new(0, math.sin(pitch), math.cos(pitch)) * distance
end

return CameraFit
