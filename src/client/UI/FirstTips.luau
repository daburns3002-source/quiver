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

	A tip never holds the run and never takes a press: it stands on the
	loading tip's plate (`Util/TipPlate`) under the top HUD for
	`Tips.seconds`, a tap puts it away, and the screen under it plays on. One
	shows at a time. It waits while the title, the story, a story beat, an
	area's loading screen, a boss banner, NEW ENEMY!, MENU's panel, a hatch
	or class select is up, and in the tutorial, which teaches by its own
	prompts; one asked for in a moment that cannot show it is let go after
	`PATIENCE` and asked again the next time that thing happens.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

local Reveal = require(script.Parent.Reveal)
local RunPaused = require(script.Parent.Parent.RunPaused)

local FirstTips = {}

--[[ Seconds a tip asked for may wait to be shown before it is let go. ]]
local PATIENCE = 12
--[[ Seconds between looks at what the profile and the stage say is new. ]]
local LOOK_EVERY = 1
--[[ Above the station screens (115), a hatch (180) and class select
     (200), for its own tip; under an area's loading screen (900). The
     title and the story are as high, but no tip shows while they are up. ]]
local DISPLAY_ORDER = 205

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

local function hide(item: GuiObject)
	if current == item then
		current = nil
		nextAt = os.clock() + Tips.gap
	end
	if reducedMotion() then
		item:Destroy()
		return
	end
	local scale = item:FindFirstChild("PopScale") :: UIScale?
	if scale then
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

local function draw(key: string)
	local screen = gui
	local tip = Tips.tips[key]
	if not screen or not tip then
		return
	end
	local size = screen.AbsoluteSize
	local box = TipRules.place(size.X, size.Y, GuiService:GetGuiInset().Y)
	-- the whole tip is one button: a tap puts it away
	local holder = Instance.new("TextButton")
	holder.Name = "Tip_" .. key
	holder.Text = ""
	holder.AutoButtonColor = false
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(box.x + box.w / 2, box.y + box.h / 2)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(box.w, box.h)
	holder.Parent = screen
	local words = TipPlate.fill(holder, Vector2.new(box.w, box.h), PromptText.plain(tip.text), 2)
	words.RichText = true
	words.Text = PromptText.rich(tip.text, PromptText.palette(UiPalette.card))
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
	holder.Activated:Connect(function()
		hide(holder)
	end)
	task.delay(Tips.seconds, function()
		if holder.Parent then
			hide(holder)
		end
	end)
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
	made.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
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
