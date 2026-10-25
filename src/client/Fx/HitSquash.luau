--!strict
--[[
	An enemy squashes when it is hit and springs back (owner, 2026-10-22:
	"make the enemies squish a little whenever they get hit and then revert
	back to their original form"), and lands with a bigger squash the moment
	it appears, as the Brood Slime's pieces do ("add the squash from the
	brood slime to every enemy").

	Presentation only, and only on this client. The body flattens and widens
	about its feet, overshoots, and settles back to exactly the shape it was
	built in. The hitbox the server sweeps is never touched.

	The body's parts are welded to the hitbox, so for the length of a squash
	each part's weld is switched off here and the part is placed every frame
	relative to the hitbox, which keeps it following the enemy. At the end
	each part is put back exactly where it was and re-welded.

	A slime's body is placed every frame by its hop (`Fx/SlimeHop`), which
	claims it (`HitSquash.claim`); then the squash is only timed here, and
	the hop folds it into its own pose (`HitSquash.tall`).
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
	strength: number,
	duration: number,
}

--[[ A hit's bounce, or the bigger one an enemy lands with as it appears,
     the same squash the Brood Slime's pieces land with (`Fx/SplitFx`). ]]
export type Kind = "Hit" | "Land"

local active: { [Model]: Squash } = {}
--[[ Bodies another module places, which only borrow the squash's timing. ]]
local claimed: { [Model]: true } = {}
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

--[[ How squashed the body is at `t` seconds in: below zero is flatter and
     wider, above is taller and narrower. A damped bounce that starts flat,
     overshoots once, and has all but settled by `duration`. ]]
local function amount(t: number, strength: number, duration: number): number
	return -strength * math.exp(-t * 5 / duration) * math.cos(t * math.pi * 3 / duration)
end

--[[ How hard a squash is for a body `height` studs tall. A hit flattens
     every enemy by about the same number of studs, so a small Moss Slime
     squashes as visibly as the big Brood Slime instead of by a sliver; a
     landing is the same for all. ]]
local function strengthFor(kind: Kind, height: number): number
	local feedback = Balance.Feedback
	if kind == "Land" then
		return feedback.landSquash
	end
	return math.clamp(feedback.hitSquashStuds / height, feedback.hitSquash, feedback.hitSquashMax)
end

local function step()
	local now = os.clock()

	for model, squash in active do
		local hitbox = squash.hitbox
		local t = now - squash.began
		if t >= squash.duration or not hitbox.Parent then
			finish(model, squash)
			continue
		end

		local a = amount(t, squash.strength, squash.duration)
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

function HitSquash.play(model: Model, kind: Kind?)
	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end
	--[[ A boss's body is posed by the server every frame (`BossBody`); a
	     squash here would fight it and snap it back to a stale shape. A
	     body that plays its own clips (`Fx/ModelAnimator`, Thornwood's
	     enemies) likewise: the squash welded its parts back to the hitbox
	     while the animator went on placing them, and the whole enemy
	     climbed into the sky (2026-10-25 playtest). ]]
	if model:GetAttribute("Boss") or model:GetAttribute("ModelClips") then
		return
	end

	local which: Kind = kind or "Hit"
	local feedback = Balance.Feedback
	local strength = strengthFor(which, hitbox.Size.Y)
	local duration = if which == "Land"
		then feedback.landSquashDuration
		else feedback.hitSquashDuration

	local existing = active[model]
	if existing then
		-- Again mid-squash: start the bounce over from where the body is.
		existing.began = os.clock()
		existing.strength = strength
		existing.duration = duration
		return
	end

	local pieces: { Piece } = {}
	local children: { Instance } = if claimed[model] then {} else model:GetChildren()
	for _, child in children do
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
	if #pieces == 0 and not claimed[model] then
		return
	end

	for _, piece in pieces do
		piece.part.Anchored = true
		if piece.weld then
			piece.weld.Enabled = false
		end
	end

	active[model] = {
		hitbox = hitbox,
		pieces = pieces,
		began = os.clock(),
		strength = strength,
		duration = duration,
	}
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

--[[ `model`'s body is placed by someone else from now on: its squashes
     are timed but not drawn here. ]]
function HitSquash.claim(model: Model)
	claimed[model] = true
	model.Destroying:Connect(function()
		claimed[model] = nil
	end)
end

--[[ How tall `model` is right now as a share of its height, for a body
     that draws its own squash: 1 when it is not squashed. The width is
     `1 / math.sqrt` of it. ]]
function HitSquash.tall(model: Model): number
	local squash = active[model]
	if not squash then
		return 1
	end
	local t = os.clock() - squash.began
	if t >= squash.duration then
		return 1
	end
	return 1 + amount(t, squash.strength, squash.duration)
end

--[[ Watches every enemy that arrives and lands it with a squash the moment
     it becomes real: the server marks that by setting `Targetable`, after
     its spawn marker (or its piece of a split) is done. The "Enemies" folder
     is rebuilt each room, so it is followed by name. ]]
function HitSquash.start(parent: Instance)
	local function watchEnemy(model: Instance)
		if not model:IsA("Model") then
			return
		end
		model:GetAttributeChangedSignal("Targetable"):Connect(function()
			if model:GetAttribute("Targetable") == true then
				HitSquash.play(model, "Land")
			end
		end)
	end

	local function watchFolder(folder: Instance)
		if folder.Name ~= "Enemies" or not folder:IsA("Folder") then
			return
		end
		for _, child in folder:GetChildren() do
			watchEnemy(child)
		end
		folder.ChildAdded:Connect(watchEnemy)
	end

	for _, child in parent:GetChildren() do
		watchFolder(child)
	end
	parent.ChildAdded:Connect(watchFolder)
end

return HitSquash
