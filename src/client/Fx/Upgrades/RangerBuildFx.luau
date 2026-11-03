--!strict
--[[
	The Ranger's class upgrades of 2026-10-27, drawn big
	(`Combat/ClassUpgrades` decides every hit):

	- Phoenix Arrow (Mythic): the phoenix itself rides the arrow the server
	  sends with the "Phoenix" look: a blocky firebird, wings beating, its
	  tips cycling the rainbow (rule 12), shedding embers, lighting the room;
	  behind it the ground burns in flickering flame cubes for as long as
	  the server's fire hurts. A flash and a kick at the bow as it leaves.
	- Rain of Arrows (Legendary): a golden arrow shoots up out of the bow
	  with a flash in the sky, a gold ring closes on the target, then the
	  rain: each arrow drops from the sky onto the very spot the server
	  strikes, kicks up dust and sticks a moment.

	Presentation only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundFx = require(script.Parent.Parent.SoundFx)
local TopDownCamera = require(script.Parent.Parent.Parent.Camera.TopDownCamera)
local Voxel = require(script.Parent.Voxel)

local RangerBuildFx = {}

local FIRE = {
	Color3.fromRGB(255, 90, 30),
	Color3.fromRGB(255, 160, 40),
	Color3.fromRGB(255, 225, 90),
}
local GOLD = Color3.fromRGB(255, 205, 70)
local DUST = { Color3.fromRGB(196, 170, 120), Color3.fromRGB(150, 128, 92) }

--[[ One patch of the phoenix's burning ground: flame cubes licking up for
     `life` seconds, then shrinking away. ]]
local function firePatch(at: Vector3, radius: number, life: number)
	local count = Voxel.share(5)
	local flames: { { part: Part, x: number, z: number, phase: number } } = {}
	for index = 1, count do
		local angle = math.random() * math.pi * 2
		local r = radius * 0.7 * math.sqrt(math.random())
		local part = Voxel.cube(0.7, FIRE[(index - 1) % #FIRE + 1], true)
		table.insert(flames, {
			part = part,
			x = at.X + math.cos(angle) * r,
			z = at.Z + math.sin(angle) * r,
			phase = math.random() * 3,
		})
	end
	local scorch =
		Voxel.cube(Vector3.new(radius * 1.6, 0.08, radius * 1.6), Color3.fromRGB(40, 22, 18))
	scorch.CFrame = CFrame.new(at.X, 0.06, at.Z) * CFrame.Angles(0, math.random() * 3, 0)
	scorch.Transparency = 0.35
	local elapsed = 0
	Voxel.run(life, function(t, dt)
		elapsed += dt
		local fade = if t > 0.8 then (1 - t) / 0.2 else 1
		for _, flame in flames do
			-- each flame climbs and drops back, stepped like a voxel fire
			local cycle = (elapsed * 2.2 + flame.phase) % 1
			local height = math.floor(cycle * 4) / 4 * 1.6 * fade
			local size = (0.9 - cycle * 0.5) * fade
			flame.part.Size = Vector3.one * math.max(0.05, size)
			flame.part.CFrame = CFrame.new(flame.x, 0.35 + height, flame.z)
				* CFrame.Angles(0, elapsed * 2 + flame.phase, 0)
			flame.part.Color = FIRE[math.floor(cycle * #FIRE) % #FIRE + 1]
		end
		scorch.Transparency = 0.35 + 0.65 * (1 - fade)
		return nil
	end, function()
		for _, flame in flames do
			flame.part:Destroy()
		end
		scorch:Destroy()
	end)
end

--[[ The phoenix: a body of fire cubes round the arrow, a gold beak, two
     beating wings of three blocks each and a tail; returns the model and
     a function posing it at a frame for a time. ]]
local function buildPhoenix(): (Model, (frame: CFrame, time: number) -> ())
	local model = Instance.new("Model")
	model.Name = "Phoenix"
	model.Parent = Voxel.folder()
	local body = Voxel.cube(Vector3.new(1.3, 1.1, 2.4), FIRE[2], true, model)
	local head = Voxel.cube(Vector3.new(0.9, 0.9, 0.9), FIRE[3], true, model)
	local beak = Voxel.cube(Vector3.new(0.4, 0.4, 0.7), Color3.fromRGB(255, 200, 40), false, model)
	local crest = Voxel.cube(Vector3.new(0.25, 0.7, 0.5), FIRE[1], true, model)
	local wings: { Part } = {}
	for side = -1, 1, 2 do
		for segment = 1, 3 do
			local wing =
				Voxel.cube(Vector3.new(1.1, 0.25, 1.3 - segment * 0.25), FIRE[segment], true, model)
			wing:SetAttribute("Side", side)
			wing:SetAttribute("Segment", segment)
			table.insert(wings, wing)
		end
	end
	local tail: { Part } = {}
	for segment = 1, 4 do
		table.insert(
			tail,
			Voxel.cube(Vector3.one * (0.8 - segment * 0.12), FIRE[(segment % 3) + 1], true, model)
		)
	end
	Voxel.light(body, FIRE[2], 16, 3)

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(FIRE[3], FIRE[1])
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.5, 0)
	embers.Lifetime = NumberRange.new(0.3, 0.6)
	embers.Speed = NumberRange.new(1, 4)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Rate = 60 * Voxel.share(10) / 10
	embers.Parent = body

	local function pose(frame: CFrame, time: number)
		body.CFrame = frame
		head.CFrame = frame * CFrame.new(0, 0.35, -1.5)
		beak.CFrame = frame * CFrame.new(0, 0.3, -2.15)
		crest.CFrame = frame * CFrame.new(0, 1, -1.3) * CFrame.Angles(math.rad(-25), 0, 0)
		local flap = math.sin(time * 18) * math.rad(35)
		for _, wing in wings do
			local side = wing:GetAttribute("Side") :: number
			local segment = wing:GetAttribute("Segment") :: number
			-- each segment further out, bending more with the beat
			local angle = flap * (0.6 + segment * 0.25)
			local out = 0.65 + (segment - 0.5) * 1.0
			wing.CFrame = frame
				* CFrame.new(side * 0.6, 0.2, 0.1 + segment * 0.25)
				* CFrame.Angles(0, 0, side * angle)
				* CFrame.new(side * out, 0, 0)
			-- the outermost blocks cycle the rainbow: a Mythic's glow
			if segment == 3 then
				wing.Color = Voxel.rainbow(time, if side > 0 then 0 else 0.5)
			end
		end
		for index, piece in tail do
			local sway = math.sin(time * 10 - index) * 0.25 * index
			piece.CFrame = frame * CFrame.new(sway, 0.1, 1.2 + index * 0.65)
		end
	end
	return model, pose
end

local function onLaunched(part: BasePart, _pool: string, aim: Vector3, _from: Model?, look: string?)
	if look ~= "Phoenix" then
		return
	end
	local config = Balance.Player.phoenix
	local model, pose = buildPhoenix()
	local heading = Vector3.new(aim.X, 0, aim.Z).Unit
	SoundFx.play("fx_phoenix")
	Voxel.flash(part.Position, 4, FIRE[2], 0.3)
	Voxel.burst(part.Position, 14, FIRE, 12, 0.6, 0.5, 6)
	TopDownCamera.shake(0.25, 0.2)

	local started = os.clock()
	local lastDrop = part.Position
	local dropped = 0
	Voxel.run(math.huge, function()
		if not part.Parent then
			return false
		end
		local position = part.Position
		local time = os.clock() - started
		-- a little lift and roll, so it flies rather than slides
		local frame = CFrame.lookAt(position, position + heading)
			* CFrame.new(0, 0.4 + math.sin(time * 9) * 0.25, 0)
			* CFrame.Angles(0, 0, math.sin(time * 6) * 0.25)
		pose(frame, time)
		-- the ground burns where it passed, patch by patch as the server's
		local travelled = Vector3.new(position.X - lastDrop.X, 0, position.Z - lastDrop.Z).Magnitude
		if travelled >= config.trailStep or dropped == 0 then
			dropped += 1
			lastDrop = position
			firePatch(position, config.trailRadius, config.trailDuration)
		end
		return nil
	end, function()
		-- it bursts into embers where it ends
		local at = model:FindFirstChildWhichIsA("BasePart") :: BasePart?
		if at then
			Voxel.burst(at.Position, 18, FIRE, 14, 0.7, 0.6, 8)
			Voxel.flash(at.Position, 5, FIRE[3], 0.35)
		end
		model:Destroy()
	end)
end

--[[ Rain of Arrows: the arrow up, the ring, the rain. ]]
local function onRain(
	origin: Vector3,
	target: Vector3,
	points: { Vector3 },
	delay: number,
	stagger: number,
	radius: number
)
	SoundFx.play("fx_arrow_rain")
	local SKY = 28
	-- the golden arrow shooting straight up out of the bow
	local up = Voxel.arrow(1.3, GOLD)
	Voxel.flash(origin, 2.5, GOLD, 0.25)
	local rise = math.min(delay * 0.6, 0.4)
	Voxel.run(rise, function(t)
		local height = origin.Y + SKY * (t ^ 0.6)
		up:PivotTo(
			CFrame.lookAt(
				Vector3.new(origin.X, height, origin.Z),
				Vector3.new(origin.X, height + 1, origin.Z)
			)
		)
		return nil
	end, function()
		Voxel.flash(Vector3.new(origin.X, origin.Y + SKY, origin.Z), 6, GOLD, 0.35)
		up:Destroy()
	end)

	-- a gold ring of cubes closing on the target until the rain lands
	local n = Voxel.share(20)
	local marks: { Part } = {}
	for index = 1, n do
		table.insert(
			marks,
			Voxel.cube(0.6, if index % 2 == 0 then GOLD else Color3.fromRGB(255, 240, 180), true)
		)
	end
	local last = delay + stagger * (#points - 1) + 0.2
	Voxel.run(last, function(t)
		local close = math.clamp(t * last / delay, 0, 1)
		local r = radius * (1.25 - 0.25 * close)
		for index, mark in marks do
			local angle = (index / n) * math.pi * 2 + t * 2
			mark.CFrame = CFrame.new(
				target.X + math.cos(angle) * r,
				0.3,
				target.Z + math.sin(angle) * r
			) * CFrame.Angles(0, -angle, 0)
			mark.Transparency = if t > 0.85 then (t - 0.85) / 0.15 else 0.1
		end
		return nil
	end, function()
		for _, mark in marks do
			mark:Destroy()
		end
	end)

	-- each arrow drops from the sky onto its own spot, landing as it strikes
	local FALL = 0.22
	for index, point in points do
		local lands = delay + (index - 1) * stagger
		task.delay(math.max(0, lands - FALL), function()
			local arrow = Voxel.arrow(1.1, GOLD)
			local from = Vector3.new(point.X + 2, SKY, point.Z + 3)
			local to = Vector3.new(point.X, 0.9, point.Z)
			local heading = (to - from).Unit
			Voxel.run(FALL, function(t)
				arrow:PivotTo(CFrame.lookAt(from:Lerp(to, t), from:Lerp(to, t) + heading))
				return nil
			end, function()
				Voxel.burst(point, 5, DUST, 6, 0.45, 0.35, 5)
				Voxel.flash(Vector3.new(point.X, 0.5, point.Z), 1.6, GOLD, 0.2)
				-- stuck a moment, then gone
				Voxel.run(0.7, function(t)
					for _, piece in arrow:GetChildren() do
						if piece:IsA("BasePart") then
							piece.LocalTransparencyModifier = math.clamp((t - 0.6) / 0.4, 0, 1)
						end
					end
					return nil
				end, function()
					arrow:Destroy()
				end)
			end)
		end)
	end
	task.delay(delay, function()
		TopDownCamera.shake(0.2, delay + stagger * #points)
	end)
end

function RangerBuildFx.start()
	FxEvents.launched:connect(onLaunched)
	Remotes.event(Remotes.UpgradeFx).OnClientEvent
		:Connect(function(kind: string, _owner: Player, ...)
			if kind == "ArrowRain" then
				onRain(...)
			end
		end)
end

return RangerBuildFx
