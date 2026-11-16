--!strict
--[[
	The Assassin's own effects (`Config/Classes.Assassin`), built from voxel
	cubes like every class's (`Fx/Upgrades/Voxel`), in the violet of the
	daggers' wraps.

	- **Shadow Dash, leaving**: this client's own dash drops a line of fading
	  violet blocks behind the character for as long as it lasts
	  (`Input/MoveController` says it began), so the dash reads as a streak
	  the moment the button is pressed.
	- **Shadow Dash, cutting**: the server's word that a dash cut
	  (`Combat/MeleeSystem.dash`, `Remotes.UpgradeFx` "ShadowDash"): a thin
	  bright slash along the ground it covered, and a cross of two short
	  cuts and a few chips over every enemy it struck. Drawn for everyone.

	Presentation only: the server decides who a dash struck.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local Voxel = require(script.Parent.Voxel)

local AssassinFx = {}

local VIOLET = Color3.fromRGB(146, 62, 224)
local PALE = Color3.fromRGB(236, 226, 255)
local SHADOW = Color3.fromRGB(52, 30, 86)
local COLOURS = { VIOLET, PALE, SHADOW }

--[[ Studs above the floor the slash is drawn at: about the daggers' height. ]]
local HEIGHT = 2.2
--[[ Seconds between the blocks a dash leaves, and how long each lasts. ]]
local DROP_EVERY = 0.012
local DROP_LIFE = 0.28

--[[ This client's dash began: blocks left along it until it ends. ]]
function AssassinFx.dashed()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local lastDrop = -math.huge
	local started = os.clock()
	local dropped = 0
	Voxel.run(Balance.Player.dash.duration + 0.04, function()
		local elapsed = os.clock() - started
		if not root.Parent then
			return false
		end
		if elapsed - lastDrop < DROP_EVERY then
			return nil
		end
		lastDrop = elapsed
		dropped += 1
		local size = Vector3.new(1.5, 3.4, 1.1)
		local bit = Voxel.cube(size, COLOURS[dropped % 2 + 1], true)
		bit.CFrame = root.CFrame
		bit.Transparency = 0.35
		Voxel.run(DROP_LIFE, function(f)
			bit.Size = size * (1 - f * 0.7)
			bit.Transparency = 0.35 + 0.65 * f
			return nil
		end, function()
			bit:Destroy()
		end)
		return nil
	end)
end

--[[ One short bright cut at `at`, turned `turn` radians about the upright. ]]
local function cut(at: Vector3, turn: number, length: number)
	local bar = Voxel.cube(Vector3.new(0.22, 0.22, 0.4), PALE, true)
	local frame = CFrame.new(at) * CFrame.Angles(0, turn, 0) * CFrame.Angles(math.rad(28), 0, 0)
	bar.CFrame = frame
	Voxel.run(0.22, function(t)
		local grown = math.min(1, t * 3.2)
		bar.Size = Vector3.new(0.22 * (1 - t), 0.22 * (1 - t), 0.4 + length * grown)
		bar.Color = PALE:Lerp(VIOLET, t)
		bar.Transparency = t * t
		return nil
	end, function()
		bar:Destroy()
	end)
end

--[[ A dash cut the ground from `a` to `b` and struck what stood at
     `struck`. ]]
local function onShadowDash(a: Vector3, b: Vector3, struck: { Vector3 })
	local from = Vector3.new(a.X, HEIGHT, a.Z)
	local to = Vector3.new(b.X, HEIGHT, b.Z)
	local span = to - from
	local length = span.Magnitude
	if length > 0.5 then
		local slash = Voxel.cube(Vector3.new(0.3, 0.3, 0.1), PALE, true)
		Voxel.light(slash, VIOLET, 10, 2)
		local facing = CFrame.lookAt(from, to)
		Voxel.run(0.2, function(t)
			--[[ Drawn out from the start in the first third, then thinning. ]]
			local reached = math.min(1, t * 3)
			local thick = 0.34 * (1 - t)
			slash.Size = Vector3.new(thick, thick, math.max(0.1, length * reached))
			slash.CFrame = facing * CFrame.new(0, 0, -length * reached / 2)
			slash.Color = PALE:Lerp(VIOLET, t)
			slash.Transparency = t * t
			return nil
		end, function()
			slash:Destroy()
		end)
	end
	if #struck > 0 then
		SoundFx.play("dagger_stab")
	end
	local turn = if length > 0.5 then math.atan2(-span.X, -span.Z) else 0
	for index, at in struck do
		if index > Voxel.share(8) then
			break
		end
		local over = Vector3.new(at.X, HEIGHT, at.Z)
		cut(over, turn + math.rad(40), 3.2)
		cut(over, turn - math.rad(40), 3.2)
		Voxel.burst(over, 4, COLOURS, 5, 0.26, 0.3, 2.5)
	end
end

function AssassinFx.start()
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			if kind ~= "ShadowDash" then
				return
			end
			local a, b, struck = ...
			if typeof(a) == "Vector3" and typeof(b) == "Vector3" and type(struck) == "table" then
				onShadowDash(a, b, struck)
			end
		end)
end

return AssassinFx
