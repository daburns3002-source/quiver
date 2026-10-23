--!strict
--[[
	An enemy squashes when it is hit and springs back (owner, 2026-10-22:
	"make the enemies squish a little whenever they get hit and then revert
	back to their original form").

	Presentation only, and only on this client. The body flattens and widens
	about its feet, overshoots, and settles back to exactly the shape it was
	built in. The hitbox the server sweeps is never touched.

	The body's parts are welded to the hitbox, so for the length of a squash
	each part's weld is switched off here and the part is placed every frame
	relative to the hitbox, which keeps it following the enemy. At the end
	each part is put back exactly where it was and re-welded.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)

local HitSquash = {}

type Piece = {
	part: BasePart,
	weld: WeldConstraint?,
	size: Vector3,
	offset: CFrame,
}

type Squash = {
	hitbox: BasePart,
	pieces: { Piece },
	began: number,
}

local active: { [Model]: Squash } = {}
local connection: RBXScriptConnection? = nil

local function finish(model: Model, squash: Squash)
	for _, piece in squash.pieces do
		local part = piece.part
		if part.Parent then
			part.Size = piece.size
			part.CFrame = squash.hitbox.CFrame * piece.offset
			part.Anchored = false
			if piece.weld then
				piece.weld.Enabled = true
			end
		end
	end
	active[model] = nil
end

--[[ How squashed the body is at `t` seconds after the hit: below zero is
     flatter and wider, above is taller and narrower. A damped bounce that
     starts flat, overshoots once, and has all but settled by `duration`. ]]
local function amount(t: number): number
	local feedback = Balance.Feedback
	local duration = feedback.hitSquashDuration
	return -feedback.hitSquash * math.exp(-t * 5 / duration) * math.cos(t * math.pi * 3 / duration)
end

local function step()
	local now = os.clock()
	local duration = Balance.Feedback.hitSquashDuration

	for model, squash in active do
		local hitbox = squash.hitbox
		local t = now - squash.began
		if t >= duration or not hitbox.Parent then
			finish(model, squash)
			continue
		end

		local a = amount(t)
		local tall = 1 + a
		local wide = 1 / math.sqrt(tall)
		local floor = -hitbox.Size.Y / 2

		for _, piece in squash.pieces do
			local p = piece.offset.Position
			--[[ Scaled about the floor under the enemy, so it squashes onto
			     its feet rather than shrinking towards its middle. ]]
			local moved = Vector3.new(p.X * wide, floor + (p.Y - floor) * tall, p.Z * wide)
			piece.part.Size =
				Vector3.new(piece.size.X * wide, piece.size.Y * tall, piece.size.Z * wide)
			piece.part.CFrame = hitbox.CFrame * (CFrame.new(moved) * piece.offset.Rotation)
		end
	end

	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

function HitSquash.play(model: Model)
	local existing = active[model]
	if existing then
		-- Hit again mid-squash: start the bounce over from where the body is.
		existing.began = os.clock()
		return
	end

	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end

	local pieces: { Piece } = {}
	for _, child in model:GetChildren() do
		if
			child:IsA("BasePart")
			and child ~= hitbox
			and child:GetAttribute(EnemyDesigns.SkinTag)
		then
			local weld = child:FindFirstChildOfClass("WeldConstraint")
			table.insert(pieces, {
				part = child,
				weld = weld,
				size = child.Size,
				offset = hitbox.CFrame:ToObjectSpace(child.CFrame),
			})
		end
	end
	if #pieces == 0 then
		return
	end

	for _, piece in pieces do
		piece.part.Anchored = true
		if piece.weld then
			piece.weld.Enabled = false
		end
	end

	active[model] = { hitbox = hitbox, pieces = pieces, began = os.clock() }
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return HitSquash
