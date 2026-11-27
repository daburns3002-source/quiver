--!strict
--[[
	Moves the parts the server animates at this screen's frame rate (owner,
	2026-11-10: "everything else that animates should be at 60fps").

	The server moves some anchored parts itself, every server frame: each
	enemy's hitbox (its body is welded to it), a boss's posed body parts, a
	lobby building's bob, the exit gate's door hinges and the Angel's bob.
	An anchored part's CFrame reaches a client only at the network's send
	rate, and the client puts it there with no blending, so on screen those
	moves step along at that rate however fast the screen draws.

	Each part the server tags `Tag` keeps the last two CFrames that came in,
	with when they came in. Every frame, before anything else draws, it is
	put between them, one update behind: the motion is the server's own,
	only drawn smoothly. Everything that reads the part afterwards this
	frame (the hit squash, the rig's pace, the health bars) reads that.

	A jump far further than any move (a room change, a spawn) and a part
	that has stopped getting updates both land exactly where the server
	put them. Presentation only: the server's copy never changes.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SmoothMotion = {}

--[[ The tag the server puts on a part it moves (`Shared` has no tag list,
     so it is spelled out on both sides). ]]
SmoothMotion.Tag = "SmoothMotion"

--[[ Studs between two updates beyond which the part was put somewhere
     new rather than moved, and is snapped. ]]
local SNAP = 12
--[[ How long the drawing runs behind the server's updates, at most
     (seconds). It follows how often they actually arrive. ]]
local MAX_DELAY = 0.1
--[[ How quickly the measured gap between updates follows a change. ]]
local GAP_EASE = 0.1

type Track = {
	part: BasePart,
	--[[ Drawn from `from` (as it stood at `fromAt`) to the server's latest,
	     `to`, which is reached `toAt`. A boss's parts squash and stretch, so
	     the size goes along with the CFrame. ]]
	fromAt: number,
	from: CFrame,
	fromSize: Vector3,
	toAt: number,
	to: CFrame,
	toSize: Vector3,
	--[[ What this module last wrote. The part holding anything else at
	     the start of a frame means the server's update came in since, which
	     is read here rather than from a changed signal: signals are
	     deferred, and a deferred one would run after this has already
	     drawn over the new value. ]]
	wrote: CFrame?,
	wroteSize: Vector3?,
}

local tracks: { [BasePart]: Track } = {}
--[[ The usual gap between two updates of one part (seconds); the drawing
     runs this far behind. Starts at a 30 Hz guess. ]]
local gap = 1 / 30
--[[ When any tracked part last got an update, for `gap`. ]]
local lastUpdate = 0

local function delay(): number
	return math.min(gap, MAX_DELAY)
end

--[[ A new update: the drawing carries on from where it is now and reaches
     it one gap later, so it never jumps, however unevenly updates come. ]]
local function received(track: Track, cf: CFrame, size: Vector3, now: number)
	local from = track.wrote or track.to
	local fromSize = track.wroteSize or track.toSize
	track.from, track.fromSize, track.fromAt = from, fromSize, now
	track.to, track.toSize, track.toAt = cf, size, now + delay()
	if (cf.Position - from.Position).Magnitude > SNAP then
		track.from, track.fromSize = cf, size
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or tracks[instance] then
		return
	end
	local part = instance :: BasePart
	local now = os.clock()
	tracks[part] = {
		part = part,
		fromAt = now,
		from = part.CFrame,
		fromSize = part.Size,
		toAt = now,
		to = part.CFrame,
		toSize = part.Size,
		wrote = nil,
		wroteSize = nil,
	}
end

local function remove(instance: Instance)
	tracks[instance :: BasePart] = nil
end

local function draw()
	local now = os.clock()
	local any = false
	for part, track in tracks do
		local held, heldSize = part.CFrame, part.Size
		local moved = held ~= track.wrote and held ~= track.to
		local grew = heldSize ~= track.wroteSize and heldSize ~= track.toSize
		if moved or grew then
			received(track, held, heldSize, now)
			any = true
		end
		local cf, size = track.to, track.toSize
		local span = track.toAt - track.fromAt
		if span > 0 and now < track.toAt then
			local alpha = math.clamp((now - track.fromAt) / span, 0, 1)
			cf = track.from:Lerp(track.to, alpha)
			size = track.fromSize:Lerp(track.toSize, alpha)
		end
		if held ~= cf then
			track.wrote = cf
			part.CFrame = cf
		end
		if heldSize ~= size then
			track.wroteSize = size
			part.Size = size
		end
	end
	--[[ One frame's updates are one packet: the gap is measured between
	     packets, not per part. ]]
	if any then
		local step = now - lastUpdate
		if step > 0.004 and step < 0.25 then
			gap += (step - gap) * GAP_EASE
		end
		lastUpdate = now
	end
end

function SmoothMotion.start()
	for _, instance in CollectionService:GetTagged(SmoothMotion.Tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(SmoothMotion.Tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(SmoothMotion.Tag):Connect(remove)
	-- first, so everything that reads these parts this frame reads them drawn
	RunService:BindToRenderStep("SmoothMotion", Enum.RenderPriority.First.Value, draw)
end

--[[ Studio checks: how many parts are tracked and the measured gap. ]]
function SmoothMotion.stats(): (number, number)
	local count = 0
	for _ in tracks do
		count += 1
	end
	return count, gap
end

return SmoothMotion
