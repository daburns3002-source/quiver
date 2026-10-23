--!strict
--[[
	Hit feedback: enemy flash, damage numbers, death pop, screen shake.

	Entirely cosmetic and entirely driven by what the server says happened. The
	Phase 1 playtest question is whether standing still to shoot feels like a
	decision, and a hit that produces no visible reaction reads as a miss — so
	this is not polish, it is part of the thing being tested.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local HitSquash = require(script.Parent.HitSquash)
local TopDownCamera = require(script.Parent.Parent.Camera.TopDownCamera)

local HitFeedback = {}

local folder: Folder? = nil
local activeNumbers = 0

--[[ The screen-edge flare, built once and reused. Four gradient bands rather
     than one radial image, because a radial vignette needs an uploaded asset
     and this needs none. ]]
local vignette: { Frame } = {}

--[[
	Guards the character flash against overlapping hits.

	Two projectiles landing inside one flash would otherwise have the second
	one record the *flashed* colour as the character's original and restore to
	red permanently. Only the newest flash is allowed to restore, and only the
	first one captures.
]]
local flashToken = 0
local originalColors: { [BasePart]: Color3 } = {}

local function buildVignette()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("HitVignette")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HitVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	--[[ Above the HUD: it is a reaction to something happening now, and the
	     health bar it is reporting on sits underneath it. ]]
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	local reach = Balance.Feedback.vignetteReach
	local edges = {
		{ size = UDim2.fromScale(1, reach), position = UDim2.fromScale(0, 0), rotation = 90 },
		{
			size = UDim2.fromScale(1, reach),
			position = UDim2.fromScale(0, 1 - reach),
			rotation = 270,
		},
		{ size = UDim2.fromScale(reach, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{
			size = UDim2.fromScale(reach, 1),
			position = UDim2.fromScale(1 - reach, 0),
			rotation = 180,
		},
	}

	table.clear(vignette)

	for _, edge in edges do
		local frame = Instance.new("Frame")
		frame.Size = edge.size
		frame.Position = edge.position
		frame.BackgroundColor3 = Balance.Feedback.vignetteColor
		--[[ Starts invisible rather than hidden, so a hit only ever has to
		     tween one property on an object that is already laid out. ]]
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ZIndex = 1
		frame.Parent = gui

		local gradient = Instance.new("UIGradient")
		--[[ Opaque at the screen edge, gone by the inner lip. Rotation picks
		     which edge keypoint 0 sits on. ]]
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame

		table.insert(vignette, frame)
	end
end

function HitFeedback.start(parent: Instance)
	local existing = parent:FindFirstChild("HitFeedback")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "HitFeedback"
	created.Parent = parent
	folder = created
	activeNumbers = 0

	table.clear(originalColors)
	flashToken = 0

	buildVignette()
end

local function spawnDamageNumber(position: Vector3, amount: number, kind: string?)
	local tier = Device.tier()

	if activeNumbers >= tier.maxDamageNumbers then
		return
	end

	activeNumbers += 1

	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	--[[ Jittered so several hits in one spot do not stack into one unreadable
	     number. ]]
	anchor.Position = position
		+ Vector3.new((math.random() - 0.5) * 2, 2.5, (math.random() - 0.5) * 2)

	--[[ Anything the server did not name is drawn as a plain hit rather
	     than not at all. ]]
	local styles = Balance.Feedback.damageNumberStyles
	local style = (styles :: any)[kind or "Hit"] or styles.Hit

	--[[ As Archero 2 draws them (docs/ART-archero2.md §4, measured frame by
	     frame): chunky rounded type with a heavy dark edge, appearing a
	     little small, popping past full size within a twentieth of a
	     second, settling, drifting up, and only fading in its last stretch. ]]
	local width, height = 4 * style.scale, 2 * style.scale
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(width * 0.6, height * 0.6)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = style.color
	label.Text = "-" .. tostring(math.floor(amount + 0.5))
	label.Parent = billboard
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(20, 16, 24)
	edge.Thickness = 2.5 * style.scale
	edge.Parent = label

	anchor.Parent = folder

	local duration = Balance.Feedback.damageNumberDuration
	TweenService:Create(
		billboard,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(width * 1.15, height * 1.15) }
	):Play()
	task.delay(0.06, function()
		TweenService:Create(
			billboard,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(width, height) }
		):Play()
	end)

	TweenService:Create(
		anchor,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = anchor.Position + Vector3.new(0, Balance.Feedback.damageNumberRise, 0) }
	):Play()

	local fade = TweenInfo.new(
		duration * 0.4,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		duration * 0.6
	)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(edge, fade, { Transparency = 1 }):Play()

	task.delay(duration, function()
		activeNumbers -= 1
	end)

	Debris:AddItem(anchor, duration)
end

--[[
	Whites out an enemy for a frame or two.

	Walks the tagged skin rather than the PrimaryPart. The PrimaryPart is the
	hitbox, and the hitbox is invisible — flashing it lit up nothing at all
	once the archetypes got bodies. The tag is set by EnemyModel on the server
	and replicates with the part, so the client needs to know nothing about
	which archetype it is looking at.
]]
local function flash(model: Model)
	--[[ The footage's hit is a white wash over the whole body with a bright
	     white rim, not just a recolour. A Highlight draws both, fading out
	     over the flash. One per enemy, reused, since Roblox caps how many
	     can be drawn at once. ]]
	local highlight = model:FindFirstChild("HitFlash")
	if not highlight then
		local created = Instance.new("Highlight")
		created.Name = "HitFlash"
		created.FillColor = Color3.new(1, 1, 1)
		created.OutlineColor = Color3.new(1, 1, 1)
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.Parent = model
		highlight = created
	end
	local h = highlight :: Highlight
	h.FillTransparency = 0.35
	h.OutlineTransparency = 0
	TweenService:Create(
		h,
		TweenInfo.new(
			Balance.Feedback.hitFlashDuration * 1.6,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{
			FillTransparency = 1,
			OutlineTransparency = 1,
		}
	):Play()

	local painted: { [BasePart]: Color3 } = {}
	local any = false

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(EnemyDesigns.TintTag) then
			painted[descendant] = descendant.Color
			any = true
			descendant.Color = Balance.Feedback.hitFlashColor
		end
	end

	if not any then
		return
	end

	task.delay(Balance.Feedback.hitFlashDuration, function()
		for part, original in painted do
			--[[ Restores to what was there when the flash began, which may be
			     the telegraph colour rather than the design's. A hit landing
			     mid-wind-up must not cancel the tell. ]]
			if part.Parent then
				part.Color = original
			end
		end
	end)
end

function HitFeedback.onEnemyHit(model: Model, amount: number, position: Vector3, kind: string?)
	if typeof(model) == "Instance" and model:IsA("Model") then
		flash(model)
		--[[ A burn ticks several times a second; squashing on each would
		     keep the body wobbling the whole time it burns. ]]
		if kind ~= "Burn" then
			HitSquash.play(model)
		end
	end

	spawnDamageNumber(position, amount, kind)
end

--[[ Takes the position rather than the model: the enemy instance is destroyed
     on the server in the same step the remote fires, so no reference to it
     would reliably survive the trip. ]]
function HitFeedback.onEnemyDied(position: Vector3, amount: number?, kind: string?)
	if amount and amount > 0 then
		spawnDamageNumber(position, amount, kind)
	end

	--[[ As the footage shows a kill: the body bursts into soft white puffs
	     that swell and thin out, with a few yellow stars thrown clear. ]]
	local function piece(name: string, size: number, colour: Color3, neon: boolean): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = colour
		part.Parent = folder
		return part
	end

	local puffs = 6
	for index = 1, puffs do
		local angle = (index / puffs) * math.pi * 2 + math.random() * 0.5
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local puff =
			piece("DeathPuff", 1.2 + math.random() * 0.5, Color3.fromRGB(250, 250, 255), false)
		puff.Position = position + out * 0.4 + Vector3.new(0, 0.6, 0)
		TweenService
			:Create(puff, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = position + out * 1.8 + Vector3.new(0, 1.2 + math.random(), 0),
				Size = Vector3.one * (2.4 + math.random() * 0.8),
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(puff, 0.4)
	end

	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2 + math.random()
		local out = Vector3.new(math.cos(angle), 0.6, math.sin(angle))
		local star = Instance.new("Part")
		star.Name = "DeathStar"
		star.Size = Vector3.new(0.45, 0.45, 0.12)
		star.Anchored = true
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.CastShadow = false
		star.Material = Enum.Material.Neon
		star.Color = Color3.fromRGB(255, 226, 90)
		star.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
			* CFrame.Angles(0, 0, math.rad(45))
		star.Parent = folder
		TweenService
			:Create(star, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(position + Vector3.new(0, 1, 0) + out * 2.4)
					* CFrame.Angles(0, 0, math.rad(135)),
				Size = Vector3.new(0.1, 0.1, 0.05),
			})
			:Play()
		Debris:AddItem(star, 0.34)
	end
end

--[[
	Where an arrow strikes a body: a few short bright streaks thrown back
	from the point of contact and a quick white pop, as the footage shows.
	Drawn at the drawn arrow's own contact, so it lands where the arrow does.
]]
function HitFeedback.onArrowContact(position: Vector3, direction: Vector3)
	if activeNumbers >= Device.tier().maxDamageNumbers then
		return
	end

	local back = if direction.Magnitude > 1e-3 then -direction.Unit else Vector3.zAxis
	local across = back:Cross(Vector3.yAxis)
	across = if across.Magnitude > 1e-3 then across.Unit else Vector3.xAxis

	local pop = Instance.new("Part")
	pop.Name = "HitPop"
	pop.Shape = Enum.PartType.Ball
	pop.Size = Vector3.one * 0.6
	pop.Position = position
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.CanTouch = false
	pop.CastShadow = false
	pop.Material = Enum.Material.Neon
	pop.Color = Color3.fromRGB(255, 250, 230)
	pop.Parent = folder
	TweenService
		:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * 1.8,
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(pop, 0.13)

	for index = 1, 5 do
		local spread = (index - 3) * 0.45 + (math.random() - 0.5) * 0.3
		local heading = (back * math.cos(spread) + across * math.sin(spread) + Vector3.new(
			0,
			0.25,
			0
		)).Unit
		local length = 0.9 + math.random() * 0.6
		local streak = Instance.new("Part")
		streak.Name = "HitSpark"
		streak.Size = Vector3.new(0.09, 0.09, length)
		streak.Anchored = true
		streak.CanCollide = false
		streak.CanQuery = false
		streak.CanTouch = false
		streak.CastShadow = false
		streak.Material = Enum.Material.Neon
		streak.Color = if index % 2 == 0
			then Color3.fromRGB(255, 214, 90)
			else Color3.fromRGB(255, 255, 240)
		local from = position + heading * 0.3
		streak.CFrame = CFrame.lookAt(from + heading * length / 2, from + heading * length)
		streak.Parent = folder
		local to = from + heading * 1.4
		TweenService
			:Create(streak, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(to + heading * length / 2, to + heading * length),
				Size = Vector3.new(0.03, 0.03, length * 0.4),
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(streak, 0.15)
	end
end

--[[
	Turns the whole character red for a beat.

	Every BasePart, not just the root: the character is read as a silhouette
	from a fixed overhead camera, and tinting one part of it reads as a
	rendering glitch rather than as damage.
]]
local function flashCharacter(character: Model)
	flashToken += 1
	local token = flashToken

	local parts: { BasePart } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(parts, descendant)
			--[[ Only the first flash of a sequence records the real colour.
			     See `flashToken`. ]]
			if not originalColors[descendant] then
				originalColors[descendant] = descendant.Color
			end
		end
	end

	for _, part in parts do
		part.Color = Balance.Feedback.playerHitColor
	end

	task.delay(Balance.Feedback.playerHitDuration, function()
		--[[ A later hit owns the restore now. Bailing out here is what stops
		     two hits in quick succession from ending the first one early and
		     leaving the character lit for the remainder of the second. ]]
		if token ~= flashToken then
			return
		end

		for part, colour in originalColors do
			if part.Parent then
				part.Color = colour
			end
		end
		table.clear(originalColors)
	end)
end

--[[ A ring thrown off the character. The flash says *you*, this says *now* —
     it is still legible when the character itself is buried under projectiles
     and damage numbers. ]]
local function spawnPlayerBurst(position: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "PlayerHitBurst"
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.one * 2
	ring.Position = position
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Balance.Feedback.playerHitColor
	ring.Transparency = 0.3
	ring.Parent = folder

	local duration = Balance.Feedback.playerHitBurstDuration
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
		Size = Vector3.one * Balance.Feedback.playerHitBurstRadius,
		Transparency = 1,
	}):Play()

	Debris:AddItem(ring, duration)
end

local function flashVignette()
	local duration = Balance.Feedback.vignetteDuration
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, frame in vignette do
		--[[ Snapped on, tweened off. A hit that fades *in* has already stopped
		     being news by the time the player sees it. ]]
		frame.BackgroundTransparency = 0.25
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
	end
end

--[[
	A blast from Blast Arrows.

	Two parts, because they answer different questions. The ground ring snaps
	to the real radius immediately and only fades — the *area* is the
	information, and animating it outwards would mean the player reads the
	wrong size for most of the effect. The core flash expands, which is what
	makes it read as a detonation rather than as a decal appearing.

	Drawn at the radius the server sent, so a player who stacks Blast Arrows
	sees the thing they bought get bigger.
]]
function HitFeedback.onExplosion(position: Vector3, radius: number)
	local tier = Device.tier()

	if activeNumbers >= tier.maxDamageNumbers or radius <= 0 then
		return
	end

	activeNumbers += 1

	local duration = Balance.Feedback.explosionDuration

	--[[ Flat against the floor, which is the only orientation that reads as
	     an area from a fixed overhead camera. ]]
	local ring = Instance.new("Part")
	ring.Name = "ExplosionRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(position.X, 0.2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Balance.Feedback.explosionColor
	ring.Transparency = 0.25
	ring.Parent = folder

	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
		Transparency = 1,
	}):Play()

	local core = Instance.new("Part")
	core.Name = "ExplosionCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * (radius * 0.5)
	core.Position = position
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = Balance.Feedback.explosionCoreColor
	core.Transparency = 0.1
	core.Parent = folder

	TweenService
		:Create(core, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.one * (radius * 1.6),
			Transparency = 1,
		})
		:Play()

	--[[ A blast is a bigger event than an arrow landing, so it gets the shake
	     an arrow does not — gated on the tier, like every other shake. ]]
	if tier.enableScreenShake then
		TopDownCamera.shake(
			Balance.Feedback.shakeOnDamageMagnitude * 0.5,
			Balance.Feedback.shakeOnDamageDuration * 0.6
		)
	end

	task.delay(duration, function()
		activeNumbers -= 1
	end)

	Debris:AddItem(ring, duration)
	Debris:AddItem(core, duration)
end

--[[
	Soul Chain: a glowing link from the enemy hit to each enemy sharing the
	hit, gone in a moment. Drawn as thin neon bars at body height, so it
	reads as a chain between bodies rather than a mark on the floor.
]]
local LINK_COLOUR = Color3.fromRGB(190, 120, 255)
local LINK_DURATION = 0.28

function HitFeedback.onSoulLink(from: Vector3, reached: { Vector3 })
	if typeof(reached) ~= "table" then
		return
	end

	for _, to in reached do
		if typeof(to) ~= "Vector3" then
			continue
		end

		local a = Vector3.new(from.X, 1.6, from.Z)
		local b = Vector3.new(to.X, 1.6, to.Z)
		local length = (b - a).Magnitude
		if length < 1e-3 then
			continue
		end

		local bar = Instance.new("Part")
		bar.Name = "SoulLink"
		bar.Size = Vector3.new(0.22, 0.22, length)
		bar.CFrame = CFrame.lookAt((a + b) / 2, b)
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = LINK_COLOUR
		bar.Parent = folder

		TweenService:Create(bar, TweenInfo.new(LINK_DURATION, Enum.EasingStyle.Quad), {
			Size = Vector3.new(0.05, 0.05, length),
			Transparency = 1,
		}):Play()
		Debris:AddItem(bar, LINK_DURATION)
	end
end

--[[ Agility: a hit missed. A word over the player, so a dodge reads as the
     card working rather than as the enemy missing by luck. ]]
function HitFeedback.onPlayerDodged()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Dodge"
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromScale(4, 1)
	billboard.StudsOffset = Vector3.new(0, 3, 0)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "DODGE!"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 230, 255)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	billboard.Parent = root

	TweenService:Create(billboard, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 5, 0),
	}):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
	Debris:AddItem(billboard, 0.6)
end

--[[
	The player has been hit by something.

	Three cues, because one is not enough on a phone: the character turns red,
	a ring leaves it, and the screen edges flare. None of them is gated on a
	device tier — between them they are a handful of property writes and one
	part, and the one genuinely expensive cue here is the camera shake, which
	was already gated.
]]
function HitFeedback.onPlayerDamaged(_amount: number)
	local character = Players.LocalPlayer.Character

	if character then
		flashCharacter(character)

		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			spawnPlayerBurst(root.Position)
		end
	end

	flashVignette()

	if not Device.tier().enableScreenShake then
		return
	end

	TopDownCamera.shake(
		Balance.Feedback.shakeOnDamageMagnitude,
		Balance.Feedback.shakeOnDamageDuration
	)
end

return HitFeedback
