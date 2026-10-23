--!strict
--[[
	The end screens' motion, from `Config/EndScreenTimeline`
	(design_handoff_end_screens, README "Animation").

	One RenderStepped loop reads the time since the screen appeared and
	poses every piece for that moment, rather than a stack of tweens: the
	design is a timeline, and posing from the clock makes tap-to-skip a
	matter of moving the clock forward. Nothing here decides anything; the
	numbers counted up are the ones the server sent.

	Victory: the banner drops, the sub-ribbon pops, rays and glow fade in and
	turn, the trophy pops and then floats, a white flash, sparks burst out,
	confetti falls, the panel slides up, the rows slide in and count up, the
	button pops and then pulses with a shine.

	Defeat: the banner slams down, the panel shakes, the shield drops in and
	floats, a red glow and edge vignette pulse, a red flash, rocks fall,
	embers rise, the rows count up, the progress bar fills, the button pops
	and its arrow spins now and then.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local EndScreenTheme = require(ReplicatedStorage.Shared.Config.EndScreenTheme)
local EndScreenTimeline = require(ReplicatedStorage.Shared.Config.EndScreenTimeline)

local Device = require(script.Parent.Parent.Device)

local EndScreenMotion = {}

type Count = { label: TextLabel, kind: "Count" | "Clock" | "Percent", target: number }

export type Parts = {
	won: boolean,
	root: Frame,
	size: Vector2,
	ribbon: Frame,
	sub: Frame,
	hero: GuiObject,
	rays: ImageLabel?,
	glow: ImageLabel?,
	--[[ Clipped to the panel, behind the content: embers. ]]
	behind: CanvasGroup,
	--[[ Clipped to the panel, over the content: flash, sparks, confetti,
	     rocks, vignette. ]]
	over: CanvasGroup,
	statsGroup: Frame,
	rows: { Frame },
	counts: { Count },
	fill: Frame?,
	percent: number,
	buttonGroup: Frame,
	icon: ImageLabel,
	shine: Frame,
}

export type Motion = {
	stop: () -> (),
	skip: () -> (),
	--[[ Whether the button may be pressed yet. ]]
	ready: () -> boolean,
	--[[ Holds the timeline at this many milliseconds, or lets it run again
	     with nil. For checking one moment of the motion in Studio. ]]
	hold: (number?) -> (),
}

local INK = EndScreenTheme.ink
local WHITE = EndScreenTheme.white
local SPARK_YELLOW = Color3.fromRGB(255, 225, 77)
local FLASH_RED = Color3.fromRGB(255, 70, 80)
--[[ Where the hero sits, the centre of the flash and of the burst. ]]
local HERO_CENTRE = Vector2.new(270, 190)
--[[ Milliseconds from one shine across the button to the next; each
     takes the whole period to cross. ]]
local SHINE_PERIOD = 2400
--[[ Radians a second the banner bobs at once it has landed. ]]
local BOB_RATE = 2

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function cubicOut(x: number): number
	return 1 - (1 - x) ^ 3
end

local function cubicIn(x: number): number
	return x ^ 3
end

local function cubicInOut(x: number): number
	return if x < 0.5 then 4 * x ^ 3 else 1 - (-2 * x + 2) ^ 3 / 2
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

local function formatCount(count: Count, value: number): string
	if count.kind == "Clock" then
		return clock(value)
	elseif count.kind == "Percent" then
		return string.format("%d%%", math.floor(value + 0.5))
	end
	return tostring(math.floor(value + 0.5))
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector2,
	colour: Color3,
	z: number
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function radial(
	parent: Instance,
	name: string,
	size: Vector2,
	colour: Color3,
	z: number
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromOffset(HERO_CENTRE.X, HERO_CENTRE.Y - 4)
	i.Size = UDim2.fromOffset(size.X, size.Y)
	i.BackgroundTransparency = 1
	i.Image = CardAssets.glow
	i.ImageColor3 = colour
	i.ImageTransparency = 1
	i.ScaleType = Enum.ScaleType.Stretch
	i.ZIndex = z
	i.Parent = parent
	return i
end

--[[ A red edge, fading toward the middle: one of the vignette's four sides. ]]
local function edge(parent: Instance, side: string, size: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = "Vignette" .. side
	f.BackgroundColor3 = Color3.fromRGB(255, 30, 60)
	f.BorderSizePixel = 0
	f.ZIndex = 1
	-- How far in from the edge the red reaches; thinner since the owner
	-- found the tint too strong.
	local depth = 80
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(0, 1)
	if side == "Top" then
		f.Size = UDim2.fromOffset(size.X, depth)
		g.Rotation = 90
	elseif side == "Bottom" then
		f.Position = UDim2.fromOffset(0, size.Y - depth)
		f.Size = UDim2.fromOffset(size.X, depth)
		g.Rotation = -90
	elseif side == "Left" then
		f.Size = UDim2.fromOffset(depth, size.Y)
		g.Rotation = 0
	else
		f.Position = UDim2.fromOffset(size.X - depth, 0)
		f.Size = UDim2.fromOffset(depth, size.Y)
		g.Rotation = 180
	end
	g.Parent = f
	f.Parent = parent
	return f
end

function EndScreenMotion.play(parts: Parts): Motion
	local won = parts.won
	local key: any = if won then EndScreenTimeline.victory else EndScreenTimeline.defeat
	local look: any = if won then EndScreenTheme.victory else EndScreenTheme.defeat
	local share = Device.tier().endScreenParticleShare
	-- Seeded, so a screen falls the same way every time it is shown.
	local random = Random.new(7)

	local function scaleOf(obj: GuiObject): UIScale
		return obj:FindFirstChildOfClass("UIScale") :: UIScale
	end

	local base: { [GuiObject]: UDim2 } = {}
	for _, obj in
		{ parts.ribbon, parts.sub, parts.hero, parts.statsGroup, parts.buttonGroup, parts.root } :: { GuiObject }
	do
		base[obj] = obj.Position
	end
	for _, r in parts.rows do
		base[r] = r.Position
	end

	local function place(obj: GuiObject, dx: number, dy: number)
		obj.Position = base[obj] + UDim2.fromOffset(dx, dy)
	end

	--[[ Everything starts hidden; each piece appears at its own keyframe. ]]
	local function show(obj: GuiObject, at: boolean)
		obj.Visible = at
	end

	local flash =
		radial(parts.over, "Flash", Vector2.new(720, 620), if won then WHITE else FLASH_RED, 20)

	-- Victory's sparks and confetti.
	type Spark = { frame: Frame, dir: Vector2, reach: number, size: number }
	local sparks: { Spark } = {}
	type Confetti = {
		frame: Frame,
		width: number,
		x0: number,
		delay: number,
		speed: number,
		sway: number,
		freq: number,
		phase: number,
		spin: number,
	}
	local confetti: { Confetti } = {}
	-- Defeat's rocks and embers.
	type Rock = { frame: Frame, x0: number, y0: number, vx: number, vy: number, spin: number }
	local rocks: { Rock } = {}
	type Ember = {
		frame: Frame,
		x0: number,
		delay: number,
		speed: number,
		sway: number,
		phase: number,
	}
	local embers: { Ember } = {}
	local vignette: { Frame } = {}

	if won then
		local k = key.sparks
		for i = 1, math.max(1, math.floor(k.count * share + 0.5)) do
			local big = i % 3 == 1
			local size = if big then 14 else 9
			local s = piece(
				parts.over,
				"Spark",
				Vector2.new(size, size),
				if i % 2 == 0 then WHITE else SPARK_YELLOW,
				22
			)
			s.Rotation = 45
			local angle = (i / k.count) * math.pi * 2 + random:NextNumber() * 0.3
			table.insert(sparks, {
				frame = s,
				dir = Vector2.new(math.cos(angle), math.sin(angle)),
				reach = lerp(k.radius[1], k.radius[2], random:NextNumber()),
				size = size,
			})
		end

		local c = key.confetti
		for i = 1, math.max(1, math.floor(c.count * share + 0.5)) do
			local square = i % 4 == 1
			local w = if square then 10 else 7
			local f = piece(
				parts.over,
				"Confetti",
				Vector2.new(w, if square then 10 else 14),
				look.confetti[(i - 1) % #look.confetti + 1],
				21
			)
			table.insert(confetti, {
				frame = f,
				width = w,
				x0 = random:NextNumber() * parts.size.X,
				delay = random:NextNumber() * c.staggerMax,
				speed = lerp(c.fallPxPerSec[1], c.fallPxPerSec[2], random:NextNumber()),
				sway = lerp(c.sway[1], c.sway[2], random:NextNumber()),
				freq = 1 + random:NextNumber() * 2,
				phase = random:NextNumber() * math.pi * 2,
				spin = 2 + random:NextNumber() * 5,
			})
		end
	else
		for _, side in { "Top", "Bottom", "Left", "Right" } do
			local f = edge(parts.over, side, parts.size)
			f.BackgroundTransparency = 1
			table.insert(vignette, f)
		end

		local r = key.rocks
		for _ = 1, r.count do
			local w = math.floor(10 + random:NextNumber() * 12)
			local f = piece(parts.over, "Rock", Vector2.new(w, w), WHITE, 23)
			local g = Instance.new("UIGradient")
			g.Color = look.rock
			g.Rotation = 45
			g.Parent = f
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 3)
			corner.Parent = f
			local stroke = Instance.new("UIStroke")
			stroke.Color = INK
			stroke.Thickness = 2.5
			stroke.Parent = f
			table.insert(rocks, {
				frame = f,
				vx = (random:NextNumber() - 0.5) * 0.5,
				vy = -0.25 - random:NextNumber() * 0.25,
				spin = (random:NextNumber() - 0.5) * 1.2,
				x0 = HERO_CENTRE.X + (random:NextNumber() - 0.5) * 120,
				y0 = 200 + random:NextNumber() * 30,
			})
		end

		local e = key.embers
		for i = 1, math.max(1, math.floor(e.count * share + 0.5)) do
			local w = if i % 3 == 1 then 7 else 5
			local f = piece(parts.behind, "Ember", Vector2.new(w, w), look.ember, 5)
			f.Rotation = 45
			table.insert(embers, {
				frame = f,
				x0 = random:NextNumber() * parts.size.X,
				delay = random:NextNumber() * 4000,
				speed = lerp(e.risePxPerSec[1], e.risePxPerSec[2], random:NextNumber()),
				sway = lerp(e.sway[1], e.sway[2], random:NextNumber()),
				phase = random:NextNumber() * math.pi * 2,
			})
		end
	end

	--[[ The clock: real time since shown, plus whatever a skip jumped. ]]
	local shownAt = os.clock()
	local jumped = 0
	local held: number? = nil
	local function now(): number
		return held or (os.clock() - shownAt) * 1000 + jumped
	end

	--[[
		Fading a whole group the way the design's CSS opacity does: every
		transparency under `root` is pulled toward 1 from its own resting
		value. `except` subtrees are left to their own fader.
	]]
	type Fade = { target: any, prop: string, rest: number }
	local function fader(root: Instance, except: { Instance }?): (number) -> ()
		local list: { Fade } = {}
		local function skipped(inst: Instance): boolean
			local excluded: { Instance } = except or {}
			for _, x in excluded do
				if inst == x or inst:IsDescendantOf(x) then
					return true
				end
			end
			return false
		end
		local function add(inst: Instance)
			if skipped(inst) then
				return
			end
			if inst:IsA("GuiObject") then
				table.insert(list, {
					target = inst,
					prop = "BackgroundTransparency",
					rest = inst.BackgroundTransparency,
				})
			end
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				table.insert(
					list,
					{ target = inst, prop = "ImageTransparency", rest = inst.ImageTransparency }
				)
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") then
				table.insert(
					list,
					{ target = inst, prop = "TextTransparency", rest = inst.TextTransparency }
				)
			end
			if inst:IsA("UIStroke") then
				table.insert(
					list,
					{ target = inst, prop = "Transparency", rest = inst.Transparency }
				)
			end
		end
		add(root)
		for _, d in root:GetDescendants() do
			add(d)
		end
		local last = -1
		return function(alpha: number)
			if alpha == last then
				return
			end
			last = alpha
			for _, f in list do
				(f.target :: any)[f.prop] = 1 - (1 - f.rest) * alpha
			end
		end
	end

	local fadeRibbon = fader(parts.ribbon)
	local fadePanel = fader(parts.statsGroup, parts.rows :: { any })
	local fadeRows = {}
	for i, r in parts.rows do
		fadeRows[i] = fader(r)
	end

	local function pose(t: number)
		local seconds = t / 1000

		-- Banner: drops in (Victory) or slams down (Defeat).
		local banner = key.banner
		local bp = clamp01((t - banner.start) / banner.dur)
		if won then
			local b = backOut(bp)
			local bob = if bp >= 1 then math.sin(seconds * BOB_RATE) * banner.idleBob else 0
			place(parts.ribbon, 0, banner.fromOffsetY * (1 - b) + bob)
			scaleOf(parts.ribbon).Scale = lerp(banner.fromScale, 1, b)
			fadeRibbon(if bp > 0 then 1 else 0)
		else
			local k = cubicIn(bp)
			scaleOf(parts.ribbon).Scale = lerp(banner.fromScale, 1, k)
			parts.ribbon.Rotation = banner.fromRotation * (1 - k)
			fadeRibbon(clamp01(bp * 3))
		end

		-- Sub-ribbon pops.
		local sub = key.sub
		local sp = clamp01((t - sub.start) / sub.dur)
		show(parts.sub, sp > 0)
		scaleOf(parts.sub).Scale = math.max(0, backOut(sp))
		parts.sub.Rotation = (sub.fromRotation or 0) * (1 - sp)

		-- Hero: pops (Victory) or drops (Defeat), then floats.
		local hero = key.hero
		local hp = clamp01((t - hero.start) / hero.dur)
		show(parts.hero, hp > 0)
		local float = if hp >= 1 then math.sin(seconds * hero.idleRadPerSec) * hero.idleFloat else 0
		if won then
			scaleOf(parts.hero).Scale = math.max(0, lerp(hero.fromScale, 1, backOut(hp)))
			place(parts.hero, 0, float)
		else
			place(parts.hero, 0, hero.fromOffsetY * (1 - backOut(hp)) + float)
		end
		parts.hero.Rotation = hero.fromRotation * (1 - hp)

		-- Rays, glow, vignette.
		if won then
			local rays = key.rays
			local rp = clamp01((t - rays.start) / rays.dur)
			local raysImage = parts.rays
			if raysImage then
				raysImage.ImageTransparency = 1 - (1 - rays.toTransparency) * rp
				scaleOf(raysImage).Scale = lerp(rays.fromScale, 1, cubicOut(rp))
				raysImage.Rotation = seconds * rays.spinDegPerSec
			end
			local glow = parts.glow
			if glow then
				glow.ImageTransparency = 1 - 0.8 * rp
				scaleOf(glow).Scale = 0.95 + 0.05 * math.sin(seconds * 2.4)
			end
		else
			local g = key.glow
			local glow = parts.glow
			if glow then
				local gp = clamp01((t - g.start) / g.dur)
				local pulse = math.sin(seconds * g.pulseRadPerSec)
				-- Softer than the reference (0.7 ± 0.3): the red was too much.
				glow.ImageTransparency = 1 - clamp01(gp * (0.45 + 0.15 * pulse))
				scaleOf(glow).Scale = 1 + 0.06 * pulse
			end
			local v = key.vignette
			local mid = (v.opacity[1] + v.opacity[2]) / 2
			local swing = (v.opacity[2] - v.opacity[1]) / 2
			local opacity = clamp01((t - v.start) / v.dur)
				* (mid + swing * math.sin(seconds * v.pulseRadPerSec))
			for _, f in vignette do
				f.BackgroundTransparency = 1 - opacity
			end
		end

		-- Flash.
		local fl = key.flash
		flash.ImageTransparency = 1
			- math.max(0, 1 - math.abs(t - fl.peak) / fl.halfWidth) * fl.maxOpacity

		-- Shake: the whole panel, decaying.
		if not won then
			local sh = key.shake
			if t > sh.start and t < sh.start + sh.dur then
				local s = (1 - (t - sh.start) / sh.dur) * sh.amplitude
				place(parts.root, (random:NextNumber() - 0.5) * s, (random:NextNumber() - 0.5) * s)
			else
				place(parts.root, 0, 0)
			end
		end

		if won then
			-- Sparks burst out of the trophy.
			local k = key.sparks
			local p = clamp01((t - k.start) / k.dur)
			local out = cubicOut(p)
			for _, s in sparks do
				local live = p > 0 and p < 1
				s.frame.Visible = live
				if live then
					local at = HERO_CENTRE + s.dir * s.reach * out
					s.frame.Position = UDim2.fromOffset(at.X, at.Y)
					s.frame.BackgroundTransparency = p * p
					local size = s.size * (1 - p * 0.6)
					s.frame.Size = UDim2.fromOffset(size, size)
				end
			end

			-- Confetti: falls, sways, spins and flips, round and round.
			local c = key.confetti
			for _, bit in confetti do
				local te = t - c.start - bit.delay
				bit.frame.Visible = te >= 0
				if te >= 0 then
					local y = -30 + (te * bit.speed / 1000) % (parts.size.Y + 60)
					local x = bit.x0 + math.sin(seconds * bit.freq + bit.phase) * bit.sway
					bit.frame.Position = UDim2.fromOffset(x, y)
					bit.frame.Rotation = seconds * 90 * bit.freq + bit.phase * 50
					local flip = math.abs(math.cos(seconds * bit.spin + bit.phase))
					bit.frame.Size =
						UDim2.fromOffset(math.max(1, bit.width * flip), bit.frame.Size.Y.Offset)
				end
			end
		else
			-- Rocks: thrown up and out from the shield, then falling.
			local r = key.rocks
			local te = t - r.start
			local gravity = r.gravityPxPerSec2 / 1e6
			for _, rock in rocks do
				local live = te >= 0 and te <= r.life
				rock.frame.Visible = live
				if live then
					local x = rock.x0 + rock.vx * te
					local y = rock.y0 + rock.vy * te + gravity * te * te
					rock.frame.Position = UDim2.fromOffset(x, y)
					rock.frame.Rotation = rock.spin * te
					local fade = clamp01((te - (r.life - 400)) / 400)
					rock.frame.BackgroundTransparency = fade
					local stroke = rock.frame:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = fade
					end
				end
			end

			-- Embers: rising from the bottom, swaying, round and round.
			local e = key.embers
			for _, ember in embers do
				local et = t - e.start - ember.delay * 0.3
				ember.frame.Visible = et >= 0
				if et >= 0 then
					local y = parts.size.Y
						+ 16
						- ((et * ember.speed / 1000 + ember.delay * 0.1) % (parts.size.Y + 56))
					local x = ember.x0 + math.sin(seconds * 1.4 + ember.phase) * ember.sway
					ember.frame.Position = UDim2.fromOffset(x, y)
					ember.frame.BackgroundTransparency = 1 - math.clamp(y / 300, 0, 1) * 0.9
				end
			end
		end

		-- Stats panel slides up and fades in.
		local panel = key.panel
		local pp = clamp01((t - panel.start) / panel.dur)
		show(parts.statsGroup, pp > 0)
		place(parts.statsGroup, 0, panel.fromOffsetY * (1 - cubicOut(pp)))
		fadePanel(pp)

		-- Rows slide in and fade in, then count up.
		local rows = key.rows
		for i, r in parts.rows do
			local start = rows.start + (i - 1) * rows.stagger
			local rp = clamp01((t - start) / rows.dur)
			place(r, rows.fromOffsetX * (1 - cubicOut(rp)), 0)
			fadeRows[i](rp * pp)

			local count = parts.counts[i]
			if count and not (i == 3 and parts.fill) then
				local q = cubicOut(clamp01((t - start - rows.countDelay) / rows.countDur))
				count.label.Text = formatCount(count, count.target * q)
			end
		end

		-- Defeat's progress bar fills, and its percentage counts with it.
		local fill = parts.fill
		if fill and key.progress then
			local f = key.progress.fill
			local q = cubicOut(clamp01((t - f[1]) / (f[2] - f[1])))
			fill.Size = UDim2.fromScale(clamp01(parts.percent / 100) * q, 1)
			local count = parts.counts[3]
			if count then
				count.label.Text = formatCount(count, count.target * q)
			end
		end

		-- Button pops; once it is live it pulses, a shine sweeps across it,
		-- and Defeat's arrow spins now and then.
		local button = key.button
		local btp = clamp01((t - button.start) / button.dur)
		show(parts.buttonGroup, btp > 0)
		local live = t > button.enableAt
		local pulse = if live
			then 1 + button.pulse * math.sin(seconds * button.pulseRadPerSec)
			else 1
		scaleOf(parts.buttonGroup).Scale = math.max(0, backOut(btp)) * pulse

		parts.shine.Visible = live
		local sweep = (t % SHINE_PERIOD) / SHINE_PERIOD
		parts.shine.Position = UDim2.fromOffset(-120 + sweep * 620, 0)

		if not won then
			local every = button.iconSpinEvery
			local cycle = ((t - button.enableAt) % every + every) % every
			local spin = if live then cubicInOut(clamp01(cycle / button.iconSpinDur)) else 0
			parts.icon.Rotation = 360 * spin
		end
	end

	pose(0)
	local connection = RunService.RenderStepped:Connect(function()
		pose(now())
	end)

	local motion: Motion = {
		stop = function()
			connection:Disconnect()
		end,
		skip = function()
			local t = now()
			if t < key.button.enableAt then
				jumped += key.button.enableAt - t
			end
		end,
		ready = function()
			return now() >= key.button.enableAt
		end,
		hold = function(ms: number?)
			held = ms
		end,
	}
	return motion
end

return EndScreenMotion
