--!strict
--[[
	The Warden's class upgrades of 2026-10-27, drawn big
	(`Combat/MeleeSystem` and `Combat/ClassUpgrades` decide every hit):

	- Titan's Grip (Mythic): this player's sword in hand is grown about its
	  grip by the card's scale (the swing the server checks grows by the
	  same, `MeleeStats.reachScale`), with an outline cycling the rainbow
	  (rule 12). Every slam, for everyone (`UpgradeFx` "TitanSlam"): the
	  room shakes hard, stone blocks heave up in a ring and sink, dust flies
	  and a shock ring runs out past the slam.
	- Counter Strike (Epic): while a player's `CounterReady` is set (a hit
	  taken), their sword burns red, pulsing, shedding red embers; when the
	  charged blow lands (`CounterAt`), a red flash and burst in front of
	  them, a ring, a shake, and COUNTER! in the blocky font.

	Presentation only. The sword is grown on this client only, as a look:
	the server's weld is left as it is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local TopDownCamera = require(script.Parent.Parent.Parent.Camera.TopDownCamera)
local UpgradeFx = require(script.Parent.UpgradeFx)
local Voxel = require(script.Parent.Voxel)

local WardenBuildFx = {}

local STONE =
	{ Color3.fromRGB(140, 132, 120), Color3.fromRGB(104, 96, 88), Color3.fromRGB(170, 160, 142) }
local DUST = { Color3.fromRGB(196, 176, 140), Color3.fromRGB(160, 140, 110) }
local RED = Color3.fromRGB(255, 40, 40)
local HOT = { RED, Color3.fromRGB(255, 120, 90), Color3.fromRGB(255, 230, 220) }

local ARCADE = Font.fromEnum(Enum.Font.Arcade)

--[[ The held sword's model, if this character holds one. ]]
local function sword(character: Model?): Model?
	local held = character and character:FindFirstChild("HeldWeapon")
	return if held and held:IsA("Model") then held else nil
end

--[[ Titan's Grip: grows every part of the held weapon about its grip,
     once per weapon model. Each part is moved by Position, never CFrame:
     with a WeldConstraint, setting CFrame would drag the whole character
     along; Position re-welds the part where it is put. ]]
local function grow(held: Model, scale: number)
	if held:GetAttribute("TitanScale") == scale then
		return
	end
	local was = (held:GetAttribute("TitanScale") :: number?) or 1
	local by = scale / was
	local origin = held:FindFirstChild("WeaponOrigin", true)
	if not origin or not origin:IsA("Attachment") then
		return
	end
	local grip = origin.WorldCFrame
	for _, part in held:GetChildren() do
		if part:IsA("BasePart") then
			part.Size *= by
			part.Position = grip.Position + (part.Position - grip.Position) * by
		end
	end
	-- the grip stays where it was, and what is drawn in the weapon's units
	-- (a blade's tip) grows with it
	origin.WorldCFrame = grip
	origin:SetAttribute("Scale", ((origin:GetAttribute("Scale") :: number?) or 1) * by)
	held:SetAttribute("TitanScale", scale)
end

local outline: Highlight? = nil

local function titanStep()
	local character = Players.LocalPlayer.Character
	local held = sword(character)
	local level = UpgradeFx.level("TitansGrip")
	if not held or level <= 0 then
		if outline then
			outline:Destroy()
			outline = nil
		end
		return
	end
	grow(held, 2)
	local current: Highlight
	local existing = outline
	if existing and existing.Parent == held then
		current = existing
	else
		if existing then
			existing:Destroy()
		end
		local highlight = Instance.new("Highlight")
		highlight.Name = "TitanGlow"
		highlight.FillTransparency = 0.85
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = held
		outline = highlight
		current = highlight
	end
	local colour = Voxel.rainbow(os.clock())
	current.OutlineColor = colour
	current.FillColor = colour
end

local function onTitanSlam(at: Vector3, radius: number)
	SoundFx.play("fx_titan_slam")
	TopDownCamera.shake(0.9, 0.45)
	Voxel.flash(Vector3.new(at.X, 0.6, at.Z), radius * 1.2, Color3.fromRGB(255, 240, 200), 0.2)
	Voxel.ring(at, radius * 1.8, { Color3.fromRGB(255, 230, 180), Color3.new(1, 1, 1) }, 0.5, 0.3)
	Voxel.burst(Vector3.new(at.X, 0.5, at.Z), 18, DUST, 12, 0.8, 0.6, 9)
	-- stone blocks heave up in a ring round the slam and sink again
	local n = Voxel.share(14)
	local stones: { { part: Part, x: number, z: number, angle: number, delay: number } } = {}
	for index = 1, n do
		local angle = index / n * math.pi * 2 + math.random() * 0.3
		local r = radius * (0.7 + math.random() * 0.4)
		local size = 0.9 + math.random() * 0.8
		local part = Voxel.cube(Vector3.new(size, size * 1.4, size), STONE[(index % #STONE) + 1])
		table.insert(stones, {
			part = part,
			x = at.X + math.cos(angle) * r,
			z = at.Z + math.sin(angle) * r,
			angle = angle,
			delay = math.random() * 0.12,
		})
	end
	Voxel.run(0.9, function(t)
		for _, stone in stones do
			local local_t = math.clamp((t * 0.9 - stone.delay) / 0.75, 0, 1)
			-- up fast, hold, sink: stepped as the game's clips are
			local lift = if local_t < 0.2
				then local_t / 0.2
				elseif local_t < 0.6 then 1
				else math.max(0, 1 - (local_t - 0.6) / 0.4)
			lift = math.ceil(lift * 4) / 4
			local half = stone.part.Size.Y / 2
			stone.part.CFrame = CFrame.new(stone.x, -half + lift * (half * 1.6), stone.z)
				* CFrame.Angles(
					0.25 * math.cos(stone.angle),
					stone.angle,
					0.25 * math.sin(stone.angle)
				)
		end
		return nil
	end, function()
		for _, stone in stones do
			stone.part:Destroy()
		end
	end)
end

--[[ Vengeful Spirit ]]

local SPIRIT = Color3.fromRGB(150, 230, 255)
local SPIRIT_DARK = Color3.fromRGB(70, 150, 200)

--[[ One risen sword: the blade, its crossguard and the glow under it. ]]
type Blade = { parts: { BasePart }, slot: number }
local blades: { [Player]: { Blade } } = {}

local function makeBlade(slot: number): Blade
	local folder = Voxel.folder()
	local blade = Voxel.cube(Vector3.new(0.3, 2.2, 0.3), SPIRIT, true, folder)
	local guard = Voxel.cube(Vector3.new(1.1, 0.28, 0.28), SPIRIT_DARK, true, folder)
	local grip = Voxel.cube(Vector3.new(0.26, 0.7, 0.26), SPIRIT_DARK, true, folder)
	for _, part in { blade, guard, grip } do
		part.Transparency = 0.25
	end
	Voxel.light(blade, SPIRIT, 7, 1.4)
	return { parts = { blade, guard, grip }, slot = slot }
end

local function dropBlades(player: Player, keep: number)
	local mine = blades[player]
	if not mine then
		return
	end
	for index = #mine, keep + 1, -1 do
		for _, part in mine[index].parts do
			part:Destroy()
		end
		table.remove(mine, index)
	end
	if #mine == 0 then
		blades[player] = nil
	end
end

--[[ The risen swords hover at the Warden's shoulder and turn slowly, one
     to each side. Driven by the `Spirits` attribute the server owns, so a
     sword is up exactly while the server has one striking. ]]
local function spiritStep()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local want = player:GetAttribute("Spirits")
		want = if type(want) == "number" then math.floor(want) else 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or want <= 0 then
			dropBlades(player, 0)
			continue
		end
		local mine = blades[player]
		if not mine then
			mine = {}
			blades[player] = mine
		end
		while #mine < want do
			--[[ The sound is of a sword rising, so it plays as one does and
			     not on every strike it goes on to make. ]]
			SoundFx.play("fx_vengeful_spirit")
			table.insert(mine, makeBlade(#mine))
		end
		dropBlades(player, want)
		local config = Balance.Player.vengefulSpirit
		for index, held in mine do
			--[[ One either side, each turning on its own phase so two never
			     read as one object. ]]
			local side = if index % 2 == 1 then 1 else -1
			local spin = now * 1.6 + index * 2.2
			local bob = math.sin(now * 2.4 + index) * 0.22
			local offset =
				Vector3.new(config.offset.X * side, config.offset.Y + bob, config.offset.Z)
			local base = CFrame.new(root.Position + offset) * CFrame.Angles(0, spin, 0.35)
			held.parts[1].CFrame = base
			held.parts[2].CFrame = base * CFrame.new(0, -0.95, 0)
			held.parts[3].CFrame = base * CFrame.new(0, -1.45, 0)
		end
	end
end

--[[ A sword struck: a flash on what it hit, and a slash of cubes. ]]
local function onSpiritStrike(at: Vector3)
	Voxel.flash(Vector3.new(at.X, 1.2, at.Z), 2.4, SPIRIT, 0.16)
	Voxel.burst(Vector3.new(at.X, 1.2, at.Z), 7, { SPIRIT, SPIRIT_DARK }, 9, 0.45, 0.35, 5)
end

--[[ Bull Rush: dust torn up along the charge. ]]
local function onBullRush(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	SoundFx.play("fx_bull_rush")
	Voxel.burst(Vector3.new(root.Position.X, 0.5, root.Position.Z), 12, DUST, 10, 0.5, 0.4, 7)
end

--[[ Guard Break ]]

--[[ The guard breaking as the slam lands: plate cubes thrown off the blow
     and a ring of dust where they went.

     Hung on the client's own blow signal rather than anything new from the
     server: `FxEvents.blow` already says which blow of the combo landed and
     whether it was the heavy last one, which is exactly when the card acts.
]]
local PLATE = { Color3.fromRGB(176, 180, 188), Color3.fromRGB(120, 126, 136) }

local function onBlow(_index: number, _of: number, heavy: boolean)
	if not heavy or UpgradeFx.level("GuardBreak") <= 0 then
		return
	end
	local root = UpgradeFx.root()
	if not root then
		return
	end
	SoundFx.play("fx_guard_break")
	local at = root.Position + root.CFrame.LookVector * 3
	Voxel.flash(Vector3.new(at.X, 0.8, at.Z), 2.8, Color3.fromRGB(255, 245, 220), 0.12)
	Voxel.burst(Vector3.new(at.X, 1, at.Z), 10, PLATE, 13, 0.55, 0.4, 8)
	Voxel.ring(Vector3.new(at.X, 0, at.Z), 7, DUST, 0.35, 0.25)
end

--[[ Blood Pact ]]

local PACT = Color3.fromRGB(190, 30, 40)

--[[ While the pact is paying out, the Warden is lit red and bleeds embers.
     On the server's `BloodPact` attribute, which flips once as he crosses
     under half health rather than every frame he stays there. ]]
local pactGlow: { [Player]: { highlight: Highlight, embers: ParticleEmitter } } = {}

local function dropPact(player: Player)
	local held = pactGlow[player]
	if not held then
		return
	end
	pactGlow[player] = nil
	held.highlight:Destroy()
	held.embers:Destroy()
end

local function onPact(player: Player)
	local on = player:GetAttribute("BloodPact") == true
	if not on then
		dropPact(player)
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or pactGlow[player] then
		return
	end
	if player == Players.LocalPlayer then
		SoundFx.play("fx_blood_pact")
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = PACT
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = PACT
	highlight.OutlineTransparency = 0.2
	highlight.Adornee = character
	highlight.Parent = character
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(PACT)
	embers.Size = NumberSequence.new(0.22)
	embers.Lifetime = NumberRange.new(0.5, 0.9)
	embers.Rate = 14
	embers.Speed = NumberRange.new(1, 2.4)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, 3.5, 0)
	embers.LightEmission = 0.8
	embers.Parent = root
	pactGlow[player] = { highlight = highlight, embers = embers }
end

--[[ Counter Strike ]]

type Charge = { highlight: Highlight, embers: ParticleEmitter }
local charges: { [Player]: Charge } = {}

local function counterStep()
	for _, player in Players:GetPlayers() do
		local ready = player:GetAttribute("CounterReady") == true
		local held = sword(player.Character)
		local charge: Charge? = charges[player]
		if ready and held and (not charge or charge.highlight.Parent ~= held) then
			if charge then
				charge.highlight:Destroy()
				charge.embers:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.Name = "CounterGlow"
			highlight.FillColor = RED
			highlight.OutlineColor = Color3.fromRGB(255, 200, 190)
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = held
			local blade = held:FindFirstChildWhichIsA("BasePart")
			local embers = Instance.new("ParticleEmitter")
			embers.Color = ColorSequence.new(RED, Color3.fromRGB(255, 160, 120))
			embers.LightEmission = 1
			embers.Size = NumberSequence.new(0.35, 0)
			embers.Lifetime = NumberRange.new(0.3, 0.6)
			embers.Speed = NumberRange.new(1, 3)
			embers.SpreadAngle = Vector2.new(180, 180)
			embers.Rate = 30
			embers.Parent = blade
			local fresh: Charge = { highlight = highlight, embers = embers }
			charges[player] = fresh
			charge = fresh
		elseif (not ready or not held) and charge then
			charge.highlight:Destroy()
			charge.embers:Destroy()
			charges[player] = nil
			charge = nil
		end
		if charge then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 10)
			charge.highlight.FillTransparency = 0.25 + 0.45 * pulse
		end
	end
end

--[[ COUNTER! over the Warden, in the blocky font, popping and rising. ]]
local function counterWord(root: BasePart)
	local anchor = Voxel.cube(0.1, RED)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0))
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = ARCADE
	label.Text = "COUNTER!"
	label.TextScaled = true
	label.TextColor3 = RED
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	local from = anchor.Position
	Voxel.run(0.8, function(t)
		local pop = if t < 0.15
			then 0.6 + t / 0.15 * 0.6
			elseif t < 0.25 then 1.2 - (t - 0.15)
			else 1.1
		billboard.Size = UDim2.fromOffset(260 * pop, 60 * pop)
		anchor.CFrame = CFrame.new(from + Vector3.new(0, t * 2, 0))
		label.TextTransparency = math.clamp((t - 0.7) / 0.3, 0, 1)
		label.TextStrokeTransparency = label.TextTransparency
		return nil
	end, function()
		anchor:Destroy()
	end)
end

local function onCounter(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	SoundFx.play("fx_counter_strike")
	local look = root.CFrame.LookVector
	local front = root.Position + Vector3.new(look.X, 0, look.Z).Unit * 3
	Voxel.flash(front, 5, RED, 0.25)
	Voxel.burst(front, 20, HOT, 16, 0.6, 0.5, 8)
	Voxel.ring(Vector3.new(front.X, 0, front.Z), 6, { RED, Color3.fromRGB(255, 150, 130) }, 0.4)
	counterWord(root)
	if player == Players.LocalPlayer then
		TopDownCamera.shake(0.5, 0.25)
	end
end

local watching: { [Player]: boolean } = {}

local function watch(player: Player)
	if watching[player] then
		return
	end
	watching[player] = true
	player:GetAttributeChangedSignal("CounterAt"):Connect(function()
		onCounter(player)
	end)
	player:GetAttributeChangedSignal("BullRushAt"):Connect(function()
		onBullRush(player)
	end)
	player:GetAttributeChangedSignal("BloodPact"):Connect(function()
		onPact(player)
	end)
	onPact(player)
end

function WardenBuildFx.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		watching[player] = nil
		local charge = charges[player]
		if charge then
			charge.highlight:Destroy()
			charge.embers:Destroy()
			charges[player] = nil
		end
	end)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			local args = { ... }
			if kind == "TitanSlam" then
				onTitanSlam(args[1], args[2])
			elseif kind == "SpiritStrike" then
				onSpiritStrike(args[1])
			end
		end)
	FxEvents.blow:connect(onBlow)
	Players.PlayerRemoving:Connect(function(player: Player)
		dropBlades(player, 0)
		dropPact(player)
	end)
	RunService.Heartbeat:Connect(function()
		titanStep()
		counterStep()
		spiritStep()
	end)
end

return WardenBuildFx
