--!strict
--[[
	The run's control menu (owner, 2026-10-29: "there needs to be a back to
	lobby button built into the game while you are mid room"; 2026-10-31: "it
	should be on the left side").

	On the left edge at mid-height, directly under the Studio SANDBOX tab
	(owner, 2026-10-31: "i want it right below the sandbox button").

	It is placed in raw pixels off the left edge rather than through
	`Kit.put`, which lays out against a 1920x1080 sheet: the SANDBOX tab
	(`UI/SandboxMenu`) is anchored at (0, 8) and half the viewport's height
	in raw pixels too, so matching that is the only way the two stay lined up
	at a window size other than 1920x1080 — which, in Studio, is every window
	size. The sheet would have put it right only on one.

	Leaving is asked for twice. The menu button opens a panel that says what
	it costs rather than doing it, because a mis-tap mid-fight would throw the
	run away and the player cannot undo it. The server still decides:
	`Remotes.RunLobby` is a request, and `RoomController.requestLobby` refuses
	it unless there is a run to leave.

	Shown only while a run is on. In the lobby there is nothing to leave, and
	on the end screens the run is already over.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local ControlMenu = {}

--[[ The menu button, in raw pixels off the left edge at mid-height: `x`
     across, `drop` below the middle, `w` by `h`. Sized and offset to sit
     under the SANDBOX tab, which is 44 tall and centred, so its bottom edge
     is 22 below the middle and this starts 12 clear of it. ]]
local MENU = { x = 8, drop = 34, w = 136, h = 64 }
--[[ The confirm panel, on the 1920x1080 sheet `UI/Kit` lays out against. ]]
local PANEL = { x = 610, y = 350, w = 700, h = 380 }

local screen: ScreenGui? = nil
local panel: Frame? = nil
local open = false

local function setOpen(value: boolean)
	open = value
	if panel then
		panel.Visible = value
	end
end

--[[ Ask to leave. The server answers by putting everyone back in the lobby
     and broadcasting the state, which hides this menu again. ]]
local function leave()
	setOpen(false)
	Remotes.event(Remotes.RunLobby):FireServer()
end

local function build()
	if screen then
		return
	end
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	--[[ Sibling, as every screen but the class picker is: a ScreenGui made
	     in code defaults to Global, where `ZIndex` is compared across the
	     whole screen rather than between siblings. This one was left on the
	     default, so the MENU button's frame (`ZIndex` 5, set so the confirm
	     panel at 10 covers it) painted over its own label at 4 and the
	     button came out blank — owner, 2026-10-31: "it has no text right now
	     which needs to be fixed". Under Sibling a child always draws over
	     its parent and the two `ZIndex` values do only what they were
	     written for. ]]
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui

	local open_ = Kit.button(gui, "MENU", Kit.slate, function()
		setOpen(not open)
	end)
	open_.AnchorPoint = Vector2.new(0, 0)
	open_.Position = UDim2.new(0, MENU.x, 0.5, MENU.drop)
	open_.Size = UDim2.fromOffset(MENU.w, MENU.h)
	open_.ZIndex = 5

	local box = Kit.panel(gui, Kit.wood)
	Kit.put(box, PANEL.x, PANEL.y, PANEL.w, PANEL.h)
	box.ZIndex = 10
	box.Visible = false
	panel = box

	local title = Kit.label(box, "LEAVE THE RUN?")
	title.Position = UDim2.fromScale(0.06, 0.08)
	title.Size = UDim2.fromScale(0.88, 0.22)
	title.ZIndex = 11

	local line = Kit.label(box, "This run's progress is lost.")
	line.Position = UDim2.fromScale(0.06, 0.32)
	line.Size = UDim2.fromScale(0.88, 0.18)
	line.ZIndex = 11

	local go = Kit.button(box, "BACK TO LOBBY", Kit.gold, leave)
	go.Position = UDim2.fromScale(0.08, 0.56)
	go.Size = UDim2.fromScale(0.84, 0.18)
	go.ZIndex = 11

	local stay = Kit.button(box, "KEEP PLAYING", Kit.green, function()
		setOpen(false)
	end)
	stay.Position = UDim2.fromScale(0.08, 0.78)
	stay.Size = UDim2.fromScale(0.84, 0.16)
	stay.ZIndex = 11
end

--[[ Argument order matches `Remotes.RunStateChanged`, as `UI/RoomSign`'s
     does. Only a run being fought can be left: "Cleared" is between rooms
     and still a run, but "Dead" and "Complete" are the end screens, which
     carry their own way out. ]]
function ControlMenu.onRunStateChanged(_index: number, _total: number, state: string)
	build()
	local during = state == "Fighting" or state == "Cleared"
	if screen then
		screen.Enabled = during
	end
	if not during then
		setOpen(false)
	end
end

--[[ Back in the lobby: nothing to leave. ]]
function ControlMenu.hide()
	if screen then
		screen.Enabled = false
	end
	setOpen(false)
end

function ControlMenu.start()
	build()
end

return ControlMenu
