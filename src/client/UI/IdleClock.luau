--!strict
--[[
	Co-op's idle clock on screen (`Shared/Util/IdlePick`, `docs/COOP.md`).

	A card screen or an Endless checkpoint left open is answered by the
	server once its clock runs out, so one player away from the keyboard
	cannot hold the run. This is the one line that says so, a pill over
	everything: on the open screen's own heading (a card screen fills a
	phone, and its heading is the one place that covers no card), or at
	the top of the screen with none open:

	- **PICKING FOR YOU IN 9** to the player whose screen it is, for the
	  clock's last seconds only (`Coop.idle.warn`);
	- **WAITING FOR ALEX: 23** to a teammate with no screen of their own,
	  who otherwise looks at a room that has stopped for no reason they can
	  see. Not for the first moment, or every quick pick would flash it;
	- **PICKED FOR YOU: MULTISHOT** once the server has picked.

	The clocks are the server's: each Player's `IdlePick.DRAFT` and
	`IdlePick.CHECKPOINT` attributes, in server time. Nothing here decides
	anything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Coop = require(ReplicatedStorage.Shared.Util.Coop)
local DraftScreen = require(script.Parent.Cards.DraftScreen)
local EndlessCheckpoint = require(script.Parent.EndlessCheckpoint)
local IdlePick = require(ReplicatedStorage.Shared.Util.IdlePick)
local Kit = require(script.Parent.Kit)
local UiContrast = require(ReplicatedStorage.Shared.Util.UiContrast)

local IdleClock = {}

--[[ Seconds a teammate's screen has been open before WAITING FOR shows,
     and seconds PICKED FOR YOU stays. ]]
local QUIET = 1.5
local SAID = 3.5
--[[ Seconds between reads of the clocks: the line counts whole seconds. ]]
local EVERY = 0.1
--[[ With no screen open: pixels down from the top of the screen, in the
     strip Roblox's own bar leaves empty in the middle, and how tall. ]]
local TOP = 6
local HEIGHT = 30
--[[ How wide the pill is for its height: its longest line fits. ]]
local WIDE = 11

local localPlayer = Players.LocalPlayer

local pill: Frame? = nil
local words: TextLabel? = nil
--[[ PICKED FOR YOU's words and `os.clock()` until which they stay. ]]
local said: string? = nil
local saidUntil = 0
--[[ `os.clock()` a teammate's clock was first seen running, nil with none. ]]
local waitingSince: number? = nil

--[[ The sooner of a player's two clocks, in whole seconds; nil with none. ]]
local function leftFor(player: Player, now: number): number?
	local draft = IdlePick.left(player:GetAttribute(IdlePick.DRAFT), now)
	local checkpoint = IdlePick.left(player:GetAttribute(IdlePick.CHECKPOINT), now)
	if draft and checkpoint then
		return math.min(draft, checkpoint)
	end
	return draft or checkpoint
end

local function line(): string?
	local clock = os.clock()
	if said and clock < saidUntil then
		return said
	end
	said = nil

	local now = Workspace:GetServerTimeNow()
	local mine = leftFor(localPlayer, now)

	--[[ The teammate the run has waited on longest is the one nearest
	     their pick. ]]
	local waitingOn: string? = nil
	local theirs: number? = nil
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer then
			local left = leftFor(other, now)
			if left and (not theirs or left < theirs) then
				waitingOn, theirs = other.DisplayName, left
			end
		end
	end
	if not theirs then
		waitingSince = nil
	elseif not waitingSince then
		waitingSince = clock
	end
	if waitingSince and clock - waitingSince < QUIET then
		waitingOn, theirs = nil, nil
	end

	return IdlePick.line(mine, Coop.idle.warn, waitingOn, theirs)
end

--[[ Puts the pill over the open screen's heading, or at the top of the
     screen with none open. ]]
local function place(frame: Frame, gui: ScreenGui)
	local at, size = DraftScreen.headingBox()
	if not at then
		at, size = EndlessCheckpoint.headingBox()
	end
	if at and size then
		local tall = math.max(HEIGHT, size.Y)
		local wide = math.max(tall * 4, math.min(tall * WIDE, size.X))
		local centre = at + size / 2 - gui.AbsolutePosition
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromOffset(centre.X, centre.Y)
		frame.Size = UDim2.fromOffset(wide, tall)
	else
		local wide = math.min(HEIGHT * WIDE, gui.AbsoluteSize.X * 0.6)
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, TOP)
		frame.Size = UDim2.fromOffset(wide, HEIGHT)
	end
end

--[[ The server picked for this player: `name` is what it took. ]]
function IdleClock.picked(name: string)
	said = IdlePick.picked(name)
	saidUntil = os.clock() + SAID
end

function IdleClock.start()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("IdleClock")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "IdleClock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- over the card screen (100) and the checkpoint (101)
	gui.DisplayOrder = 110
	gui.Parent = playerGui

	local frame = Kit.panel(gui, Kit.gold)
	frame.Name = "Pill"
	frame.Visible = false
	Kit.pill(frame)
	place(frame, gui)

	--[[ The gold face's own words (`UiContrast`): dark and unstroked. ]]
	local face = UiContrast.faceOf(Kit.gold)
	local label = Kit.label(frame, "", face.text)
	label.Name = "Words"
	label.Position = UDim2.fromScale(0.05, 0.12)
	label.Size = UDim2.fromScale(0.9, 0.76)
	if face.stroke then
		label.TextStrokeColor3 = face.stroke
	else
		label.TextStrokeTransparency = 1
	end

	pill = frame
	words = label

	local since = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		since += deltaTime
		if since < EVERY then
			return
		end
		since = 0
		local text = line()
		local p, w = pill, words
		if not p or not w then
			return
		end
		if text then
			if w.Text ~= text then
				w.Text = text
			end
			place(p, gui)
			p.Visible = true
		else
			p.Visible = false
		end
	end)
end

return IdleClock
