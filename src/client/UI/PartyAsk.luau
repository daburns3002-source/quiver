--!strict
--[[
	PARTY INVITE: someone in this server asks the local player into their
	party (`Remotes.PartyAsked`, from `Run/Parties`), with ACCEPT and
	DECLINE and the time left draining from a bar. The answer is only a
	request (`Remotes.PartyAnswer`): the server joins the party, or says why
	not (`UI/PartyScreen`'s news line). The prompt goes when it is answered,
	when its time runs out, or when the server takes the invite away
	(seconds 0: the sender left, or their party filled).

	A Chunky panel like the notifications' question (`UI/NotifyPrompt`),
	every word in Fredoka One.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)

local Chunky = require(script.Parent.Chunky)

local PartyAsk = {}

local WIDTH = 380
local MARGIN = 12

local gui: ScreenGui? = nil
--[[ The sender of the invite on screen, and a count that tells an old
     prompt's timer it has been replaced. ]]
local current: number? = nil
local shownCount = 0

function PartyAsk.close()
	current = nil
	shownCount += 1
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

local function answer(from: number, accept: boolean)
	if current ~= from then
		return
	end
	PartyAsk.close()
	Remotes.event(Remotes.PartyAnswer):FireServer(from, accept)
end

--[[ Shows `from`'s invite for `seconds`. A new one replaces any on screen
     (the server allows one in at a time). ]]
function PartyAsk.show(from: number, seconds: number, view: Vector2?)
	local screen = gui
	if not screen then
		return
	end
	PartyAsk.close()
	current = from
	local mine = shownCount
	local sender = Players:GetPlayerByUserId(from)
	local name = if sender then sender.DisplayName:upper() else "SOMEONE"

	local camera = Workspace.CurrentCamera
	-- `view`: Studio's look at a phone's size
	local fitTo = view or if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local w = WIDTH * 2
	local pad = 40
	local header = 104
	local lineTop, lineH = header + 28, 116
	local hintTop, hintH = lineTop + lineH + 6, 44
	local barTop, barH = hintTop + hintH + 22, 30
	local buttonTop, buttonH = barTop + barH + 30, 112
	local h = buttonTop + buttonH + 34 + 12
	local fit = RunHudRules.fit(fitTo, WIDTH, h / 2, MARGIN)

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
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
	Chunky.ribbon(sheet, "PARTY INVITE", 0, 0, w, header)

	local line = Chunky.text(box, `{name} WANTS YOU IN THEIR PARTY!`, Chunky.ink, 0)
	line.Name = "Line"
	line.Position = UDim2.fromScale(pad / w, lineTop / h)
	line.Size = UDim2.fromScale(1 - 2 * pad / w, lineH / h)
	line.TextWrapped = true
	line.ZIndex = 8
	local hint = Chunky.text(box, "YOU GO ON THEIR RUNS TOGETHER", Chunky.inkSoft, 0)
	hint.Name = "Hint"
	hint.Position = UDim2.fromScale(pad / w, hintTop / h)
	hint.Size = UDim2.fromScale(1 - 2 * pad / w, hintH / h)
	hint.ZIndex = 8

	local bar = Chunky.bar(sheet, 1, Chunky.lime, pad + 30, barTop, w - 2 * pad - 60, barH)
	bar.Name = "Time"
	local fill = bar:FindFirstChildWhichIsA("Frame")

	local half = (w - 2 * pad - 24) / 2
	Chunky.button(sheet, "ACCEPT", Chunky.green, pad, buttonTop, half, buttonH, function()
		answer(from, true)
	end).Name =
		"Accept"
	Chunky.button(
		sheet,
		"DECLINE",
		Chunky.grey,
		pad + half + 24,
		buttonTop,
		half,
		buttonH,
		function()
			answer(from, false)
		end
	).Name =
		"Decline"
	screen.Enabled = true
	Chunky.pop(box)

	local endsAt = os.clock() + seconds
	task.spawn(function()
		while shownCount == mine do
			local left = endsAt - os.clock()
			if left <= 0 then
				-- the server lets it lapse too (`PartyRules.tidy`)
				PartyAsk.close()
				return
			end
			if fill then
				fill.Size = UDim2.fromScale(math.clamp(left / seconds, 0.03, 1), 1)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

function PartyAsk.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("PartyAsk")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "PartyAsk"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the party panel and the notifications' question, under a
	-- prize's reveal (150)
	screen.DisplayOrder = 145
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen
	Remotes.event(Remotes.PartyAsked).OnClientEvent
		:Connect(function(from: unknown, seconds: unknown)
			if type(from) ~= "number" or type(seconds) ~= "number" then
				return
			end
			if seconds > 0 then
				PartyAsk.show(from, seconds)
			elseif current == from then
				PartyAsk.close()
			end
		end)
end

return PartyAsk
