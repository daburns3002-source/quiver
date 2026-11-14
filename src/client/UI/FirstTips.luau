--!strict
--[[
	First-time tips (`Config/Tips`; owner, 2026-11-13: "there should be a
	tutorial for everything new that the player has not done yet. if they
	have already seen that certain tutorial tip then dont play it anymore").

	`FirstTips.show(key)` is all a screen calls: the lobby's stations as each
	opens (`UI/StationScreen`), the portal, the Soulstone shop, a boss once
	its banner has gone, a draft with a redeal, a lost run, an Endless
	checkpoint. What the profile itself says is new (a first pet, a weapon
	beyond the starters, three of a tier to merge, the first gems or boss
	item) is asked here in the lobby, and a first area past Mossy Glade in a
	run.

	Whether one may show is `Util/TipRules.due`, the one rule: never seen in
	the save, not shown yet this visit. Once a tip is on screen the server
	is told (`Remotes.TipSeen`) and keeps it, so it never shows again.

	A tip holds everything until OK (owner, 2026-11-13: "they should be in
	the outer arena area so it doesnt block the arena, and also pause the
	game and have an ok button to dismiss the tip and resume the game. make
	sure the music quiets as well while its paused"): its card stands
	beside the arena, in the side margin a landscape screen has or above or
	below it on an upright phone (`TipRules.place`), on the loading tip's
	plate (`TipPlate.card`) with a green OK. While it is up the client is
	paused (`RunPaused.setTip`), the server holds the run
	(`RunSession.anyReadingTip`, `Tips.holdMax` at most) and the music is
	down (`MusicFx.setTip`). OK, Return, Enter or a gamepad's A closes it,
	so a probe clears it with a synthetic Return. One shows at a time. It
	waits while the title, the story, a story beat, an area's loading
	screen, a boss banner, NEW ENEMY!, MENU's panel, a hatch or class
	select (for every tip but its own) is up, and in the tutorial, which
	teaches by its own prompts; one asked for in a moment that cannot show
	it is let go after `PATIENCE` and asked again the next time that thing
	happens.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local PromptText = require(ReplicatedStorage.Shared.Util.PromptText)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TipPlate = require(ReplicatedStorage.Shared.Util.TipPlate)
local TipRules = require(ReplicatedStorage.Shared.Util.TipRules)
local Tips = require(ReplicatedStorage.Shared.Config.Tips)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local Chunky = require(script.Parent.Chunky)
local MusicFx = require(script.Parent.Parent.Fx.MusicFx)
local Reveal = require(script.Parent.Reveal)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local FirstTips = {}

--[[ Seconds a tip asked for may wait to be shown before it is let go. ]]
local PATIENCE = 12
--[[ Seconds between looks at what the profile and the stage say is new. ]]
local LOOK_EVERY = 1
--[[ Above the station screens (115), a hatch (180) and class select
     (200), for its own tip; under an area's loading screen (900). The
     title and the story are as high, but no tip shows while they are up. ]]
local DISPLAY_ORDER = 205
--[[ The OK button's size on the card, in points: a thumb's 48 tall. ]]
local OK_WIDTH = 150
local OK_HEIGHT = 48
--[[ Seconds after a tip closes that its key press is still its own. ]]
local KEY_GRACE = 0.3

--[[ Screens that own the whole view while they exist in PlayerGui. ]]
local COVERS = { "IntroCutscene", "StoryCutscene", "StoryBeat", "AreaLoading" }

--[[ The save's `tipsSeen`, nil until the profile has come. ]]
local seen: { [string]: boolean }? = nil
local latest: SaveSchema.Profile? = nil
--[[ Shown this visit, ahead of the server's answer. ]]
local shown: { [string]: boolean } = {}
type Waiting = { key: string, asked: number }
local queue: { Waiting } = {}
local current: GuiObject? = nil
-- when the last tip was closed, for `takesKeys`
local closedAt = -math.huge
--[[ Gamepad and Enter navigation: what was selected before the tip took
     the selection for its OK, given back after; and the watch that keeps
     it on OK while the tip is up (a screen under it, the portal's START,
     selects its own button just after asking for the tip). ]]
local restoreSelection: GuiObject? = nil
local selectionWatch: RBXScriptConnection? = nil
local nextAt = 0
local gui: ScreenGui? = nil

--[[ The starters every profile holds, so a weapon beyond them is new. ]]
local starters = SaveSchema.default().weapons
local firstArea = Balance.Stages[Balance.campaign[1]].area

local function reducedMotion(): boolean
	local ok, on = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and on == true
end

local function inTutorial(): boolean
	return Workspace:GetAttribute("InLobby") ~= true
		and CurrentStage.index() == Balance.tutorialStage
end

--[[ Whether something else owns the screen, so tip `key` waits. Class
     select owns it for every tip but its own. ]]
local function covered(key: string): boolean
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui or RunPaused.covered() or Reveal.busy() or inTutorial() then
		return true
	end
	if (player:GetAttribute("ClassSelecting") == true) ~= (key == "ClassSelect") then
		return true
	end
	for _, name in COVERS do
		if playerGui:FindFirstChild(name) then
			return true
		end
	end
	return false
end

--[[ The arena's box on the screen, clipped to it: what a tip keeps clear
     of. Nil in the lobby, or with no room built. The room is centred on
     the world's origin (`TopDownCamera`), walls included. ]]
local function arenaBox(w: number, h: number): TipRules.Box?
	if Workspace:GetAttribute("InLobby") == true or not Workspace:FindFirstChild("Arena") then
		return nil
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local arena = Balance.Arena
	local hx = arena.size.X / 2 + arena.wallThickness
	local hz = arena.size.Z / 2 + arena.wallThickness
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, y in { 0, arena.wallHeight } do
		for _, corner in
			{
				Vector3.new(-hx, y, -hz),
				Vector3.new(hx, y, -hz),
				Vector3.new(-hx, y, hz),
				Vector3.new(hx, y, hz),
			}
		do
			local point, inFront = camera:WorldToViewportPoint(corner)
			if inFront then
				minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
				minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
			end
		end
	end
	if minX > maxX then
		return nil
	end
	minX, maxX = math.clamp(minX, 0, w), math.clamp(maxX, 0, w)
	minY, maxY = math.clamp(minY, 0, h), math.clamp(maxY, 0, h)
	return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

--[[ OK: the tip goes, the run and the music come back. ]]
local function close(item: GuiObject)
	if current ~= item then
		return
	end
	current = nil
	closedAt = os.clock()
	nextAt = closedAt + Tips.gap
	RunPaused.setTip(false)
	MusicFx.setTip(false)
	Remotes.event(Remotes.TipClosed):FireServer()
	SoundFx.play("card_click")
	if selectionWatch then
		selectionWatch:Disconnect()
		selectionWatch = nil
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(item) then
		GuiService.SelectedObject = nil
	end
	-- given back once this press is done, so it cannot press that too
	local restore = restoreSelection
	restoreSelection = nil
	if restore then
		task.delay(KEY_GRACE, function()
			if current == nil and restore:IsDescendantOf(game) and restore.Visible then
				GuiService.SelectedObject = restore
			end
		end)
	end
	local scale = item:FindFirstChild("PopScale") :: UIScale?
	if scale and not reducedMotion() then
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		tween.Completed:Once(function()
			item:Destroy()
		end)
		tween:Play()
	else
		item:Destroy()
	end
end

--[[ The tip's card beside the arena with its OK, the run held and the
     music down until OK. ]]
local function draw(key: string)
	local screen = gui
	local tip = Tips.tips[key]
	if not screen or not tip then
		return
	end
	local size = screen.AbsoluteSize
	local placed =
		TipRules.place(size.X, size.Y, GuiService:GetGuiInset().Y, arenaBox(size.X, size.Y))
	local box = placed.box
	-- the card takes every press that lands on it, and only those
	local holder = Instance.new("Frame")
	holder.Name = "Tip_" .. key
	holder.Active = true
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(box.x + box.w / 2, box.y + box.h / 2)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(box.w, box.h)
	holder:SetAttribute("Side", placed.side)
	holder.Parent = screen
	local words =
		TipPlate.card(holder, Vector2.new(box.w, box.h), PromptText.plain(tip.text), 2, OK_HEIGHT)
	words.RichText = true
	words.Text = PromptText.rich(tip.text, PromptText.palette(UiPalette.card))
	local sheet = Chunky.pointSheet(holder, box.w, box.h)
	local pad = TipPlate.CARD_PAD
	local okWidth = math.min(OK_WIDTH, box.w - pad * 2)
	local ok = Chunky.button(
		sheet,
		"OK",
		Chunky.green,
		(box.w - okWidth),
		(box.h - pad - OK_HEIGHT) * 2,
		okWidth * 2,
		OK_HEIGHT * 2,
		function()
			close(holder)
		end
	)
	ok.Name = "Ok"
	if not reducedMotion() then
		local scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Scale = 0.82
		scale.Parent = holder
		TweenService
			:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			})
			:Play()
	end
	current = holder
	RunPaused.setTip(true)
	MusicFx.setTip(true)
	--[[ Enter and a gamepad's A press whatever is selected: while the tip
	     is up that is its OK, never a button under it. Taken after the
	     caller has finished, since a screen that asks for a tip as it opens
	     may then select its own. ]]
	local face = ok:FindFirstChildWhichIsA("GuiButton", true)
	if face and (UserInputService.GamepadEnabled or GuiService.SelectedObject ~= nil) then
		task.defer(function()
			if current ~= holder then
				return
			end
			local before = GuiService.SelectedObject
			restoreSelection = if before and not before:IsDescendantOf(holder) then before else nil
			GuiService.SelectedObject = face
			selectionWatch = GuiService:GetPropertyChangedSignal("SelectedObject")
				:Connect(function()
					local now = GuiService.SelectedObject
					if current == holder and now ~= face then
						if now and not now:IsDescendantOf(holder) then
							restoreSelection = now
						end
						GuiService.SelectedObject = face
					end
				end)
		end)
	end
end

--[[ Puts up the next tip waiting, if one may show now. ]]
local function pump()
	local now = os.clock()
	-- let go of tips that waited too long; they are asked again next time
	for i = #queue, 1, -1 do
		local waiting = queue[i]
		if
			now - waiting.asked > PATIENCE
			or (seen ~= nil and not TipRules.due(waiting.key, seen, shown))
		then
			table.remove(queue, i)
		end
	end
	if
		seen == nil
		or gui == nil
		or current ~= nil
		or now < nextAt
		or #queue == 0
		or covered(queue[1].key)
	then
		return
	end
	local waiting = table.remove(queue, 1) :: Waiting
	if not TipRules.due(waiting.key, seen, shown) then
		return
	end
	shown[waiting.key] = true
	draw(waiting.key)
	Remotes.event(Remotes.TipSeen):FireServer(waiting.key)
end

--[[ Whether Return, Enter or A belongs to a tip: one is up, or one closed
     a moment ago on that very press. A screen under a tip that also answers
     those keys (NEW ENEMY!'s GOT IT!, the portal's START, the draft's
     CHOOSE on A) asks this first, so one press closes the tip and nothing
     else. ]]
function FirstTips.takesKeys(): boolean
	return current ~= nil or os.clock() - closedAt < KEY_GRACE
end

--[[ Asks for tip `key`: shown once ever, when the screen is free. ]]
function FirstTips.show(key: string)
	if not TipRules.due(key, seen, shown) then
		return
	end
	for _, waiting in queue do
		if waiting.key == key then
			return
		end
	end
	table.insert(queue, { key = key, asked = os.clock() })
	pump()
end

--[[ Class select while it is up; what the profile says is new, in the
     lobby; and a first area past Mossy Glade in a run. ]]
local function look()
	if Players.LocalPlayer:GetAttribute("ClassSelecting") == true then
		FirstTips.show("ClassSelect")
	elseif Workspace:GetAttribute("InLobby") == true then
		local profile = latest
		if not profile then
			return
		end
		if next(profile.pets) ~= nil then
			FirstTips.show("FirstPet")
		end
		for weapon in profile.weapons do
			if not starters[weapon] then
				FirstTips.show("NewWeapon")
				break
			end
		end
		local tiers = profile.tiers
		local books: { { [string]: MergeRules.Counts } } = if tiers
			then { tiers.weapons, tiers.pets }
			else {}
		for _, book in books do
			for _, counts in book do
				for _, tier in MergeRules.TIERS do
					if MergeRules.canMerge(counts, tier) then
						FirstTips.show("Merge")
					end
				end
			end
		end
		if profile.gems > 0 then
			FirstTips.show("Gems")
		end
		if next(profile.items) ~= nil then
			FirstTips.show("BossItem")
		end
	else
		local stage = CurrentStage.config()
		if
			stage.mode ~= "Endless"
			and stage.area ~= nil
			and stage.area ~= firstArea
			and not inTutorial()
		then
			FirstTips.show("NewArea")
		end
	end
end

function FirstTips.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local made = Instance.new("ScreenGui")
	made.Name = "FirstTips"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	-- in the viewport's own points, as the arena is projected (`arenaBox`)
	made.ScreenInsets = Enum.ScreenInsets.None
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.DisplayOrder = DISPLAY_ORDER
	made.Parent = playerGui
	gui = made

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(profile)
		if type(profile) == "table" then
			latest = profile
			seen = if type(profile.tipsSeen) == "table" then profile.tipsSeen else {}
		end
	end)
	Remotes.event(Remotes.RunSummary).OnClientEvent:Connect(function(summary)
		if type(summary) == "table" and summary.won == false then
			FirstTips.show("Defeat")
		end
	end)
	Remotes.event(Remotes.EndlessCheckpoint).OnClientEvent:Connect(function()
		FirstTips.show("EndlessCheckpoint")
	end)

	--[[ OK by key too: Return or Enter, or A on a gamepad. A probe's
	     synthetic Return clears it, as it does NEW ENEMY!. ]]
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local item = current
		local key = input.KeyCode
		if
			item
			and (
				key == Enum.KeyCode.Return
				or key == Enum.KeyCode.KeypadEnter
				or key == Enum.KeyCode.ButtonA
			)
		then
			close(item)
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= LOOK_EVERY then
			since = 0
			look()
		end
		pump()
	end)
end

return FirstTips
