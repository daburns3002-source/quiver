--!strict
--[[
	Device tier resolution.

	Roblox will not tell us what hardware we are on, so this infers a tier from
	input capabilities and screen size. It is a presentation budget only —
	nothing gameplay-affecting may read it, or two players on different phones
	would be playing different games.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraFit = require(ReplicatedStorage.Shared.Util.CameraFit)
local DeviceTiers = require(ReplicatedStorage.Shared.Config.DeviceTiers)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("Device")

local Device = {}

local resolved: DeviceTiers.Tier? = nil

local function detect(): DeviceTiers.Tier
	--[[ Studio only: a `DevTier` attribute on the Workspace ("Low",
	     "Medium" or "High"), set in Edit before Play, plays as that tier,
	     so a phone's budgets can be measured on a computer. ]]
	local forced = if RunService:IsStudio() then Workspace:GetAttribute("DevTier") else nil
	if forced == "Low" or forced == "Medium" or forced == "High" then
		return DeviceTiers[forced]
	end

	if GuiService:IsTenFootInterface() then
		return DeviceTiers.Medium
	end

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	if not touchOnly then
		return DeviceTiers.High
	end

	--[[
		Touch device. Split phones from tablets by viewport size: a tablet has
		the pixels and usually the thermal headroom for the middle tier.
	]]
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local smallestEdge = math.min(viewport.X, viewport.Y)

	if smallestEdge >= 700 then
		return DeviceTiers.Medium
	end

	return DeviceTiers.Low
end

--[[ A phone, not a tablet or a computer: a touch screen whose short side is
     small. Phones get their own, larger HUD and a closer camera.

	 Read from the screen's size, not from which inputs are present: a phone
	 reports none of mouse or keyboard, but Studio's phone emulator reports
	 both as soon as the window has focus, and a check on them flipped the
	 HUD back to the computer layout mid-run. ]]
function Device.isPhone(): boolean
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return CameraFit.isPhone(viewport, UserInputService.TouchEnabled)
end

function Device.tier(): DeviceTiers.Tier
	if resolved then
		return resolved :: DeviceTiers.Tier
	end

	local tier = detect()
	resolved = tier
	log.info("resolved tier %s", tier.name)

	return tier
end

return Device
