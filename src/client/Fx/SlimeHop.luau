--!strict
--[[
	The slimes hop instead of gliding (the owner's
	design_handoff_slime_movement, 2026-10-23): every few studs a slime
	crouches, lurches forward with a small hop, lands with a squash and
	jiggles back to shape; when it stops it finishes the hop and breathes.

	Presentation only, and only on this client. The server moves the
	hitbox at a steady speed exactly as before; here the body's parts are
	unwelded and placed every frame from it. The hop's phase is the
	distance the hitbox has travelled forward over the hop's length, so
	every client sees the same rhythm without a byte of network. The body
	hangs back while crouching and catches up in the lurch, never more
	than about a third of a hop from the hitbox.

	A hit's squash (`Fx/HitSquash`) is folded in rather than fought over:
	the body is claimed from it, and its squash scales the hop's pose.
	The blob shadow stays on the floor under the body and shrinks as it
	rises. Which enemies hop, and the shape of a hop: `Balance.SlimeHop`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local HitSquash = require(script.Parent.HitSquash)
local HopCurve = require(ReplicatedStorage.Shared.Util.HopCurve)

local SlimeHop = {}

type Piece = {
	part: BasePart,
	size: Vector3,
	--[[ From the floor under the hitbox's centre, in the hitbox's frame. ]]
	offset: CFrame,
}

type Slime = {
	hitbox: BasePart,
	pieces: { Piece },
	shadow: Piece?,
	hop: number,
	height: number,
	--[[ Hops travelled; the fraction is how far through this one. ]]
	phase: number,
	--[[ Hops a second when it last moved, to finish a hop once stopped. ]]
	rate: number,
	still: number,
	clock: number,
	last: Vector3,
}

local slimes: { [Model]: Slime } = {}

--[[ Hops a second at least, to finish a hop after stopping. ]]
local MIN_FINISH_RATE = 1.2
--[[ How the finishing rate dies away once stopped. ]]
local RATE_DECAY = 2
--[[ How much a lifted body's shadow shrinks at the top of a hop. ]]
local SHADOW_SHRINK = 0.15

local function setup(model: Model)
	if slimes[model] then
		return
	end
	local kind = (Balance.SlimeHop.kinds :: any)[model.Name]
	local hitbox = model.PrimaryPart
	if not kind or not hitbox then
		return
	end

	local floor = hitbox.CFrame * CFrame.new(0, -hitbox.Size.Y / 2, 0)
	local slime: Slime = {
		hitbox = hitbox,
		pieces = {},
		shadow = nil,
		hop = kind.hop,
		height = kind.height,
		phase = 0,
		rate = 0,
		still = 0,
		clock = math.random() * 10,
		last = hitbox.Position,
	}
	for _, child in model:GetChildren() do
		if
			child:IsA("BasePart")
			and child ~= hitbox
			and child:GetAttribute(EnemyDesigns.SkinTag)
		then
			for _, weld in child:GetChildren() do
				if weld:IsA("WeldConstraint") then
					weld.Enabled = false
				end
			end
			child.Anchored = true
			local piece: Piece =
				{ part = child, size = child.Size, offset = floor:ToObjectSpace(child.CFrame) }
			if child.Name == "Shadow" then
				slime.shadow = piece
			else
				table.insert(slime.pieces, piece)
			end
		end
	end
	if #slime.pieces == 0 then
		return
	end
	HitSquash.claim(model)
	slimes[model] = slime
end

local function step(dt: number)
	local config = Balance.SlimeHop
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero

	for model, s in slimes do
		local hitbox = s.hitbox
		if not model.Parent or not hitbox.Parent then
			slimes[model] = nil
			continue
		end
		local at = hitbox.Position
		--[[ Only travel forward counts, so a knockback does not skip the
		     body through a hop. ]]
		local moved = Vector3.new(at.X - s.last.X, 0, at.Z - s.last.Z)
		local forward = math.max(0, moved:Dot(hitbox.CFrame.LookVector))
		s.last = at
		s.clock += dt
		if (at - eye).Magnitude > config.maxDistance then
			continue
		end

		if forward > 1e-3 then
			s.phase += forward / s.hop
			s.rate = forward / s.hop / math.max(dt, 1e-4)
			s.still = 0
		else
			s.still += dt
			--[[ Stopped mid-hop: finish it in time, and land on the hop's end. ]]
			if s.phase % 1 > 1e-3 then
				local nextPhase = s.phase + math.max(s.rate, MIN_FINISH_RATE) * dt
				s.phase = if math.floor(nextPhase) > math.floor(s.phase)
					then math.floor(nextPhase)
					else nextPhase
			end
			s.rate *= math.exp(-dt * RATE_DECAY)
		end

		local through = s.phase % 1
		local hop = HopCurve.sample(config.keys, through)
		local tall, wide, deep = hop.tall, hop.wide, hop.deep
		if s.still > config.idleAfter and through < 1e-3 then
			local breath = config.idleAmount * math.sin(s.clock * 2 * math.pi / config.idlePeriod)
			tall, wide, deep = 1 + breath, 1 - breath * 0.5, 1 - breath * 0.5
		end
		local squash = HitSquash.tall(model)
		local thin = 1 / math.sqrt(squash)
		tall, wide, deep = tall * squash, wide * thin, deep * thin

		--[[ Behind the hitbox while crouching, ahead of it in the lurch. ]]
		local ahead = s.hop * (hop.ease - through)
		local floor = hitbox.CFrame * CFrame.new(0, -hitbox.Size.Y / 2, -ahead)
		local frame = floor * CFrame.new(0, hop.lift * s.height, 0) * CFrame.Angles(-hop.tilt, 0, 0)
		local scale = Vector3.new(wide, tall, deep)
		for _, piece in s.pieces do
			local offset = piece.offset
			piece.part.CFrame = frame * (CFrame.new(offset.Position * scale) * offset.Rotation)
			-- In the part's own axes: exact for parts set upright in the model.
			local own = offset.Rotation:VectorToObjectSpace(scale)
			piece.part.Size = piece.size
				* Vector3.new(math.abs(own.X), math.abs(own.Y), math.abs(own.Z))
		end

		local shadow = s.shadow
		if shadow then
			local shrink = 1 - SHADOW_SHRINK * hop.lift
			shadow.part.CFrame = floor * shadow.offset
			shadow.part.Size = Vector3.new(
				shadow.size.X * wide * shrink,
				shadow.size.Y,
				shadow.size.Z * deep * shrink
			)
		end
	end
end

--[[ Watches every enemy that arrives. The "Enemies" folder is rebuilt
     each room, so it is followed by name. ]]
function SlimeHop.start(parent: Instance)
	local function watchFolder(folder: Instance)
		if folder.Name ~= "Enemies" or not folder:IsA("Folder") then
			return
		end
		local function arrive(child: Instance)
			if child:IsA("Model") then
				setup(child)
			end
		end
		for _, child in folder:GetChildren() do
			arrive(child)
		end
		folder.ChildAdded:Connect(arrive)
	end

	for _, child in parent:GetChildren() do
		watchFolder(child)
	end
	parent.ChildAdded:Connect(watchFolder)
	RunService.RenderStepped:Connect(step)
end

return SlimeHop
