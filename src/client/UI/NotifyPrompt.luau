--!strict
--[[
	The notifications' question (`Data/Notify`, `docs/NOTIFICATIONS.md`):
	GET A PING?, asked when the server says so (`Remotes.NotifyAsk`, just
	after a daily reward is claimed, never in a first session) and only
	once the player is free in the lobby with the REWARDS screen put away,
	so it never covers a reward or a run.

	Roblox's own opt-in (`ExperienceNotificationService:PromptOptIn`, its
	words fixed by Roblox) shows only behind YES, so a player who would say
	no never spends Roblox's once-in-30-days prompt. Where Roblox says it
	cannot ask (already opted in, under 13, asked lately) nothing shows and
	the server is told "cannot". NOT NOW is saved, and the rules wait days
	before asking again (`Util/NotifyRules`).

	A Chunky panel (`UI/Chunky`) like the store's offers, every word in
	Fredoka One, the one diamond as its picture.
]]

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Chunky = require(script.Parent.Chunky)
local Kit = require(script.Parent.Kit)
local PortalScreen = require(script.Parent.PortalScreen)
local RewardsScreen = require(script.Parent.RewardsScreen)

local NotifyPrompt = {}

local WIDTH = 380
local MARGIN = 12
--[[ Seconds the lobby must stay quiet before the question shows, and how
     long it waits for that before giving up for this session. ]]
local SETTLE = 1.5
local PATIENCE = 600

local TITLE = "GET A PING?"
local LINE = "Want Roblox to tell you when your daily reward is ready, "
	.. "your gift box is full or an event starts?"

local gui: ScreenGui? = nil
local asking = false

--[[ The device's offset from UTC in minutes, from its own clock. ]]
local function zone(): number
	local now = DateTime.now()
	local l = now:ToLocalTime() :: any
	local asUtc = DateTime.fromUniversalTime(l.Year, l.Month, l.Day, l.Hour, l.Minute, l.Second)
	return math.floor((asUtc.UnixTimestamp - now.UnixTimestamp) / 60 + 0.5)
end

local function answer(words: string)
	Remotes.event(Remotes.NotifyAnswer):FireServer(words, zone())
end

local function close()
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

--[[ Whether nothing else wants the player: in the lobby, arrived, no
     station, portal, REWARDS or store offer up. ]]
local function quiet(): boolean
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	local offer = playerGui:FindFirstChild("RobuxOffer")
	return Workspace:GetAttribute("InLobby") == true
		and player:GetAttribute("Arrived") == true
		and player:GetAttribute("ClassSelecting") ~= true
		and player:GetAttribute("InStation") ~= true
		and not PortalScreen.isOpen()
		and not RewardsScreen.isOpen()
		and not (offer and offer:IsA("ScreenGui") and offer.Enabled)
end

--[[ Waits for `SETTLE` quiet seconds in a row; false if `PATIENCE` runs
     out first. ]]
local function settle(): boolean
	local deadline = os.clock() + PATIENCE
	local since: number? = nil
	while os.clock() < deadline do
		if quiet() then
			since = since or os.clock()
			if os.clock() - (since :: number) >= SETTLE then
				return true
			end
		else
			since = nil
		end
		task.wait(0.25)
	end
	return false
end

--[[ The panel, with `yes` and `no` as its buttons' actions. ]]
local function show(yes: () -> (), no: () -> ())
	local screen = gui
	if not screen then
		return
	end
	close()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local w = WIDTH * 2
	local pad = 40
	local header = 104
	local iconTop, iconH = header + 24, 150
	local lineTop = iconTop + iconH + 12
	local lineH = 120
	local yesTop = lineTop + lineH + 20
	local buttonH = 116
	local noTop = yesTop + buttonH + 18
	local noH = 92
	local h = noTop + noH + 30 + 12
	local fit = RunHudRules.fit(view, WIDTH, h / 2, MARGIN)

	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Ask"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, TITLE, 0, 0, w, header)

	local picture = Kit.image(box, ShopAssets.gem)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.fromScale(0.5, iconTop / h)
	picture.Size = UDim2.fromScale(iconH / w, iconH / h)
	picture.ZIndex = 6
	local words = Chunky.text(box, LINE, Chunky.ink, 0)
	words.Position = UDim2.fromScale(pad / w, lineTop / h)
	words.Size = UDim2.fromScale(1 - 2 * pad / w, lineH / h)
	words.TextWrapped = true
	words.ZIndex = 6

	Chunky.button(sheet, "YES, TELL ME", Chunky.green, pad, yesTop, w - 2 * pad, buttonH, yes)
	Chunky.button(sheet, "NOT NOW", Chunky.grey, pad + 60, noTop, w - 2 * pad - 120, noH, no)
	screen.Enabled = true
	Chunky.pop(box)
end

--[[ The server asked. `preview` (Studio's look) shows the panel even
     where Roblox says it cannot ask. ]]
local function asked(preview: boolean)
	if asking then
		return
	end
	asking = true
	if not preview and not settle() then
		-- never quiet enough this session: asked another day
		asking = false
		return
	end
	local ok, can = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	local roblox = ok and can == true
	if not roblox and not preview then
		answer("cannot")
		asking = false
		return
	end
	local done = false
	show(function()
		if done then
			return
		end
		done = true
		close()
		answer("yes")
		if roblox then
			pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end)
		end
		asking = false
	end, function()
		if done then
			return
		end
		done = true
		close()
		answer("no")
		asking = false
	end)
end

function NotifyPrompt.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("NotifyPrompt")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "NotifyPrompt"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- with the store's offers, under a prize's reveal (150)
	screen.DisplayOrder = 140
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen
	Remotes.event(Remotes.NotifyAsk).OnClientEvent:Connect(function(preview: unknown)
		task.spawn(asked, preview == true)
	end)
end

return NotifyPrompt
