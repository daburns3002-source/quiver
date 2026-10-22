--!strict
--[[
	The camera's framing per screen, pinned because Studio cannot pretend to
	be a phone: a phone sees the arena closer than a desktop does, and a
	phone held upright still sees the whole floor's width.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CameraFit = require(ReplicatedStorage.Shared.Util.CameraFit)
local TestRunner = require(script.Parent.TestRunner)

local DESKTOP = Vector2.new(1920, 1080)
local PHONE_LANDSCAPE = Vector2.new(844, 390)
local PHONE_PORTRAIT = Vector2.new(390, 844)
local TABLET = Vector2.new(1024, 768)

local function framing(phone: boolean): CameraFit.Framing
	local c = Balance.Camera
	return {
		pitch = c.pitch,
		fieldOfView = c.fieldOfView,
		fitWidth = if phone then c.phone.fitWidth else c.fitWidth,
		minVisibleDepth = if phone then c.phone.minVisibleDepth else c.minVisibleDepth,
	}
end

--[[ Studs of floor across the screen at the focus, for a camera `offset`. ]]
local function groundWidth(viewport: Vector2, offset: Vector3): number
	local half = math.rad(Balance.Camera.fieldOfView) / 2
	return 2 * offset.Magnitude * math.tan(half) * viewport.X / viewport.Y
end

return function(t: TestRunner.Helper)
	t.test("a phone is told apart from a tablet and a computer", function()
		t.isTrue(CameraFit.isPhone(PHONE_LANDSCAPE, true))
		t.isTrue(CameraFit.isPhone(PHONE_PORTRAIT, true))
		t.isFalse(CameraFit.isPhone(TABLET, true), "a tablet is framed like a phone")
		t.isFalse(
			CameraFit.isPhone(PHONE_LANDSCAPE, false),
			"a small mouse window is framed like a phone"
		)
		t.isFalse(CameraFit.isPhone(DESKTOP, false))
	end)

	t.test("a phone sees the arena closer than the desktop framing would show it", function()
		for _, viewport in { PHONE_LANDSCAPE, PHONE_PORTRAIT } do
			local phone = CameraFit.offset(viewport, framing(true)).Magnitude
			local desktop = CameraFit.offset(viewport, framing(false)).Magnitude
			t.isTrue(phone < desktop * 0.9, "the phone framing is not meaningfully closer")
		end
	end)

	t.test("a phone held upright still sees the floor's full width", function()
		local offset = CameraFit.offset(PHONE_PORTRAIT, framing(true))
		t.isTrue(
			groundWidth(PHONE_PORTRAIT, offset) >= Balance.Arena.size.X,
			"the walls are off screen"
		)
	end)

	t.test("a phone held sideways sees the floor's full width too", function()
		local offset = CameraFit.offset(PHONE_LANDSCAPE, framing(true))
		t.isTrue(
			groundWidth(PHONE_LANDSCAPE, offset) >= Balance.Arena.size.X,
			"the walls are off screen"
		)
	end)
end
