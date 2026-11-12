--!strict
--[[
	The run's control menu (owner, 2026-10-29: "there needs to be a back to
	lobby button built into the game while you are mid room"; 2026-10-31: "it
	should be on the left side").

	**On a computer** it is the MENU button on the left edge at mid-height,
	directly under the Studio SANDBOX tab (owner, 2026-10-31: "i want it
	right below the sandbox button"), placed in raw pixels as that tab is so
	the two stay lined up at any window size.

	**On a phone** it is a pause icon at the top left, under Roblox's own
	buttons and beside the run's top HUD (`Util/RunHudRules.top`,
	`Config/Hud` `top`): a thumb's 48 points square. The words-and-all
	button stood 136 x 64 at the left edge at mid-height, a third of a
	phone's width exactly where the thumb that moves comes down (the
	2026-11-11 loop and UI review). Still on the left, as asked.

	Leaving is asked for twice. The button opens a panel that says what it
	costs rather than doing it, because a mis-tap mid-fight would throw the
	run away and the player cannot undo it. The panel stops the fight while
	it is open (owner, 2026-11-05), on both sides: `RunPaused.setMenu` here
	and `RunSession.anyInMenu` on the server, which lets go by itself after
	`CombatTuning.menuHold` so one player cannot freeze everyone's run. The
	server still decides: `Remotes.RunLobby` is a request, and
	`RoomController.requestLobby` refuses it unless there is a run to leave.

	The panel says what is true: the coins a kill paid are already in the
	wallet and stay there; what ends is the run. (It used to say "This run's
	progress is lost.") It is drawn in the chunky kit (`UI/Chunky`), sized
	in screen points so a phone held upright gets a panel it can read: on
	the 1920 x 1080 sheet it came to about 142 points wide there.

	Shown only while a run is on. In the lobby there is nothing to leave, and
	on the end screens the run is already over.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chunky = require(script.Parent.Chunky)
local CombatTuning = require(ReplicatedStorage.Shared.Config.CombatTuning)
local HudLayout = require(script.Parent.HudLayout)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)

local ControlMenu = {}

--[[ A computer's MENU button, in raw pixels off the left edge at
     mid-height: `x` across, `drop` below the middle, `w` by `h`. Sized and
     offset to sit under the SANDBOX tab, which is 44 tall and centred, so
     its bottom edge is 22 below the middle and this starts 12 clear of it. ]]
local MENU = { x = 8, drop = 34, w = 136, h = 64 }
--[[ The shape the confirm panel is built in, in screen points. How large
     it is drawn comes from `RunHudRules.top`: fitted to a phone, grown on a
     computer's big screen. ]]
local PANEL = { w = 440, h = 273 }

local screen: ScreenGui? = nil
local panel: Frame? = nil
local wordsButton: Frame? = nil
local iconButton: Frame? = nil
local open = false

--[[ Bumped on every open or shut, so an old timer never shuts a panel opened
     since. ]]
local opening = 0

local function setOpen(value: boolean)
	local was = open
	open = value
	local box = panel
	if box then
		box.Visible = value
		if value and not was then
			Chunky.pop(box)
		end
	end
	if was == value then
		return
	end
	RunPaused.setMenu(value)
	Remotes.event(Remotes.RunMenu):FireServer(value)
	opening += 1
	if value then
		local this = opening
		--[[ The server stops holding at `menuHold`, so the panel cannot stay
		     up over a fight that has started again. ]]
		task.delay(CombatTuning.menuHold, function()
			if this == opening then
				setOpen(false)
			end
		end)
	end
end

--[[ Ask to leave. The server answers by putting everyone back in the lobby
     and broadcasting the state, which hides this menu again. ]]
local function leave()
	setOpen(false)
	Remotes.event(Remotes.RunLobby):FireServer()
end

local function toggle()
	setOpen(not open)
end

--[[ A frame the kit can draw on, `w` by `h` points. ]]
local function holder(gui: ScreenGui, name: string, w: number, h: number, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(w, h)
	frame.ZIndex = z
	frame.Parent = gui
	return frame
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
	     whole screen rather than between siblings, and the MENU button once
	     painted over its own label that way (owner, 2026-10-31: "it has no
	     text right now which needs to be fixed"). ]]
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui

	-- A computer's button, with the word on it.
	local words = holder(gui, "Menu", MENU.w, MENU.h, 5)
	words.Position = UDim2.new(0, MENU.x, 0.5, MENU.drop)
	local wordsSheet = Chunky.pointSheet(words, MENU.w, MENU.h)
	Chunky.button(wordsSheet, "MENU", Chunky.blue, 0, 0, wordsSheet.w, wordsSheet.h, toggle)
	wordsButton = words

	-- A phone's: a square with a pause mark, two white bars.
	local size = 48
	local icon = holder(gui, "MenuIcon", size, size, 5)
	local iconSheet = Chunky.pointSheet(icon, size, size)
	local square = Chunky.button(iconSheet, "", Chunky.blue, 0, 0, iconSheet.w, iconSheet.h, toggle)
	local face = square:FindFirstChild("Face", true)
	if face and face:IsA("Frame") then
		for side = -1, 1, 2 do
			local bar = Instance.new("Frame")
			bar.Name = "Pause"
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = Chunky.white
			bar.Position = UDim2.fromScale(0.5 + side * 0.15, 0.5)
			bar.Size = UDim2.fromScale(0.17, 0.5)
			bar.ZIndex = 14
			bar.Parent = face
			Chunky.round(bar, 5)
			Chunky.outline(bar, 4, Chunky.shade(Chunky.blue))
		end
	end
	iconButton = icon

	-- The confirm panel: built once at its own shape, sized as a whole.
	local box = holder(gui, "Confirm", PANEL.w, PANEL.h, 10)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Visible = false
	local sheet = Chunky.pointSheet(box, PANEL.w, PANEL.h)
	local w, h = sheet.w, sheet.h
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "LEAVE THE RUN?", 0, 0, w, 104)
	Chunky.close(sheet, 0, 0, 0, function()
		setOpen(false)
	end)
	local line = Chunky.text(box, "You keep your coins. The run ends here.", Chunky.ink, 0)
	line.Position = UDim2.fromScale(0.07, 0.25)
	line.Size = UDim2.fromScale(0.86, 0.2)
	line.TextWrapped = true
	Chunky.button(sheet, "BACK TO LOBBY", Chunky.red, 56, 268, w - 112, 110, leave)
	Chunky.button(sheet, "KEEP PLAYING", Chunky.green, 56, 396, w - 112, 110, function()
		setOpen(false)
	end)
	panel = box

	HudLayout.bindTop(function(layout)
		local wordsNow, iconNow, boxNow = wordsButton, iconButton, panel
		if not wordsNow or not iconNow or not boxNow then
			return
		end
		local at = layout.menu
		wordsNow.Visible = at == nil
		iconNow.Visible = at ~= nil
		if at then
			iconNow.Position = UDim2.fromOffset(at.x, at.y)
			iconNow.Size = UDim2.fromOffset(at.w, at.h)
		end
		local room = layout.panel
		local width = math.min(room.w, room.h * PANEL.w / PANEL.h)
		boxNow.Size = UDim2.fromOffset(width, width * PANEL.h / PANEL.w)
	end)
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
