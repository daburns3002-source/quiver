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

	Its cards' (`Combat/AssassinUpgrades`, `Combat/MeleeSystem`):

	- **Backstab**: a cut and a few chips where a strike landed from behind.
	- **Poison Trail**: a ring of green blocks round the cloud and bubbles
	  rising in it, for as long as it stays.
	- **Fan of Knives**: each thrown knife (the "Knife" look) is pale steel.
	- **Death Mark**: a violet diamond turning over the marked enemy
	  (`DeathMarked` on its model).
	- **Phantom Blades**: ghost daggers circling every player who holds
	  them (`PhantomBlades` on the player), where the server's are.
	- **Thousand Cuts**: a shadow, two cuts and a rainbow flash on each
	  enemy in turn.

	Presentation only: the server decides who anything struck.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
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

--[[ The cards (`Combat/AssassinUpgrades`) ]]

local POISON = {
	Color3.fromRGB(126, 224, 92),
	Color3.fromRGB(70, 168, 62),
	Color3.fromRGB(96, 52, 150),
}
local GHOST = Color3.fromRGB(150, 232, 255)

--[[ Fan of Knives: a thrown knife is pale steel, out of a small violet
     burst. ]]
local function knife(part: BasePart)
	part.Color = PALE
	Voxel.burst(part.Position, 2, { VIOLET, PALE }, 5, 0.2, 0.25, 2)
	SoundFx.play("fx_fan_of_knives")
end

--[[ Backstab: a strike landed from behind the enemy at `at`. ]]
local function onBackstab(at: Vector3)
	local over = Vector3.new(at.X, HEIGHT, at.Z)
	cut(over, math.random() * math.pi, 2.6)
	Voxel.burst(over, 3, { PALE, VIOLET }, 6, 0.24, 0.3, 4)
	SoundFx.play("fx_backstab")
end

--[[ Poison Trail: a cloud `radius` wide at `at` for `seconds`: a ring of
     blocks marking its edge and bubbles rising inside it. ]]
local function onPoisonTrail(at: Vector3, radius: number, seconds: number)
	SoundFx.play("fx_poison_trail")
	local edge: { Part } = {}
	local count = Voxel.share(12)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local bit = Voxel.cube(0.45, POISON[index % 2 + 1], true)
		bit.CFrame = CFrame.new(at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
			* CFrame.new(0, 0.3, 0)
		table.insert(edge, bit)
	end
	local bubbles: { { part: Part, at: Vector3, phase: number, size: number } } = {}
	for index = 1, Voxel.share(9) do
		local angle = math.random() * math.pi * 2
		local out = math.sqrt(math.random()) * radius * 0.85
		local size = 0.5 + math.random() * 0.5
		table.insert(bubbles, {
			part = Voxel.cube(size, POISON[index % #POISON + 1], true),
			at = at + Vector3.new(math.cos(angle) * out, 0, math.sin(angle) * out),
			phase = math.random(),
			size = size,
		})
	end
	local started = os.clock()
	Voxel.run(seconds, function(t)
		local elapsed = os.clock() - started
		--[[ Fading in the last fifth, so the cloud does not blink out. ]]
		local fade = math.clamp((t - 0.8) / 0.2, 0, 1)
		for _, bit in edge do
			bit.Transparency = 0.25 + 0.75 * fade
		end
		for _, bubble in bubbles do
			local rise = (elapsed * 1.1 + bubble.phase) % 1
			bubble.part.Size = Vector3.one * bubble.size * (0.5 + rise * 0.7)
			bubble.part.CFrame = CFrame.new(bubble.at + Vector3.new(0, 0.3 + rise * 2.2, 0))
				* CFrame.Angles(0, elapsed * 2 + bubble.phase * 6, 0)
			bubble.part.Transparency = math.max(0.2 + rise * 0.7, fade)
		end
		return nil
	end, function()
		for _, bit in edge do
			bit:Destroy()
		end
		for _, bubble in bubbles do
			bubble.part:Destroy()
		end
	end)
end

--[[ Thousand Cuts: a shadow at each of `at` in turn, `gap` seconds apart,
     each a dark figure, two crossing cuts and a flash turning round the
     rainbow (a Mythic glows). ]]
local function onThousandCuts(at: { Vector3 }, gap: number)
	SoundFx.play("fx_thousand_cuts")
	for index, point in at do
		if typeof(point) ~= "Vector3" then
			continue
		end
		task.delay(index * gap, function()
			local over = Vector3.new(point.X, HEIGHT, point.Z)
			local side = CFrame.Angles(0, index * 2.4, 0).LookVector * 2.2
			local shadow = Voxel.cube(Vector3.new(1.5, 3.4, 1.1), SHADOW, false)
			shadow.CFrame = CFrame.lookAt(over + side, over)
			shadow.Transparency = 0.15
			Voxel.run(0.3, function(t)
				--[[ Through the enemy and out the other side, fading. ]]
				shadow.CFrame = CFrame.lookAt(over + side * (1 - 2 * t), over + side * -3)
				shadow.Transparency = 0.15 + 0.85 * t
				return nil
			end, function()
				shadow:Destroy()
			end)
			local turn = index * 1.1
			cut(over, turn, 3.6)
			cut(over, turn + math.rad(75), 3.6)
			Voxel.flash(over, 2.2, Voxel.rainbow(os.clock(), index / 8), 0.22)
			Voxel.burst(over, 3, COLOURS, 6, 0.26, 0.3, 3)
		end)
	end
end

--[[ Death Mark: a violet diamond turning over the marked enemy, with four
     ticks round it. Polled, as `ClassCardFx` polls its marks. ]]
type Marker = { parts: { Part }, height: number }
local markers: { [Model]: Marker } = {}

local function clearMarker(model: Model)
	local marker = markers[model]
	if marker then
		for _, part in marker.parts do
			part:Destroy()
		end
		markers[model] = nil
	end
end

local function pollMarkers()
	for model in markers do
		if not model.Parent or model:GetAttribute("DeathMarked") ~= true then
			clearMarker(model)
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end
	for _, model in enemies:GetChildren() do
		if
			model:IsA("Model")
			and model:GetAttribute("DeathMarked") == true
			and not markers[model]
		then
			local parts = { Voxel.cube(0.9, VIOLET, true) }
			Voxel.light(parts[1], VIOLET, 8, 2)
			for _ = 1, 4 do
				table.insert(parts, Voxel.cube(Vector3.new(0.22, 0.22, 0.7), PALE, true))
			end
			markers[model] = { parts = parts, height = model:GetExtentsSize().Y + 1.4 }
			local at = model:GetPivot().Position
			Voxel.flash(at + Vector3.new(0, 2, 0), 3, VIOLET, 0.3)
			SoundFx.play("fx_death_mark")
		end
	end
end

local function markersStep(time: number)
	for model, marker in markers do
		if not model.Parent then
			continue
		end
		local base = model:GetPivot().Position
		local centre =
			Vector3.new(base.X, base.Y + marker.height + math.sin(time * 3) * 0.2, base.Z)
		marker.parts[1].CFrame = CFrame.new(centre)
			* CFrame.Angles(0, time * 2.4, 0)
			* CFrame.Angles(math.rad(45), 0, math.rad(45))
		for index = 2, #marker.parts do
			local angle = time * -1.6 + (index - 2) * math.pi / 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			marker.parts[index].CFrame = CFrame.lookAt(centre + out * 1.5, centre)
		end
	end
end

--[[ Phantom Blades: every player's ghost daggers, where the server's are
     (`AssassinRules.orbit`, on the clock every client shares). ]]
local phantoms: { [Player]: { Part } } = {}

local function phantomsStep()
	local config = Balance.Player.assassin.phantom
	local clock = Workspace:GetServerTimeNow()
	local lobby = Workspace:GetAttribute("InLobby") == true
	for _, player in Players:GetPlayers() do
		local count = player:GetAttribute("PhantomBlades")
		local wanted = if type(count) == "number" and not lobby then math.floor(count) else 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			wanted = 0
		end
		local blades = phantoms[player]
		if not blades and wanted > 0 then
			blades = {}
			phantoms[player] = blades
		end
		if not blades then
			continue
		end
		while #blades > wanted do
			(table.remove(blades) :: Part):Destroy()
		end
		while #blades < wanted do
			local blade = Voxel.cube(Vector3.new(0.3, 0.3, 2.3), GHOST, true)
			blade.Transparency = 0.3
			Voxel.light(blade, GHOST, 6, 1.5)
			table.insert(blades, blade)
		end
		if root then
			local centre = Vector3.new(root.Position.X, root.Position.Y, root.Position.Z)
			for index, blade in blades do
				local at =
					AssassinRules.orbit(centre, config.radius, config.turn, clock, index, wanted)
				local ahead = AssassinRules.orbit(
					centre,
					config.radius,
					config.turn,
					clock + 0.1,
					index,
					wanted
				)
				blade.CFrame = CFrame.lookAt(at, ahead)
			end
		end
		if wanted == 0 then
			phantoms[player] = nil
		end
	end
	for player, blades in phantoms do
		if not player.Parent then
			for _, blade in blades do
				blade:Destroy()
			end
			phantoms[player] = nil
		end
	end
end

function AssassinFx.start()
	FxEvents.launched:connect(
		function(part: BasePart, _pool: string, _aim: Vector3, _from: Model?, look: string?)
			if look == "Knife" then
				knife(part)
			end
		end
	)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			local a, b, c = ...
			if kind == "ShadowDash" then
				if typeof(a) == "Vector3" and typeof(b) == "Vector3" and type(c) == "table" then
					onShadowDash(a, b, c)
				end
			elseif kind == "Backstab" then
				if typeof(a) == "Vector3" then
					onBackstab(a)
				end
			elseif kind == "PoisonTrail" then
				if typeof(a) == "Vector3" and type(b) == "number" and type(c) == "number" then
					onPoisonTrail(a, b, c)
				end
			elseif kind == "ThousandCuts" then
				if type(a) == "table" and type(b) == "number" then
					onThousandCuts(a, b)
				end
			end
		end)
	local sinceLastPoll = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		sinceLastPoll += deltaTime
		if sinceLastPoll >= 0.1 then
			sinceLastPoll = 0
			pollMarkers()
		end
		markersStep(os.clock())
		phantomsStep()
	end)
end

return AssassinFx
