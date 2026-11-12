--!strict
--[[
	The shops' celebrations (owner, 2026-10-26: "heavy on dopamine"; redone
	2026-11-06: "right now they look terrible"): the egg hatch and the chest
	opening, one sequence drawn from `Util/RevealTimeline`'s clock.

	Egg: it drops in and bounces, wobbles harder and harder as cracks spread
	and light leaks out, bursts into shell pieces with a flash and confetti,
	and the pet pops out with a bounce; its rarity's colour bursts behind it
	and its banner slams down. Chest: it rattles, the padlocks pop off, light
	leaks from the lid's seam, the lid bursts open with beams and a fountain
	of coins, and the weapon rises out and lands with a pop. Legendary and
	Mythic build longer, darken the screen, shake the camera and glow; a
	Mythic says it is something special while it builds.

	What is opened (`look`), best first: the area's Tripo model
	(`GearAssets.models.eggs` / `.chests`, keyed by area) once it is
	imported and loaded, then its cut frames (`GearAssets.eggs` /
	`GearAssets.crates`), then the area's single picture
	(`GearAssets.areaPictures`, then Victory's chest), and last an egg or
	chest drawn here in the area's colours (`Config/Reveal.shells`), so an
	area with nothing yet still opens.

	Only server answers supply prizes. A tap skips ahead; the screen closes
	by itself.
]]
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Beats = require(ReplicatedStorage.Shared.Config.Reveal)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local PetGait = require(ReplicatedStorage.Shared.Util.PetGait)
local PetGaits = require(ReplicatedStorage.Shared.Config.PetGaits)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local RevealTimeline = require(ReplicatedStorage.Shared.Util.RevealTimeline)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local Reveal = {}
--[[ `key` is a pet's `Config/PetModels` name: the prize stands up as the same
     3D model the egg screen shows (`Kit.petModel`), and `icon` is only used if
     that model is not built. A weapon has none: the chest screen shows it as
     2D art, so its reveal does too (CLAUDE.md rule 14). ]]
export type Prize = {
	icon: string,
	name: string,
	rarity: string,
	note: string,
	fresh: boolean,
	key: string?,
}
--[[ What is opened. The pictures are "" where it has none: `whole` alone
     is a single picture (cracks are drawn over it), `crack1`/`crack2` an
     egg's cut stages, `bare`/`open` a chest's padlock-less and open
     frames. ]]
type Look = {
	kind: RevealTimeline.Kind,
	whole: string,
	crack1: string,
	crack2: string,
	bare: string,
	open: string,
	model: GearAssets.RevealModel?,
	--[[ The shell's (or wood's) two colours, for its pieces and the drawn
	     stand-in. ]]
	colours: { Color3 },
	--[[ The light inside it, in its area's colour (`Config/Reveal.glows`). ]]
	glow: Color3,
	special: string,
}
--[[ Something thrown: launched at `at` from (`x`, `y`). With `drag` it
     slows and drifts down at `g` (confetti); without, it falls under `g`. ]]
type Bit = {
	item: GuiObject,
	image: boolean,
	at: number,
	life: number,
	x: number,
	y: number,
	vx: number,
	vy: number,
	g: number,
	drag: number,
	spin: number,
	phase: number,
	w: number,
	h: number,
	flip: boolean,
}
type Crack = { item: Frame, stage: number, a: Vector2, b: Vector2 }
--[[ A big star shot out of a chest: it flies, slows, swells and pops. ]]
type Star = {
	item: Frame,
	star: ImageLabel,
	halo: ImageLabel,
	at: number,
	life: number,
	vx: number,
	vy: number,
	size: number,
	spin: number,
}
--[[ A speck of the dust that keeps rising off an open chest. `at` is after
     the burst, and it loops every `life`. ]]
type Dust = {
	item: ImageLabel,
	at: number,
	life: number,
	x: number,
	drift: number,
	size: number,
	phase: number,
}
--[[ One egg or chest of a reveal and everything around it. ]]
type Part = {
	prize: Prize,
	x: number,
	y: number,
	size: number,
	burst: number,
	colour: Color3,
	tier: Beats.Tier,
	leak: ImageLabel,
	aura: ImageLabel,
	inner: ImageLabel,
	leakRays: ImageLabel,
	shell: ImageLabel,
	drawn: Frame,
	view: ViewportFrame?,
	block: MeshPart?,
	native: Vector3?,
	lid: MeshPart?,
	cracks: { Crack },
	beams: { Frame },
	bits: { Bit },
	stars: { Star },
	dust: { Dust },
	ring: ImageLabel,
	ring2: ImageLabel,
	rays: ImageLabel,
	rays2: ImageLabel,
	glow: ImageLabel,
	sparkles: { ImageLabel },
	icon: ImageLabel,
	petView: ViewportFrame?,
	petModel: Model?,
	petGait: PetGaits.Gait?,
	petSize: number?,
	petBase: CFrame?,
	name: TextLabel,
	banner: ImageLabel,
	rarity: TextLabel,
	note: TextLabel,
	odds: TextLabel,
}
local showing = false
local pendingUntil = 0
function Reveal.busy(): boolean
	return showing or os.clock() < pendingUntil
end
function Reveal.request(action: () -> ())
	if Reveal.busy() then
		return
	end
	pendingUntil = os.clock() + 5
	action()
end
local INK = Color3.fromRGB(58, 36, 18)
--[[ A full-screen layer for the reveals: its dimmer, the shaken frame and
     its canvas, a white flash over it and a tap catcher over everything. ]]
local function layer(): (ScreenGui, Frame, Frame, Frame, Frame, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GearReveal"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 180
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer.PlayerGui
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	local shake = Instance.new("Frame")
	shake.BackgroundTransparency = 1
	shake.Size = UDim2.fromScale(1, 1)
	shake.Parent = gui
	local canvas = Kit.canvas(shake)
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 10
	flash.Parent = gui
	local tap = Instance.new("TextButton")
	tap.Font = Enum.Font.FredokaOne
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 20
	tap.Parent = gui
	return gui, dim, shake, canvas, flash, tap
end
-- places a centred item in the 1920 x 1080 canvas
local function put(item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position = UDim2.fromScale(x / 1920, y / 1080)
	item.Size = UDim2.fromScale(math.max(w, 0) / 1920, math.max(h, 0) / 1080)
end
local function centred<T>(item: T, z: number): T
	local gui = item :: any
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.ZIndex = z
	return item
end
local function clamp01(k: number): number
	return math.clamp(k, 0, 1)
end
-- 0 to 1 with a little overshoot, for things that pop in
local function popIn(k: number): number
	k = clamp01(k)
	return 1 + 2.7 * (k - 1) ^ 3 + 1.7 * (k - 1) ^ 2
end
--[[ A decaying wobble after an impact at `since` seconds: 1 at the hit. ]]
local function decay(since: number, rate: number, speed: number): number
	if since < 0 then
		return 0
	end
	return math.exp(-since * rate) * math.cos(since * speed)
end
local function block(parent: Instance, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = z
	f.Parent = parent
	return f
end
local function outline(item: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item
end
local function round(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = item
end
--[[ The egg or chest drawn in its colours, for an area with no picture or
     model yet: an egg with spots, or a chest with its bands and lock. ]]
local function drawn(parent: Instance, look: Look): Frame
	local main, trim = look.colours[1], look.colours[2] or Color3.new(1, 1, 1)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.ZIndex = 4
	box.Parent = parent
	local body = block(box, main, 4)
	body.Position = UDim2.fromScale(0.5, 0.5)
	outline(body, 4)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(main:Lerp(Color3.new(1, 1, 1), 0.35), main:Lerp(INK, 0.25))
	shine.Parent = body
	if look.kind == "egg" then
		body.Size = UDim2.fromScale(0.68, 0.86)
		round(body, 0.5)
		for _, spot in { { 0.32, 0.3, 0.2 }, { 0.66, 0.46, 0.15 }, { 0.42, 0.68, 0.17 } } do
			local s = block(body, trim, 5)
			s.Position = UDim2.fromScale(spot[1], spot[2])
			s.Size = UDim2.fromScale(spot[3], spot[3] * 0.8)
			round(s, 0.5)
		end
	else
		body.Size = UDim2.fromScale(0.9, 0.62)
		body.Position = UDim2.fromScale(0.5, 0.58)
		round(body, 0.08)
		local lid = block(box, main:Lerp(Color3.new(1, 1, 1), 0.12), 5)
		lid.Position, lid.Size = UDim2.fromScale(0.5, 0.33), UDim2.fromScale(0.94, 0.24)
		round(lid, 0.3)
		outline(lid, 4)
		for _, x in { 0.2, 0.8 } do
			local band = block(box, trim, 6)
			band.Position, band.Size = UDim2.fromScale(x, 0.55), UDim2.fromScale(0.08, 0.66)
			outline(band, 3)
		end
		local lock = block(box, trim, 7)
		lock.Position, lock.Size = UDim2.fromScale(0.5, 0.47), UDim2.fromScale(0.14, 0.16)
		outline(lock, 3)
	end
	return box
end
--[[ How much of the viewport's height the model fills when it is sitting
     still. The rest is room for the squash, the shake and the chest's tip,
     none of which may clip the frame's edge. ]]
local MODEL_FILL = 0.68
local MODEL_FOV = 40
--[[ Every egg and chest model comes out of its import with its front on -Z,
     away from the viewport's camera (measured on all twelve, 2026-11-08), so
     each is turned to face it. ]]
local MODEL_FACING = math.pi
--[[ A two-piece chest's viewport, this much bigger with the chest the same size
     in it, so a lid thrown open has room. ]]
local CHEST_VIEW = 1.5
--[[ How far a two-piece chest's lid opens. ]]
local LID_OPEN = math.rad(108)
--[[ The rock either side of facing the camera, in radians, and its speed. It
     replaced a slow full turn, which swung the padlock away as the chest opened. ]]
local MODEL_SWAY = math.rad(14)
local MODEL_SWAY_SPEED = 1.1
--[[ An egg's spin while it wobbles and cracks, in radians a second (owner,
     2026-11-08: "make sure the egg spins"). ]]
local EGG_SPIN = 1.4
--[[ The same rock for a pet standing out of its egg, a little less. ]]
local PET_SWAY = math.rad(10)
local PET_SWAY_SPEED = 1.3

--[[ The reveals' models, loaded once and cloned per reveal.

     A MeshPart, not a block with a `SpecialMesh`: a modern mesh asset does
     not load into one of those at all, and draws nothing. MeshParts come
     from `AssetService:CreateMeshPartAsync`, which yields while it fetches,
     and a reveal has to be on screen the frame it is asked for -- so they
     are fetched when the client starts and a reveal that finds its model
     missing plays its pictures instead. ]]
local templates: { [string]: MeshPart } = {}

function Reveal.preloadModels()
	local specs: { { mesh: string, texture: string } } = {}
	for _, spec in GearAssets.models.eggs do
		table.insert(specs, spec)
	end
	for _, spec in GearAssets.models.chests do
		local parts = spec.parts
		if parts then
			table.insert(specs, parts.base)
			table.insert(specs, parts.lid)
		else
			table.insert(specs, spec)
		end
	end
	--[[ A texture is only fetched once it is drawn, so without this the first
	     chest of a session opened plain grey (seen 2026-11-08). ]]
	local textures = {}
	for _, spec in specs do
		table.insert(textures, spec.texture)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(textures)
		end)
	end)
	for _, spec in specs do
		if templates[spec.mesh] then
			continue
		end
		task.spawn(function()
			local ok, part = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(spec.mesh), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Precise,
				})
			end)
			if ok and part then
				part.TextureID = spec.texture
				part.Anchored = true
				part.CanCollide = false
				part.CastShadow = false
				templates[spec.mesh] = part
			end
		end)
	end
end

--[[ An egg or chest as its model, in a viewport of its own. The camera is
     placed off the mesh's own height rather than by eye, so a model of
     another size frames itself. ]]
local function shellModel(root: Instance, template: MeshPart): (ViewportFrame, MeshPart)
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 0.94, 0.8)
	view.LightDirection = Vector3.new(-0.3, -1, -0.5)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.ZIndex = 4
	view.Parent = root
	local world = Instance.new("WorldModel")
	world.Parent = view
	local made = template:Clone()
	made.CFrame = CFrame.new()
	made.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = MODEL_FOV
	local away = (made.Size.Y / MODEL_FILL) / 2 / math.tan(math.rad(MODEL_FOV) / 2)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, away), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	return view, made
end

--[[ A chest as its lid and base, in one viewport framed on the closed chest. ]]
local function chestModel(
	root: Instance,
	parts: GearAssets.RevealParts,
	baseTemplate: MeshPart,
	lidTemplate: MeshPart
): (ViewportFrame, MeshPart, MeshPart)
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 0.94, 0.8)
	view.LightDirection = Vector3.new(-0.3, -1, -0.5)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.ZIndex = 4
	view.Parent = root
	local world = Instance.new("WorldModel")
	world.Parent = view
	local base = baseTemplate:Clone()
	base.Parent = world
	local lid = lidTemplate:Clone()
	lid.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = MODEL_FOV
	local away = (parts.size.Y * CHEST_VIEW / MODEL_FILL) / 2 / math.tan(math.rad(MODEL_FOV) / 2)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, away), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	return view, base, lid
end

--[[ The cracks, per stage, as lines in the shell's own box (-0.5..0.5,
     down positive). An egg's zigzag spreads from its middle; a chest's
     light runs out along its lid's seam. ]]
local EGG_CRACKS: { { { number } } } = {
	{ { -0.05, -0.05, 0.06, 0.02 }, { 0.06, 0.02, 0, 0.1 }, { 0, 0.1, 0.1, 0.18 } },
	{
		{ -0.05, -0.05, -0.16, -0.12 },
		{ -0.16, -0.12, -0.1, -0.22 },
		{ 0.06, 0.02, 0.2, -0.02 },
		{ 0.2, -0.02, 0.24, 0.08 },
	},
	{
		{ 0, 0.1, -0.14, 0.14 },
		{ -0.14, 0.14, -0.24, 0.06 },
		{ -0.1, -0.22, 0.02, -0.3 },
		{ 0.1, 0.18, 0.18, 0.28 },
	},
}
local CHEST_CRACKS: { { { number } } } = {
	{ { -0.1, -0.06, 0.1, -0.06 } },
	{ { -0.26, -0.06, -0.1, -0.06 }, { 0.1, -0.06, 0.26, -0.06 } },
	{ { -0.38, -0.06, -0.26, -0.06 }, { 0.26, -0.06, 0.38, -0.06 }, { 0, -0.06, 0, 0.04 } },
}
--[[ Draws a thrown bit at `t`: closed form, so a skip lands it right. ]]
local function fly(bit: Bit, t: number)
	local u = t - bit.at
	local item = bit.item
	if u < 0 or u > bit.life then
		item.Visible = false
		return
	end
	item.Visible = true
	local x: number, y: number
	if bit.drag > 0 then
		local slowed = (1 - math.exp(-bit.drag * u)) / bit.drag
		x = bit.x + bit.vx * slowed + math.sin(u * 5 + bit.phase) * 24
		y = bit.y + bit.vy * slowed + bit.g * u
	else
		x = bit.x + bit.vx * u
		y = bit.y + bit.vy * u + 0.5 * bit.g * u * u
	end
	local w = if bit.flip
		then bit.w * math.max(0.15, math.abs(math.cos(u * 9 + bit.phase)))
		else bit.w
	put(item, x, y, w, bit.h)
	item.Rotation = bit.phase * 57 + bit.spin * u
	local fade = 1 - clamp01((bit.life - u) / 0.35)
	if bit.image then
		(item :: ImageLabel).ImageTransparency = fade
	else
		item.BackgroundTransparency = fade
	end
end
--[[ Nudges the world's camera by the shake, on top of whatever moves it:
     the offset is taken back off before the camera script's next frame
     can be mistaken for it. Returns the stop. ]]
local function shakeCamera(amount: () -> number, clock: () -> number): () -> ()
	local name = "RevealShake"
	local written: CFrame? = nil
	local base: CFrame? = nil
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = camera.CFrame
		local from = if written and base and now == written then base else now
		local a = amount()
		local t = clock()
		local nudge = CFrame.Angles(
			math.rad(math.sin(t * 61) * a * 0.5),
			math.rad(math.cos(t * 53) * a * 0.5),
			math.rad(math.sin(t * 47) * a * 0.35)
		)
		base = from
		written = from * nudge
		camera.CFrame = written :: CFrame
	end)
	return function()
		RunService:UnbindFromRenderStep(name)
		local camera = workspace.CurrentCamera
		if camera and written and base and camera.CFrame == written then
			camera.CFrame = base
		end
	end
end

--[[ The reveal: every egg or chest of the press, in step. ]]
local function play(look: Look, prizes: { Prize }, chanceOf: (Prize) -> number, finished: () -> ())
	local rarities = {}
	for _, prize in prizes do
		table.insert(rarities, prize.rarity)
	end
	local line = RevealTimeline.build(look.kind, rarities)
	local top = line.tier
	local gui, dim, shake, canvas, flash, tap = layer()
	local random = Random.new()
	local single = #prizes == 1
	local size = if single then 480 else 330
	local chest = look.kind == "crate"
	local model = look.model
	local template = if model then templates[model.mesh] else nil
	-- a picture with no cut stages gets drawn cracks; a chest always leaks
	local drawCracks = chest or look.crack1 == "" or template ~= nil
	-- a chest with its 3D model plays the seven steps; without it, the frames
	local pieces = if chest and model then model.parts else nil
	local baseTemplate = if pieces then templates[pieces.base.mesh] else nil
	local lidTemplate = if pieces then templates[pieces.lid.mesh] else nil
	local twoPiece = baseTemplate ~= nil and lidTemplate ~= nil
	local juicy = chest and (template ~= nil or twoPiece)
	local chestBeats = Beats.crate
	local parts: { Part } = {}
	for index, prize in prizes do
		local root = Instance.new("Frame")
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
		root.Parent = canvas
		local colour = Kit.colour(prize.rarity)
		local tier = Beats.tiers[prize.rarity] or Beats.tiers.Common
		local x = if single then 960 else 960 + (index - 2) * 560
		local y = if single then 470 else 450
		local burst = line.bursts[index]
		local part: Part = {
			prize = prize,
			x = x,
			y = y,
			size = size,
			burst = burst,
			colour = colour,
			tier = tier,
			leakRays = centred(Kit.image(root, GearAssets.fx.rays), 1),
			leak = centred(Kit.image(root, GearAssets.fx.glow), 2),
			aura = centred(Kit.image(root, GearAssets.fx.glow), 2),
			inner = centred(Kit.image(root, GearAssets.fx.glow), 5),
			rays2 = centred(Kit.image(root, GearAssets.fx.rays), 2),
			rays = centred(Kit.image(root, GearAssets.fx.rays), 2),
			glow = centred(Kit.image(root, GearAssets.fx.glow), 3),
			ring = centred(Kit.image(root, GearAssets.fx.ring), 3),
			ring2 = centred(Kit.image(root, GearAssets.fx.ring), 3),
			shell = centred(Kit.image(root, look.whole), 4),
			drawn = drawn(root, look),
			cracks = {},
			beams = {},
			bits = {},
			stars = {},
			dust = {},
			sparkles = {},
			icon = centred(Kit.image(root, prize.icon), 7),
			name = centred(Kit.label(root, string.upper(prize.name)), 9),
			banner = centred(Kit.image(root, GearAssets.showcase.banner), 9),
			rarity = Kit.label(root, string.upper(prize.rarity)),
			note = centred(Kit.label(root, prize.note, Kit.gold), 11),
			odds = centred(Kit.label(root, "", Kit.gold), 9),
		}
		part.rarity.Parent = part.banner
		part.rarity.ZIndex = 10
		part.rarity.AnchorPoint = Vector2.new(0.5, 0.5)
		part.rarity.Position, part.rarity.Size =
			UDim2.fromScale(0.5, 0.44), UDim2.fromScale(0.7, 0.36)
		part.banner.ImageColor3 = colour
		part.ring.ImageColor3 = colour
		part.ring2.ImageColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.4)
		part.glow.ImageColor3 = colour
		part.rays.ImageColor3 = Color3.new(1, 1, 1):Lerp(colour, 0.7)
		part.rays2.ImageColor3 = colour
		if tier.glow or tier.special then
			local chance = chanceOf(prize)
			if chance > 0 then
				part.odds.Text = "1 IN " .. tostring(math.round(1 / chance))
			end
		end
		if pieces and baseTemplate and lidTemplate then
			local view, base, lid = chestModel(root, pieces, baseTemplate, lidTemplate)
			part.view, part.block, part.native, part.lid = view, base, pieces.size, lid
		elseif template then
			local view, made = shellModel(root, template)
			part.view, part.block, part.native = view, made, made.Size
		end
		local petView = if prize.key then Kit.petModel(root, prize.key, false) else nil
		if petView then
			petView.AnchorPoint = Vector2.new(0.5, 0.5)
			petView.ZIndex = 7
			petView.Visible = false
			local world = petView:FindFirstChildOfClass("WorldModel")
			local petModel = if world then world:FindFirstChildOfClass("Model") else nil
			part.petView, part.petModel = petView, petModel
			part.petBase = if petModel then petModel:GetPivot() else nil
			if petModel and prize.key then
				part.petGait = PetGait.of(prize.key)
				-- a gait is in the studs of a pet at heel, 2.4 tall
				part.petSize = petModel:GetExtentsSize().Y / 2.4
			end
		end
		if drawCracks and not juicy then
			local pattern: { { { number } } } = if chest then CHEST_CRACKS else EGG_CRACKS
			for stage, lines in ipairs(pattern) do
				for _, l in lines do
					table.insert(part.cracks, {
						item = block(root, Color3.new(1, 1, 1), 5),
						stage = stage,
						a = Vector2.new(l[1], l[2]),
						b = Vector2.new(l[3], l[4]),
					})
				end
			end
		end
		if chest then
			for n = 1, 5 do
				local beam = block(root, Color3.new(1, 1, 1):Lerp(colour, 0.45), 3)
				beam.AnchorPoint = Vector2.new(0.5, 1)
				beam.Rotation = (n - 3) * 18
				local fade = Instance.new("UIGradient")
				fade.Rotation = 90
				fade.Transparency = NumberSequence.new(1, 0.05)
				fade.Parent = beam
				table.insert(part.beams, beam)
			end
		end
		if tier.glow then
			for _ = 1, 8 do
				local sparkle = centred(Kit.image(root, GearAssets.fx.sparkle), 8)
				sparkle.ImageColor3 = Color3.new(1, 1, 1):Lerp(colour, 0.3)
				table.insert(part.sparkles, sparkle)
			end
		end
		local scale = size / 480
		local function throw(
			item: GuiObject,
			image: boolean,
			launch: number,
			bit: { [string]: any }
		)
			local b: Bit = {
				item = item,
				image = image,
				at = launch,
				life = bit.life or 1.2,
				x = bit.x or x,
				y = bit.y or y,
				vx = bit.vx,
				vy = bit.vy,
				g = bit.g or 2600,
				drag = bit.drag or 0,
				spin = bit.spin or random:NextNumber(-540, 540),
				phase = random:NextNumber(0, math.pi * 2),
				w = bit.w,
				h = bit.h,
				flip = bit.flip == true,
			}
			item.Visible = false
			table.insert(part.bits, b)
		end
		if juicy then
			local count = if tier.glow then chestBeats.rareStars else chestBeats.stars
			if not single then
				count = math.ceil(count * 0.6)
			end
			for n = 1, count do
				local holder = centred(Instance.new("Frame"), 6)
				holder.BackgroundTransparency = 1
				holder.Visible = false
				holder.Parent = root
				local halo = Kit.image(holder, GearAssets.fx.glow)
				halo.AnchorPoint = Vector2.new(0.5, 0.5)
				halo.Position, halo.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(2.6, 2.6)
				halo.ImageColor3 = Kit.gold
				halo.ZIndex = 1
				local star = Kit.image(holder, GearAssets.fx.star)
				star.AnchorPoint = Vector2.new(0.5, 0.5)
				star.Position, star.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
				star.ImageColor3 = Color3.fromRGB(255, 240, 175)
					:Lerp(colour, if tier.glow then 0.4 else 0)
				star.ZIndex = 2
				-- a fan upward, out of the top of the chest
				local across = (n - 0.5) / count + random:NextNumber(-0.05, 0.05)
				local angle = math.rad(-90 + (across - 0.5) * 110)
				local speed = random:NextNumber(1050, 1700) * scale
				table.insert(part.stars, {
					item = holder,
					star = star,
					halo = halo,
					at = burst + random:NextNumber(0.03, 0.24),
					life = random:NextNumber(0.75, 1.1),
					vx = math.cos(angle) * speed,
					vy = math.sin(angle) * speed,
					size = random:NextNumber(70, 130) * scale,
					spin = random:NextNumber(-220, 220),
				})
			end
			for _ = 1, if single then chestBeats.dust else math.ceil(chestBeats.dust * 0.6) do
				local speck = centred(Kit.image(root, GearAssets.fx.sparkle), 8)
				speck.ImageColor3 = Color3.fromRGB(255, 236, 170)
				speck.Visible = false
				table.insert(part.dust, {
					item = speck,
					at = random:NextNumber(0.2, 1.1),
					life = random:NextNumber(1.1, 1.9),
					x = random:NextNumber(-0.36, 0.36) * size,
					drift = random:NextNumber(10, 34),
					size = random:NextNumber(14, 30) * scale,
					phase = random:NextNumber(0, math.pi * 2),
				})
			end
		elseif chest then
			-- the two padlocks pop off on the second crack
			for side = -1, 1, 2 do
				local lock = block(root, look.colours[2], 6)
				outline(lock, 3)
				throw(lock, false, line.cracks[2], {
					x = x + side * 60 * scale,
					y = y,
					vx = side * random:NextNumber(300, 520),
					vy = -random:NextNumber(700, 950),
					w = 46 * scale,
					h = 52 * scale,
				})
			end
			for _ = 1, 6 do
				local splinter = block(root, look.colours[1], 6)
				outline(splinter, 2)
				throw(splinter, false, burst, {
					y = y - 40 * scale,
					vx = random:NextNumber(-700, 700),
					vy = -random:NextNumber(600, 1100),
					w = random:NextNumber(18, 30) * scale,
					h = random:NextNumber(50, 80) * scale,
				})
			end
			for _ = 1, Beats.crate.coins do
				local coin = Kit.image(root, EndScreenAssets.coin)
				coin.AnchorPoint = Vector2.new(0.5, 0.5)
				coin.ZIndex = 6
				local s = random:NextNumber(44, 64) * scale
				throw(coin, true, burst + random:NextNumber(0, 0.25), {
					y = y - 60 * scale,
					vx = random:NextNumber(-560, 560),
					vy = -random:NextNumber(1150, 1650),
					w = s,
					h = s,
					life = 1.4,
					spin = 0,
					flip = true,
				})
			end
		else
			for n = 1, Beats.shards do
				local shard = block(root, look.colours[(n % 2) + 1] or look.colours[1], 6)
				outline(shard, 3)
				local angle = (n / Beats.shards) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
				local speed = random:NextNumber(700, 1250)
				throw(shard, false, burst, {
					x = x + math.cos(angle) * 60 * scale,
					y = y + math.sin(angle) * 70 * scale,
					vx = math.cos(angle) * speed,
					vy = math.sin(angle) * speed - 650,
					w = random:NextNumber(46, 96) * scale,
					h = random:NextNumber(40, 80) * scale,
				})
			end
		end
		-- the confetti, out of the burst; a Legendary or Mythic gets a rain of it too
		local palette =
			{ colour, Kit.gold, Color3.new(1, 1, 1), colour:Lerp(Color3.new(1, 1, 1), 0.5) }
		local count = math.ceil(Beats.confetti / #prizes)
		for n = 1, count do
			-- a 3D chest's burst is its stars
			if not juicy then
				local bit = block(root, palette[(n % #palette) + 1], 12)
				throw(bit, false, burst, {
					vx = random:NextNumber(-1500, 1500),
					vy = random:NextNumber(-1700, -500),
					g = random:NextNumber(150, 260),
					drag = 3,
					w = 18,
					h = 28,
					life = 2.4,
					flip = true,
				})
			end
			if tier.glow then
				local rain = block(root, palette[(n % #palette) + 1], 12)
				throw(rain, false, line.banner + random:NextNumber(0, 0.8), {
					x = random:NextNumber(0, 1920),
					y = -40,
					vx = random:NextNumber(-80, 80),
					vy = 0,
					g = random:NextNumber(260, 380),
					drag = 2,
					w = 18,
					h = 28,
					life = 3.2,
					flip = true,
				})
			end
		end
		table.insert(parts, part)
	end
	local special = centred(Kit.label(canvas, look.special, Kit.colour(line.top)), 12)
	put(special, 960, 960, 1300, 64)
	special.Visible = false

	-- the shake: impacts that ring out, and a rumble under a big build
	local hits: { { number } } = { { line.drop, 0.3 } }
	for _, crack in line.cracks do
		table.insert(hits, { crack, 0.2 * (1 + top.build) })
	end
	for _, burst in line.bursts do
		table.insert(hits, { burst, top.shake })
	end
	if top.glow then
		table.insert(hits, { line.banner, top.shake * 0.6 })
	end
	local started = os.clock()
	local offset = 0
	local function clock(): number
		return os.clock() - started + offset
	end
	local shakeNow = 0
	local function shaking(t: number): number
		local a = 0
		for _, hit in hits do
			if t >= hit[1] then
				a += hit[2] * math.exp(-(t - hit[1]) * 9)
			end
		end
		if top.glow and t < line.burst then
			a += top.shake * 0.18 * clamp01((t - line.settle) / (line.burst - line.settle))
		end
		return a
	end
	local stopCamera = shakeCamera(function()
		return shakeNow
	end, clock)
	local played = { open = false, rare = false, fresh = false }
	local stopGlitter: (() -> ())? = nil
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		gui:Destroy()
		finished()
	end
	local function pose()
		local t = clock()
		if t >= line.done then
			close()
			return
		end
		local gone = clamp01((t - line.leave) / (line.done - line.leave))
		-- the screen dims, darker as a big pull builds, easing back after
		local build = clamp01((t - line.settle) / (line.burst - line.settle))
		local darkness = 0.4 + top.dark * 0.55 * build ^ 2
		if t >= line.burst then
			darkness = 0.4 + top.dark * 0.55 * (1 - 0.5 * clamp01((t - line.burst) / 0.6))
		end
		darkness *= clamp01(t / 0.2) * (1 - gone)
		dim.BackgroundTransparency = 1 - darkness
		special.Visible = top.special and t >= line.settle and t < line.burst
		special.TextTransparency = 0.5 - 0.5 * math.sin(t * 6)
		for _, part in parts do
			local x, y = part.x, part.y
			local b = part.burst
			local u = t - line.drop
			-- the fall, the landing's squash and the bounce
			local fall = clamp01(t / line.drop)
			local px, py = x, y - (1 - fall) ^ 2 * 900
			local sx, sy = 1 - 0.1 * fall, 1 + 0.16 * fall
			if u >= 0 then
				local squash = 0.26 * decay(u, 7, 26)
				sx, sy = 1 + squash, 1 - squash
				py = y - math.abs(math.sin(u * math.pi / 0.2)) * 70 * math.exp(-u * 6)
			end
			-- the wobble: harder and faster to the burst, a hop on each crack
			local w = clamp01((t - line.settle) / (b - line.settle)) ^ 1.6
			local rot = math.sin(t * (9 + 24 * w)) * w * (12 + 6 * top.shake)
			px += math.sin(t * 57) * w * 6 * top.shake
			if chest then
				rot *= if juicy then 0.7 else 0.4
				py -= math.abs(math.sin(t * 38)) * w * 16
			end
			for n, crack in line.cracks do
				local since = t - crack
				if not juicy and since >= 0 and since < 0.4 then
					py -= math.sin(clamp01(since / 0.22) * math.pi) * (24 + n * 10)
					local jolt = 0.12 * decay(since, 10, 30)
					sx, sy = sx + jolt, sy - jolt
				end
			end
			-- the breath in before it bursts
			local inhale = if juicy then 0 else clamp01((t - (b - 0.16)) / 0.16)
			sx, sy = sx + inhale * 0.16, sy - inhale * 0.14
			--[[ A 3D chest stops shaking, squashes down, then springs up tall
			     and comes back down on the burst. ]]
			if juicy and t < b then
				local stretchAt = b - chestBeats.stretch
				local squashed = clamp01((t - (stretchAt - chestBeats.squash)) / chestBeats.squash)
				squashed = 1 - (1 - squashed) ^ 2
				local risen = clamp01((t - stretchAt) / chestBeats.stretch)
				rot *= 1 - squashed
				px = x + (px - x) * (1 - squashed)
				sx, sy = sx + 0.26 * squashed, sy - 0.36 * squashed
				if risen > 0 then
					local tall = 1 - (1 - math.min(risen / 0.5, 1)) ^ 2
					sx, sy = 1.26 + (0.8 - 1.26) * tall, 0.64 + (1.38 - 0.64) * tall
					local height = chestBeats.height * size / 480
					local up = if risen < 0.65
						then 1 - (1 - risen / 0.65) ^ 2
						else 1 - ((risen - 0.65) / 0.35) ^ 2
					py -= up * height
				end
			end
			-- the burst: an egg is gone, a chest's lid flies open
			local burst = t >= b
			local since = t - b
			local open = 0
			if chest and burst then
				open = clamp01(since / 0.12)
				-- a one-piece chest has no lid to fling: the whole chest
				-- bursts wide, and (no 3D model) hops, before it sinks away
				local pop = (if template then 0.3 else 0.18) * decay(since, 8, 24)
				sx, sy = 1 + pop, 1 - pop
				rot = 0
				py = if juicy
					then y + clamp01((since - 0.5) / 0.5) * (if twoPiece then 60 else 100)
					else y - math.sin(clamp01(since / 0.3) * math.pi) * 90 + clamp01(
						(since - 0.35) / 0.5
					) * 140
			end
			-- its squash is from the ground up, not the middle
			if juicy and u >= 0 then
				py += size * MODEL_FILL * 0.5 * (1 - sy)
			end
			local shellAlpha = if twoPiece
				then clamp01((t - (line.banner + 0.6)) / 0.4)
				elseif chest then clamp01((t - (line.banner - 0.1)) / 0.35)
				else (if burst then 1 else 0)
			local cracked = 0
			for n, crack in line.cracks do
				if t >= crack then
					cracked = n
				end
			end
			local picture = look.whole
			if chest then
				picture = if burst and look.open ~= ""
					then look.open
					elseif cracked >= 2 and look.bare ~= "" then look.bare
					else look.whole
			elseif not drawCracks then
				picture = if cracked >= 3
					then look.crack2
					elseif cracked >= 2 then look.crack1
					else look.whole
			end
			local view, made, native = part.view, part.block, part.native
			local hasPicture = picture ~= "" and view == nil
			part.shell.Visible = hasPicture and shellAlpha < 1
			part.shell.Image = picture
			part.shell.Rotation = rot
			part.shell.ImageTransparency = shellAlpha
			put(part.shell, px, py, size * sx, size * sy)
			part.drawn.Visible = not hasPicture and view == nil and shellAlpha < 1
			part.drawn.Rotation = rot
			put(part.drawn, px, py, size * sx, size * sy)
			if view and made and native then
				view.Visible = shellAlpha < 1
				view.ImageTransparency = shellAlpha
				local lidPart = part.lid
				local across = if lidPart then size * CHEST_VIEW else size
				put(view, px, py, across, across)
				if not lidPart then
					made.Size = native * Vector3.new(sx, sy, sx)
				end
				local tips = model ~= nil and model.tips
				-- turned to the camera first, so the wobble is still a wobble on screen
				-- an egg keeps turning through its hatch; a chest only rocks
				local turn = if chest
					then math.sin(t * MODEL_SWAY_SPEED) * MODEL_SWAY
					else t * EGG_SPIN
				made.CFrame = CFrame.Angles(
					if tips then -open * math.rad(38) else 0,
					0,
					math.rad(-rot)
				) * CFrame.Angles(0, MODEL_FACING + turn, 0)
				if lidPart and pieces then
					--[[ Squashed with the chest, then the lid turned on its
					     hinge: it rattles as the chest shakes, and on the slam
					     it is thrown open and bounces. ]]
					local frame = made.CFrame
					local stretch = Vector3.new(sx, sy, sx)
					local hinge = pieces.hinge * stretch
					local angle = math.abs(math.sin(t * 40)) * w ^ 2 * math.rad(5)
					if t >= b - chestBeats.stretch - chestBeats.squash and t < b then
						angle = 0
					elseif t >= b then
						local thrown = clamp01(since / 0.14)
						angle = LID_OPEN * (1 - (1 - thrown) ^ 3)
							+ math.rad(12) * decay(since - 0.14, 6, 18)
					end
					made.Size = pieces.base.size * stretch
					made.CFrame = frame * CFrame.new(pieces.base.offset * stretch)
					lidPart.Size = pieces.lid.size * stretch
					lidPart.CFrame = frame
						* CFrame.new(hinge)
						* CFrame.Angles(angle, 0, 0)
						* CFrame.new(pieces.lid.offset * stretch - hinge)
				end
			end
			-- the cracks, glowing, turning with the shell
			-- the light inside: the area's, warming to the rarity's in a big pull
			local light = look.glow:Lerp(Color3.new(1, 1, 1), 0.25)
			if part.tier.glow then
				light = light:Lerp(part.colour, w * 0.7)
			end
			local angle = math.rad(rot)
			local cosA, sinA = math.cos(angle), math.sin(angle)
			local function place(v: Vector2): Vector2
				local lx, ly = v.X * size * sx, v.Y * size * sy
				return Vector2.new(px + lx * cosA - ly * sinA, py + lx * sinA + ly * cosA)
			end
			for _, crack in part.cracks do
				local shown = cracked >= crack.stage and (not burst or (chest and open < 1))
				crack.item.Visible = shown
				if shown then
					local grow = popIn((t - line.cracks[crack.stage]) / 0.1)
					local a, c = place(crack.a), place(crack.b)
					local mid = (a + c) / 2
					local length = (c - a).Magnitude * grow
					put(crack.item, mid.X, mid.Y, length + 6, 8 * size / 480)
					crack.item.Rotation = math.deg(math.atan2(c.Y - a.Y, c.X - a.X))
					crack.item.BackgroundColor3 = light
				end
			end
			-- the light leaking out as it cracks
			local leaking = clamp01((t - line.cracks[1]) / (b - line.cracks[1]))
			part.leak.Visible = not burst and w > 0
			part.leak.ImageColor3 = light
			put(part.leak, px, py, size * (1 + 0.7 * w), size * (1 + 0.7 * w))
			part.leak.ImageTransparency = 1 - 0.8 * w
			part.leakRays.Visible = not juicy and not burst and leaking > 0
			part.leakRays.ImageColor3 = light
			part.leakRays.Rotation = t * 80
			put(part.leakRays, px, py, size * (1.1 + leaking), size * (1.1 + leaking))
			part.leakRays.ImageTransparency = 1 - 0.65 * leaking
			--[[ The glow of the thing itself (owner, 2026-11-06: "make sure there
			     is a glow in the egg and chest"): a halo from the landing that
			     swells and pulses as it wobbles, and a light inside it -- over
			     the egg's middle, out of the chest's seam -- that flares on the
			     burst, stronger the better the pull. ]]
			local strength = part.tier.aura
			local arrived = clamp01(u / 0.3)
			local pulse = 0.85 + 0.15 * math.sin(t * (6 + 10 * w))
			local flare = if burst
				then 1 - clamp01(since / (if juicy then 1.3 elseif chest then 0.9 else 0.35))
				else 0
			local halo = (0.3 + 0.7 * w) * strength * arrived * pulse
			part.aura.Visible = (halo > 0.01 and not burst) or flare > 0.01
			part.aura.ImageColor3 = light
			local auraSize = size * (1.25 + 0.55 * w * strength + flare * 0.9)
			put(part.aura, px, py, auraSize, auraSize)
			part.aura.ImageTransparency = 1
				- math.min(0.95, if burst then flare * strength else halo)
			local seam = if chest then py - size * 0.06 * sy else py
			local within = (0.15 + 0.55 * w ^ 1.3) * strength * arrived * pulse
			part.inner.Visible = (within > 0.01 and not burst) or flare > 0.01
			part.inner.ImageColor3 = light:Lerp(Color3.new(1, 1, 1), 0.35)
			local innerW = size * (if chest then 0.95 + 0.4 * w else 0.6 + 0.25 * w) * (1 + flare)
			local innerH = size * (if chest then 0.32 + 0.3 * w else 0.7 + 0.25 * w) * (1 + flare)
			put(part.inner, px, seam, innerW, innerH)
			local inside = if juicy then math.max(strength, 0.85) else strength
			part.inner.ImageTransparency = 1
				- math.min(0.9, if burst then flare * inside else within)
			-- the chest's beams out of its open lid
			for n, beam in part.beams do
				local up = popIn(since / 0.3) * (1 - clamp01((t - line.banner) / 0.6))
				beam.Visible = burst and up > 0.01
				put(
					beam,
					px,
					py - size * 0.12,
					(34 + (n % 2) * 26) * size / 480,
					(if juicy then 520 else 820) * up * size / 480
				)
				beam.Rotation = (n - 3) * 18 + math.sin(t * 2 + n) * 4
			end
			for _, bit in part.bits do
				fly(bit, t)
			end
			-- the prize pops out, arcs up and lands with a squash
			local pet = burst and gone < 1
			local rise = clamp01(since / Beats.egg.pop)
			local petY = y - 30 - math.sin(rise * math.pi) * 170
			if chest then
				petY = y + 40 - math.sin(rise * math.pi * 0.5) * (if twoPiece then 230 else 140)
			end
			local landed = since - Beats.egg.pop
			local psx, psy = 1, 1
			if landed >= 0 then
				local squash = 0.24 * decay(landed, 8, 28)
				psx, psy = 1 + squash, 1 - squash
				-- a model stands as that pet stands (below); only a picture bobs
				if not part.petView then
					petY += math.sin(t * 3.9) * 8
				end
			end
			local grown = popIn(since / 0.25) * (1 - gone)
			local petSize = size * 0.9 * grown
			local petView, petModel, petBase = part.petView, part.petModel, part.petBase
			part.icon.Visible = pet and petView == nil
			put(part.icon, x, petY, petSize * psx, petSize * psy)
			if petView then
				petView.Visible = pet
				-- a viewport draws to its height, so its squash is one number
				put(petView, x, petY, petSize, petSize * psy)
				if pet and petModel and petBase then
					-- shown turning, and moving as it stands at the player's heel
					local gait = part.petGait
					local petScale = part.petSize or 1
					local stands = if gait
						then PetGait.pose(gait, t, 0, 0, 1, 0, petScale) * CFrame.new(
							0,
							-(gait.float or 0) * size,
							0
						)
						else CFrame.identity
					petModel:PivotTo(
						CFrame.Angles(0, math.sin(t * PET_SWAY_SPEED) * PET_SWAY, 0)
							* petBase
							* stands
					)
				end
			end
			-- its colour bursts behind it
			local spread = clamp01(since / 0.45)
			part.ring.Visible = burst and spread < 1
			put(part.ring, x, y, size * (0.5 + spread * 2.2), size * (0.5 + spread * 2.2))
			part.ring.ImageTransparency = spread
			-- a chest's ring of light rushes out along the ground
			if juicy then
				local across = size * (0.6 + spread * 3)
				part.ring.ScaleType = Enum.ScaleType.Stretch
				put(part.ring, x, y + size * 0.3, across, across * 0.3)
				part.ring.ImageColor3 = light:Lerp(Color3.new(1, 1, 1), 0.4)
				part.ring.ImageTransparency = spread ^ 1.5
			end
			for _, s in part.stars do
				local age = t - s.at
				local k = age / s.life
				local live = k >= 0 and k < 1
				s.item.Visible = live
				if live then
					local slowed = (1 - math.exp(-age * 3.2)) / 3.2
					local bursting = clamp01((k - 0.78) / 0.22)
					local across = s.size * popIn(k / 0.18) * (1 + 0.7 * bursting)
					put(
						s.item,
						x + s.vx * slowed,
						y - size * 0.12 + s.vy * slowed + 260 * age * age,
						across,
						across
					)
					s.item.Rotation = s.spin * age
					s.star.ImageTransparency = bursting
					s.halo.ImageTransparency = 0.45 + 0.55 * bursting
				end
			end
			for _, d in part.dust do
				local age = since - d.at
				local live = age >= 0 and gone < 1
				d.item.Visible = live
				if live then
					local k = (age % d.life) / d.life
					local across = d.size
						* math.sin(k * math.pi)
						* (0.6 + 0.4 * math.sin(t * 9 + d.phase))
						* (1 - gone)
					put(
						d.item,
						x + d.x + math.sin(t * 1.6 + d.phase) * d.drift,
						y - size * 0.05 - k * size * 0.95,
						across,
						across
					)
				end
			end
			local second = clamp01((t - line.banner) / 0.5)
			part.ring2.Visible = part.tier.glow and t >= line.banner and second < 1
			put(part.ring2, x, y, size * (0.6 + second * 2.6), size * (0.6 + second * 2.6))
			part.ring2.ImageTransparency = second
			local raysSize = size * 1.9 * popIn(since / 0.35) * (1 - gone)
			part.rays.Visible = pet
			part.rays.Rotation = t * 35
			put(part.rays, x, y - 20, raysSize, raysSize)
			part.rays.ImageTransparency = if part.tier.glow then 0.05 else 0.3
			part.rays2.Visible = pet and part.tier.glow
			part.rays2.Rotation = -t * 22
			put(part.rays2, x, y - 20, raysSize * 1.35, raysSize * 1.35)
			part.rays2.ImageTransparency = 0.45
			part.glow.Visible = pet
			put(part.glow, x, y - 20, size * 1.4 * grown, size * 1.4 * grown)
			part.glow.ImageTransparency = if part.tier.glow
				then 0.25 + 0.2 * math.sin(t * 5)
				else 0.55
			for n, sparkle in part.sparkles do
				local orbit = n * 2.399 + t * 1.3
				local reach = size * (0.55 + 0.12 * math.sin(t * 2 + n))
				local twinkle = (0.5 + 0.5 * math.sin(t * 7 + n * 1.7)) * grown
				sparkle.Visible = pet
				put(
					sparkle,
					x + math.cos(orbit) * reach,
					y - 20 + math.sin(orbit) * reach * 0.8,
					60 * twinkle * size / 480,
					60 * twinkle * size / 480
				)
			end
			-- the banner slams down, the name and the note pop
			local slam = clamp01((t - line.banner) / 0.2)
			local words = t >= line.banner and gone < 1
			local bannerScale = if slam < 1
				then 1 + 1.4 * (1 - slam) ^ 2
				else 1 + 0.1 * decay(t - line.banner - 0.2, 9, 30)
			local wide = if single then 620 else 430
			local bannerY = y + size * 0.62 + (if single then 80 else 50)
			part.banner.Visible = words
			part.banner.ImageTransparency = 1 - slam
			put(part.banner, x, bannerY, wide * bannerScale * (1 - gone), wide * 0.4 * bannerScale)
			part.rarity.TextTransparency = 1 - slam
			local named = popIn((t - line.banner - 0.06) / 0.25) * (1 - gone)
			part.name.Visible = words and named > 0.01
			put(
				part.name,
				x,
				bannerY - wide * 0.27,
				wide * 1.15 * named,
				64 * named * size / 480 + 12
			)
			local stamped = popIn((t - line.banner - 0.18) / 0.22) * (1 - gone)
			part.note.Visible = words and stamped > 0.01
			part.note.Rotation = -14
			put(
				part.note,
				x + size * 0.36,
				y - size * 0.42,
				220 * stamped * size / 480,
				64 * stamped * size / 480
			)
			local counted = clamp01((t - line.banner - 0.3) / 0.25) * (1 - gone)
			part.odds.Visible = words and part.odds.Text ~= "" and counted > 0
			part.odds.TextTransparency = 1 - counted
			put(part.odds, x, bannerY + wide * 0.26, wide * 0.8, 44 * size / 480)
		end
		-- the full-screen flash on the bursts (a bright one for a big pull)
		local white = 0
		for _, b in line.bursts do
			local peak = if b == line.burst then (if top.glow then 1 else 0.85) else 0.5
			-- so the slam itself can be seen
			if juicy and not top.glow then
				peak *= 0.4
			end
			local k = if t < b then clamp01(1 - (b - t) / 0.07) else clamp01(1 - (t - b) / 0.4)
			white = math.max(white, k * peak)
		end
		if top.glow then
			white = math.max(white, 0.5 * clamp01(1 - math.abs(t - line.banner) / 0.15))
		end
		flash.BackgroundTransparency = 1 - white
		shakeNow = shaking(t)
		shake.Position = UDim2.fromScale(
			math.sin(t * 83) * shakeNow * 0.006,
			math.cos(t * 71) * shakeNow * 0.006
		)
		if t >= line.soundAt and not played.open then
			played.open = true
			-- a skip past the sound's burst would play it late: leave it out
			if t < line.burst + 0.2 then
				SoundFx.play(line.sound)
			end
		end
		local rareAt, rareSound = line.rareAt, line.rareSound
		if rareAt and rareSound and t >= rareAt and not played.rare then
			played.rare = true
			SoundFx.play(rareSound)
		end
		local fresh = false
		for _, prize in prizes do
			fresh = fresh or prize.fresh
		end
		if fresh and t >= line.banner and not played.fresh then
			played.fresh = true
			SoundFx.play("new_item")
		end
		if t >= line.banner and t < line.leave and not stopGlitter then
			stopGlitter = SoundFx.loop("reveal_glitter")
		elseif t >= line.leave and stopGlitter then
			stopGlitter()
			stopGlitter = nil
		end
	end
	pose()
	local step = RunService.RenderStepped:Connect(pose)
	tap.Activated:Connect(function()
		local t = clock()
		offset += RevealTimeline.skip(line, t) - t
		pose()
	end)
	gui.Destroying:Once(function()
		step:Disconnect()
		stopCamera()
		if stopGlitter then
			stopGlitter()
		end
		if not closed then
			closed = true
			finished()
		end
	end)
end
--[[ Shows what a press won: every prize of it at once. ]]
local function present(look: Look, prizes: { Prize }, chanceOf: (Prize) -> number)
	if showing or #prizes == 0 then
		return
	end
	pendingUntil = 0
	showing = true
	play(look, prizes, chanceOf, function()
		showing = false
	end)
end
--[[ The chest a crate of `area` opens as: its model, its cut frames, its
     single picture, Victory's chest, or one drawn here. ]]
local function crateLook(area: string): Look
	local frames = GearAssets.crates[area]
	local single = GearAssets.areaPictures.chests[area] or ""
	if single == "" then
		local chests: { [string]: string } = EndScreenAssets.chests
		single = chests[area] or ""
	end
	return {
		kind = "crate",
		whole = if frames then frames.closed else single,
		crack1 = "",
		crack2 = "",
		bare = if frames then frames.bare else "",
		open = if frames then frames.open else "",
		model = GearAssets.models.chests[area],
		colours = Beats.wood,
		glow = Beats.glows[area] or Beats.glows.MossyGlade,
		special = "YOU FOUND SOMETHING SPECIAL...",
	}
end
--[[ The egg `key` hatches as: its model, its cut frames, its area's single
     picture, or one drawn here in its area's colours. ]]
local function eggLook(key: string): Look
	local egg = EggRules.find(key)
	local area = if egg then egg.area else "MossyGlade"
	local frames = GearAssets.eggs[key]
	return {
		kind = "egg",
		whole = if frames then frames.whole else (GearAssets.areaPictures.eggs[area] or ""),
		crack1 = if frames then frames.crack1 else "",
		crack2 = if frames then frames.crack2 else "",
		bare = "",
		open = "",
		model = GearAssets.models.eggs[area],
		colours = Beats.shells[area] or Beats.shells.MossyGlade,
		glow = Beats.glows[area] or Beats.glows.MossyGlade,
		special = "YOU HATCHED SOMETHING SPECIAL...",
	}
end
--[[ A crate's weapons (owner, 2026-10-27: the chests "changed exactly how
     you are changing the pets and with the same ui"). ]]
function Reveal.crates(index: number, results: { { weapon: string, new: boolean } })
	local crate = Shop.crates[index]
	if not crate then
		return
	end
	local prizes: { Prize } = {}
	for _, result in results do
		local entry = ShopRules.find(result.weapon)
		if entry then
			table.insert(prizes, {
				-- the full 2D drawing (owner, 2026-10-26), the mini icon if none
				icon = ShopAssets.weapons[result.weapon] or GearAssets.weapons[result.weapon] or "",
				name = entry.label,
				rarity = entry.rarity,
				fresh = result.new,
				note = if result.new then "NEW!" else "+1 COPY",
			})
		end
	end
	present(crateLook(crate.area), prizes, function(prize)
		for _, entry in ShopRules.cratePool(index) do
			if entry.label == prize.name then
				return ShopRules.chance(index, entry)
			end
		end
		return 0
	end)
end
function Reveal.eggs(
	key: string,
	results: { { pet: string, new: boolean } },
	counts: { [string]: number }?
)
	local prizes: { Prize } = {}
	for _, result in results do
		local info = Pets[result.pet]
		if info then
			table.insert(prizes, {
				icon = GearAssets.pets[result.pet] or "",
				key = result.pet,
				name = info.name,
				rarity = info.rarity,
				fresh = result.new,
				note = if result.new
					then "NEW!"
					else "x" .. tostring(if counts then counts[result.pet] or 2 else 2),
			})
		end
	end
	present(eggLook(key), prizes, function(prize)
		for _, entry in EggRules.pool(key) do
			if entry.name == prize.name then
				return entry.chance
			end
		end
		return 0
	end)
end
function Reveal.equip(source: GuiObject, target: GuiObject, asset: string, pet: boolean)
	if Reveal.busy() then
		return
	end
	SoundFx.play(if pet then "equip_pet" else "equip_weapon")
	local host = target:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui?
	if not host then
		return
	end
	showing = true
	local flying = Kit.image(host, asset)
	flying.ZIndex = 100
	local start = source.AbsolutePosition + source.AbsoluteSize / 2
	local finish = target.AbsolutePosition + target.AbsoluteSize / 2
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local ring = Kit.image(host, GearAssets.fx.ring)
	ring.ZIndex = 99
	local sparkle = Kit.image(host, GearAssets.fx.sparkle)
	sparkle.ZIndex = 101
	local began = os.clock()
	local offset = 0
	local overlay = Instance.new("TextButton")
	overlay.Font = Enum.Font.FredokaOne
	overlay.Text = ""
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 110
	overlay.Parent = host
	local step: RBXScriptConnection
	local function cleanup()
		step:Disconnect()
		showing = false
		overlay:Destroy()
		flying:Destroy()
		ring:Destroy()
		sparkle:Destroy()
		if scale.Parent then
			scale:Destroy()
		end
	end
	step = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began + offset
		if not target.Parent then
			cleanup()
			return
		end
		-- done by itself once it settles, so the screen redraws the slot with
		-- the new item in it (owner, 2026-10-26: it "goes on top of the
		-- weapon" when it waited for a tap)
		if t >= Beats.equip.settle then
			cleanup()
			return
		end
		local k = math.clamp(t / Beats.equip.fly, 0, 1)
		local at = start:Lerp(finish, 1 - (1 - k) ^ 3)
		local size = host.AbsoluteSize
		flying.Position =
			UDim2.fromScale((at.X - 48) / size.X, (at.Y - 48 - math.sin(k * math.pi) * 80) / size.Y)
		flying.Size = UDim2.fromScale(96 / size.X, 96 / size.Y)
		local pop = math.clamp((t - Beats.equip.fly) / Beats.equip.pop, 0, 1)
		scale.Scale = 1 + math.sin(pop * math.pi) * 0.2
		ring.Visible = k >= 1
		sparkle.Visible = k >= 1
		local radius = 96 + pop * 160
		ring.Position =
			UDim2.fromScale((finish.X - radius / 2) / size.X, (finish.Y - radius / 2) / size.Y)
		ring.Size = UDim2.fromScale(radius / size.X, radius / size.Y)
		ring.ImageTransparency = pop
		sparkle.Position, sparkle.Size = ring.Position, ring.Size
		sparkle.ImageTransparency = pop
	end)
	overlay.Activated:Connect(function()
		offset = Beats.equip.settle
	end)
end
return Reveal
