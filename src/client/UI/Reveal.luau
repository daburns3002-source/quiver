--!strict
--[[
	The shops' single-clock celebrations (owner, 2026-10-26: "heavy on dopamine").
	Only server answers supply prizes. A tap advances the clock; a second closes.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Beats = require(ReplicatedStorage.Shared.Config.Reveal)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local Reveal = {}
export type Prize = { icon: string, name: string, rarity: string, note: string, fresh: boolean }
--[[ What is opened: the egg or crate's pictures (whole and two cracked
     stages), its opening sound, where that sound's burst falls and how
     long it runs, and the Mythic cinematic's first line. ]]
type Look = {
	whole: string,
	crack1: string,
	crack2: string,
	sound: string,
	soundBurst: number,
	jingle: number,
	special: string,
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
--[[ A full-screen layer for the reveals: its canvas, a white flash over
     it and a tap catcher over everything. ]]
local function layer(dimming: number): (ScreenGui, Frame, Frame, Frame, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GearReveal"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 180
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer.PlayerGui
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = dimming
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	local shake = Instance.new("Frame")
	shake.BackgroundTransparency = 1
	shake.Size = UDim2.fromScale(1, 1)
	shake.Parent = dim
	local canvas = Kit.canvas(shake)
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 10
	flash.Parent = gui
	local tap = Instance.new("TextButton")
	tap.Font = Enum.Font.Arcade
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 20
	tap.Parent = dim
	return gui, shake, canvas, flash, tap
end
local function centre(item: GuiObject, x: number, y: number, w: number, h: number)
	Kit.put(item, x - w / 2, y - h / 2, w, h)
end
local function rainbow(t: number, rarity: string): Color3
	return if rarity == "Mythic" then Color3.fromHSV((t * 0.3) % 1, 0.8, 1) else Kit.colour(rarity)
end
-- 0 to 1 with a little overshoot, for things that pop in
local function popIn(k: number): number
	return 1 + 2.7 * (k - 1) ^ 3 + 1.7 * (k - 1) ^ 2
end
--[[ The eggs hatch over the world, in step (docs/EGG-HATCH-REFERENCE.md):
     they drop in, a ring sweeps out, they flash white, shake as cracks
     spread, the screen flashes and each pet stands where its egg was with
     rays behind it and its name, rarity and note under it, then they shrink
     away and the layer closes by itself. A tap skips to the next beat. ]]
local function hatch(look: Look, prizes: { Prize }, finished: () -> ())
	local beats = Beats.egg
	local gui, shake, canvas, flash, tap = layer(1)
	local single = #prizes == 1
	local size = if single then 560 else 440
	local rare, fresh = false, false
	for _, prize in prizes do
		rare = rare or Beats.rare[prize.rarity] == true
		fresh = fresh or prize.fresh
	end
	local soundAt = beats.burst - look.soundBurst
	-- an Epic or better holds until its reveal sound has played over it
	local leave = if rare then math.max(beats.leave, soundAt + look.jingle + 0.6) else beats.leave
	local done = leave + beats.done - beats.leave
	local parts = {}
	for index, prize in prizes do
		local root = Instance.new("Frame")
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
		root.Parent = canvas
		local glow = Kit.image(root, GearAssets.fx.glow)
		local rays = Kit.image(root, GearAssets.fx.rays)
		local ring = Kit.image(root, GearAssets.fx.ring)
		ring.ImageColor3 = Color3.new(1, 1, 1)
		local shell = Kit.image(root, look.whole)
		shell.AnchorPoint = Vector2.new(0.5, 0.5)
		local white = Kit.image(root, GearAssets.fx.glow)
		white.ImageColor3 = Color3.new(1, 1, 1)
		local icon = Kit.image(root, prize.icon)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		local name = Kit.label(root, prize.name)
		local nameScale = Instance.new("UIScale")
		nameScale.Parent = name
		local rarity = Kit.label(root, string.upper(prize.rarity))
		local note = Kit.label(root, prize.note, Kit.gold)
		table.insert(parts, {
			x = if single then 960 else 960 + (index - 2) * 400,
			glow = glow,
			rays = rays,
			ring = ring,
			shell = shell,
			white = white,
			icon = icon,
			name = name,
			nameScale = nameScale,
			rarity = rarity,
			note = note,
		})
	end
	local started = os.clock()
	local offset = 0
	local played = { hatch = false, rare = false, fresh = false }
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
		local t = os.clock() - started + offset
		if t >= done then
			close()
			return
		end
		local y = 500
		local fall = math.clamp(t / beats.drop, 0, 1)
		local squash = math.sin(math.clamp((t - beats.drop) / 0.3, 0, 1) * math.pi) * 0.08
		local whiten = math.sin(
			math.clamp((t - beats.whiten[1]) / (beats.whiten[2] - beats.whiten[1]), 0, 1) * math.pi
		)
		local power = math.clamp((t - beats.whiten[2]) / (beats.burst - beats.whiten[2]), 0, 1)
		local swept = t - beats.drop
		local shown = math.clamp((t - beats.burst) / (beats.land - beats.burst + 0.15), 0, 1)
		local gone = math.clamp((t - leave) / (done - leave), 0, 1)
		local scale = math.max(0.02, popIn(shown) * (1 - gone))
		for index, part in parts do
			local x = part.x
			local colour = rainbow(t, prizes[index].rarity)
			-- the egg
			local egg = t < beats.burst
			part.shell.Visible = egg
			part.shell.Image = if t >= beats.cracks[2]
				then look.crack2
				elseif t >= beats.cracks[1] then look.crack1
				else look.whole
			part.shell.Rotation = math.sin(t * (28 + power * 30)) * power * 12
			part.shell.Position = UDim2.fromScale(
				(x + math.sin(t * 67) * power * 10) / 1920,
				(y - (1 - fall) ^ 2 * 900) / 1080
			)
			part.shell.Size =
				UDim2.fromScale(size * (1 + squash) / 1920, size * (1 - squash) / 1080)
			part.white.Visible = egg and whiten > 0
			centre(part.white, x, y, size * 1.3, size * 1.3)
			part.white.ImageTransparency = 1 - whiten
			part.ring.Visible = swept >= 0 and swept < 0.5
			local ringSize = size * (0.8 + math.max(0, swept) * 2)
			centre(part.ring, x, y, ringSize, ringSize)
			part.ring.ImageTransparency = math.clamp(swept / 0.5, 0, 1)
			-- the glow builds as it cracks (white: it gives nothing away), and is
			-- the white puff the pet leaves in
			part.glow.Visible = (egg and power > 0) or gone > 0
			part.glow.ImageColor3 = Color3.new(1, 1, 1)
			local glowSize = if egg then size * (1.1 + power * 0.5) else size * (1 + gone)
			centre(part.glow, x, y, glowSize, glowSize)
			part.glow.ImageTransparency = if egg then 1 - power * 0.7 else 0.2 + gone * 0.8
			-- the pet
			local pet = t >= beats.burst
			local petSize = (if single then 460 else 380) * scale
			part.icon.Visible = pet
			part.icon.Position =
				UDim2.fromScale(x / 1920, (y + math.sin(t * math.pi * 2 / 1.6) * 8) / 1080)
			part.icon.Size = UDim2.fromScale(petSize / 1920, petSize / 1080)
			part.rays.Visible = pet
			part.rays.Rotation = t * 40
			part.rays.ImageColor3 = Color3.new(1, 1, 1):Lerp(colour, 0.25)
			local raySize = (if single then 900 else 700) * scale
			centre(part.rays, x, y, raySize, raySize)
			part.rays.ImageTransparency = 0.15 + gone * 0.85
			local words = t >= beats.land and t < leave
			local wide = if single then 720 else 420
			part.name.Visible = words
			Kit.put(part.name, x - wide / 2, y + 230, wide, 72)
			part.nameScale.Scale = 1
				+ math.sin(math.clamp((t - beats.land) / 0.25, 0, 1) * math.pi) * 0.28
			part.rarity.Visible = words
			part.rarity.TextColor3 = colour
			Kit.put(part.rarity, x - wide / 2, y + 304, wide, 52)
			part.note.Visible = words
			Kit.put(part.note, x - wide / 2, y + 360, wide, 44)
		end
		-- the full-screen flash: up fast to the burst, fading after
		local white = if t < beats.burst
			then math.clamp(1 - (beats.burst - t) / 0.1, 0, 1)
			else math.clamp(1 - (t - beats.burst) / 0.35, 0, 1)
		flash.BackgroundTransparency = 1 - white
		shake.Position =
			UDim2.fromScale(math.sin(t * 83) * white * 0.009, math.cos(t * 71) * white * 0.009)
		if t >= soundAt and not played.hatch then
			played.hatch = true
			SoundFx.play(look.sound)
		end
		if rare and t >= soundAt + look.jingle and not played.rare then
			played.rare = true
			SoundFx.play("reveal_rare")
		end
		if fresh and t >= beats.land and not played.fresh then
			played.fresh = true
			SoundFx.play("new_item")
		end
		if t >= beats.land and t < leave and not stopGlitter then
			stopGlitter = SoundFx.loop("reveal_glitter")
		elseif t >= leave and stopGlitter then
			stopGlitter()
			stopGlitter = nil
		end
	end
	pose()
	local step = RunService.RenderStepped:Connect(pose)
	tap.Activated:Connect(function()
		local t = os.clock() - started + offset
		offset += (if t < beats.land then beats.land elseif t < leave then leave else done) - t
		pose()
	end)
	gui.Destroying:Once(function()
		step:Disconnect()
		if stopGlitter then
			stopGlitter()
		end
		if not closed then
			closed = true
			finished()
		end
	end)
end
--[[ A Mythic's own cinematic (Tap Simulator Reborn's top-rarity hatch):
     a dark screen with the pet's silhouette, a bobbing "?", a white flash,
     a glide through the hatchery, the lone egg glowing, then the pet on its
     pedestal as "MYTHIC DISCOVERED" with its odds. A tap skips to the pet;
     another closes it. ]]
local function cinematic(look: Look, prize: Prize, chance: number, finished: () -> ())
	local beats = Beats.mythic
	local gui, shake, canvas, flash, tap = layer(0)
	local hall = Kit.image(canvas, GearAssets.backgrounds.hatchery)
	hall.AnchorPoint = Vector2.new(0.5, 0.5)
	hall.ScaleType = Enum.ScaleType.Crop
	local silhouette = Kit.image(canvas, prize.icon)
	silhouette.ImageColor3 = Color3.new(0, 0, 0)
	centre(silhouette, 960, 470, 520, 520)
	local special = Kit.label(canvas, look.special)
	Kit.put(special, 360, 860, 1200, 64)
	local badge = Kit.image(canvas, GearAssets.fx.badge)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	local question = Kit.label(badge, "?")
	question.Size = UDim2.fromScale(1, 1)
	local sparkles = {}
	for _ = 1, 14 do
		local sparkle = Kit.image(canvas, GearAssets.fx.sparkle)
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(sparkles, sparkle)
	end
	local glow = Kit.image(canvas, GearAssets.fx.glow)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.ImageColor3 = Kit.gold
	local egg = Kit.image(canvas, look.whole)
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	local rays = Kit.image(canvas, GearAssets.fx.rays)
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	local pedestal = Kit.image(canvas, GearAssets.showcase.pedestal)
	centre(pedestal, 960, 760, 460, 460 * 318 / 642)
	local icon = Kit.image(canvas, prize.icon)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	local discovered = Kit.label(canvas, "MYTHIC DISCOVERED", Kit.gold)
	Kit.put(discovered, 560, 852, 800, 48)
	local name = Kit.label(canvas, string.upper(prize.name))
	Kit.put(name, 360, 900, 1200, 88)
	local odds =
		Kit.label(canvas, "1 / " .. tostring(math.round(1 / math.max(chance, 1e-6))), Kit.gold)
	Kit.put(odds, 560, 988, 800, 52)
	local started = os.clock()
	local offset = 0
	local reveal = false
	local stopGlitter: (() -> ())? = nil
	local closed = false
	local function pose()
		local t = os.clock() - started + offset
		local dark = t < beats.flash
		local gliding = t >= beats.flash and t < beats.discovered
		local shown = t >= beats.discovered
		-- the hatchery glides past, slowly closing in; dim while dark
		hall.Visible = gliding or shown
		local glide = math.clamp((t - beats.flash) / (beats.egg - beats.flash), 0, 1)
		local zoom = 1 + glide * 0.35
		hall.Position = UDim2.fromScale((960 - glide * 160) / 1920, 0.5)
		hall.Size = UDim2.fromScale(zoom * 1.1, zoom * 1.1)
		hall.ImageColor3 = if t >= beats.egg
			then Color3.fromRGB(150, 140, 170)
			else Color3.new(1, 1, 1)
		silhouette.Visible = t < beats.question
		special.Visible = t < beats.question
		-- the "?" pops in and bobs, then whitens in sparkles
		local asked = math.clamp((t - beats.question) / 0.35, 0, 1)
		local whitened = math.clamp((t - beats.whiten) / (beats.flash - beats.whiten), 0, 1)
		badge.Visible = dark and t >= beats.question
		local badgeSize = 420 * popIn(asked)
		centre(badge, 960, 480 + math.sin(t * 2.4) * 18, badgeSize, badgeSize)
		badge.ImageColor3 = Color3.new(1, 1, 1)
		badge.ImageTransparency = whitened * 0.6
		for n, sparkle in sparkles do
			local angle = n * 2.399 + t
			local reach = 160 + whitened * 260 + n % 3 * 40
			sparkle.Visible = dark and t >= beats.whiten
			centre(sparkle, 960 + math.cos(angle) * reach, 480 + math.sin(angle) * reach, 56, 56)
			sparkle.ImageTransparency = whitened * 0.5
		end
		-- the lone egg, glowing brighter and bigger until it bursts
		local building = math.clamp((t - beats.egg) / (beats.discovered - beats.egg), 0, 1)
		local hatching = t >= beats.egg and not shown
		egg.Visible = hatching
		egg.Rotation = math.sin(t * (20 + building * 40)) * building * 8
		local eggSize = 420 + building * 160
		centre(egg, 960, 500, eggSize, eggSize)
		glow.Visible = hatching
		local glowSize = eggSize * (1.3 + building)
		centre(glow, 960, 500, glowSize, glowSize)
		glow.ImageTransparency = 0.7 - building * 0.6
		-- the pet on its pedestal
		local landed = math.clamp((t - beats.discovered) / 0.4, 0, 1)
		pedestal.Visible = shown
		pedestal.ImageColor3 = rainbow(t, "Mythic")
		icon.Visible = shown
		local petSize = 420 * math.max(0.02, popIn(landed))
		centre(icon, 960, 560 + math.sin(t * math.pi * 2 / 1.6) * 10, petSize, petSize)
		rays.Visible = shown
		rays.Rotation = t * 30
		rays.ImageColor3 = rainbow(t, "Mythic")
		centre(rays, 960, 560, 1000 * popIn(landed), 1000 * popIn(landed))
		discovered.Visible = shown
		name.Visible = shown
		name.TextColor3 = rainbow(t + 1, "Mythic")
		odds.Visible = shown and chance > 0
		local white = math.max(
			math.clamp(1 - math.abs(t - beats.flash) / 0.25, 0, 1),
			math.clamp(1 - math.abs(t - beats.discovered) / 0.3, 0, 1)
		)
		flash.BackgroundTransparency = 1 - white
		shake.Position =
			UDim2.fromScale(math.sin(t * 83) * white * 0.008, math.cos(t * 71) * white * 0.008)
		if shown and not reveal then
			reveal = true
			SoundFx.play("mythic_reveal")
			if prize.fresh then
				SoundFx.play("new_item")
			end
			stopGlitter = SoundFx.loop("reveal_glitter")
		end
	end
	pose()
	local step = RunService.RenderStepped:Connect(pose)
	tap.Activated:Connect(function()
		local t = os.clock() - started + offset
		if t < beats.discovered then
			offset += beats.discovered - t
			pose()
		elseif t >= beats.done then
			gui:Destroy()
		end
	end)
	gui.Destroying:Once(function()
		step:Disconnect()
		if stopGlitter then
			stopGlitter()
		end
		if not closed then
			closed = true
			finished()
		end
	end)
end
--[[ Shows what a press won: a Mythic's cinematic first (its odds from
     `chanceOf`), then the rest hatch or open together. ]]
local function present(look: Look, prizes: { Prize }, chanceOf: (Prize) -> number)
	if showing or #prizes == 0 then
		return
	end
	pendingUntil = 0
	showing = true
	local mythics, rest = {}, {}
	for _, prize in prizes do
		table.insert(if prize.rarity == "Mythic" then mythics else rest, prize)
	end
	local function after()
		if #rest > 0 then
			hatch(look, rest, function()
				showing = false
			end)
		else
			showing = false
		end
	end
	if #mythics > 0 then
		cinematic(look, mythics[1], chanceOf(mythics[1]), function()
			for n = 2, #mythics do
				table.insert(rest, mythics[n])
			end
			after()
		end)
	else
		after()
	end
end
--[[ A crate's weapons (owner, 2026-10-27: the chests "changed exactly how
     you are changing the pets and with the same ui"): the crate in the
     eggs' place, shaking to its own opening sound. ]]
function Reveal.crates(index: number, results: { { weapon: string, new: boolean } })
	local crate = Shop.crates[index]
	local art = if crate then GearAssets.crates[crate.area] else nil
	if not art then
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
	present(
		{
			whole = art.closed,
			crack1 = art.closed,
			crack2 = art.closed,
			sound = "crate_open",
			soundBurst = Beats.crate.soundBurst,
			jingle = Beats.crate.jingle,
			special = "YOU FOUND SOMETHING SPECIAL...",
		},
		prizes,
		function(prize)
			for _, entry in ShopRules.cratePool(index) do
				if entry.label == prize.name then
					return ShopRules.chance(index, entry)
				end
			end
			return 0
		end
	)
end
function Reveal.eggs(
	key: string,
	results: { { pet: string, new: boolean } },
	counts: { [string]: number }?
)
	local art = GearAssets.eggs[key]
	if not art then
		return
	end
	local prizes: { Prize } = {}
	for _, result in results do
		local info = Pets[result.pet]
		if info then
			table.insert(prizes, {
				icon = GearAssets.pets[result.pet] or "",
				name = info.name,
				rarity = info.rarity,
				fresh = result.new,
				note = if result.new
					then "NEW!"
					else "x" .. tostring(if counts then counts[result.pet] or 2 else 2),
			})
		end
	end
	present(
		{
			whole = art.whole,
			crack1 = art.crack1,
			crack2 = art.crack2,
			sound = "egg_hatch",
			soundBurst = Beats.egg.soundBurst,
			jingle = Beats.egg.jingle,
			special = "YOU HATCHED SOMETHING SPECIAL...",
		},
		prizes,
		function(prize)
			for _, entry in EggRules.pool(key) do
				if entry.name == prize.name then
					return entry.chance
				end
			end
			return 0
		end
	)
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
	overlay.Font = Enum.Font.Arcade
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
