--!strict
--[[
	The two Robux offers that come to the player instead of waiting in the
	STORE (`Config/RobuxStore`):

	- **REVIVE?** over the DEFEAT screen (`revive`), when the server says the
	  run can take one (`RunSummary.revive`): "buy" for 15 Robux, "use" for
	  one already held. REVIVE sends `Remotes.StoreBuy`; the server prompts,
	  grants and puts the player back into the room (`Server/Data/Purchases`),
	  and the room's fight starting clears DEFEAT and this with it. NO THANKS
	  leaves DEFEAT as it was. Robux only, never gems (owner).
	- **STARTER PACK** once, as the player leaves the Victory of their first
	  1-1 clear (`RunSummary.starter`; `owe`, then `after` runs what leaving
	  was going to do once the offer is answered). Bought, its eggs are shown
	  as a prize and the button says CONTINUE.

	Chunky panels (`UI/Chunky`), every word in Fredoka One, the numbers beside
	the one coin and one diamond.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)

local Chunky = require(script.Parent.Chunky)
local Kit = require(script.Parent.Kit)
local RobuxStore = require(script.Parent.RobuxStore)

local RobuxOffer = {}

local WIDTH = 400
local MARGIN = 12

local gui: ScreenGui? = nil
--[[ The offer up now, if any, and how to answer it from outside. ]]
local current: string? = nil
local primary: Frame? = nil
local onGrant: ((key: string) -> ())? = nil
--[[ The revive's watch on Roblox's prompt, while its offer is up. ]]
local promptWatch: RBXScriptConnection? = nil
local starterOwed = false

local function close()
	current = nil
	primary = nil
	onGrant = nil
	if promptWatch then
		promptWatch:Disconnect()
		promptWatch = nil
	end
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

type Button = { words: string, colour: Color3, action: () -> () }

--[[ The panel: a title, a picture, what it gives, a line, then the main
     button and NO THANKS under it. Returns the main button. ]]
local function show(
	name: string,
	title: string,
	icon: string,
	chips: { RobuxStore.Chip },
	line: string,
	main: Button,
	other: Button
): Frame?
	local screen = gui
	if not screen then
		return nil
	end
	-- whatever was up before is answered by this one
	close()
	current = name
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local w = WIDTH * 2
	local pad = 40
	local header = 104
	local iconTop, iconH = header + 26, 210
	local chipsTop = iconTop + iconH + 14
	local chipsH = if #chips > 0 then 70 else 0
	local lineTop = chipsTop + chipsH + 8
	local lineH = 84
	local mainTop = lineTop + lineH + 20
	local buttonH = 116
	local otherTop = mainTop + buttonH + 18
	local otherH = 92
	local h = otherTop + otherH + 30 + 12
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
	box.Name = name
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, title, 0, 0, w, header)

	local picture = Kit.image(box, icon)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.fromScale(0.5, iconTop / h)
	picture.Size = UDim2.fromScale(0.5, iconH / h)
	picture.ZIndex = 6
	if #chips > 0 then
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromScale(pad / w, chipsTop / h)
		strip.Size = UDim2.fromScale(1 - 2 * pad / w, chipsH / h)
		strip.ZIndex = 6
		strip.Parent = box
		RobuxStore.chipRow(strip, chips, 6)
	end
	local words = Chunky.text(box, line, Chunky.ink, 0)
	words.Position = UDim2.fromScale(pad / w, lineTop / h)
	words.Size = UDim2.fromScale(1 - 2 * pad / w, lineH / h)
	words.TextWrapped = true
	words.ZIndex = 6

	local button = Chunky.button(
		sheet,
		main.words,
		main.colour,
		pad,
		mainTop,
		w - 2 * pad,
		buttonH,
		main.action
	)
	Chunky.button(
		sheet,
		other.words,
		other.colour,
		pad + 60,
		otherTop,
		w - 2 * pad - 120,
		otherH,
		other.action
	)
	primary = button
	screen.Enabled = true
	Chunky.pop(box)
	return button
end

--[[ DEFEAT's offer: `offer` is the summary's "buy" or "use". ]]
function RobuxOffer.revive(offer: unknown)
	if offer ~= "buy" and offer ~= "use" then
		return
	end
	local product = StoreRules.product("Revive")
	if not product then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	-- DEFEAT already gone (the run moved on before this came up)
	if not playerGui or not playerGui:FindFirstChild("EndScreen") then
		return
	end
	local words = if offer == "use"
		then "REVIVE (OWNED)"
		else `REVIVE  {RobuxStore.price(product.robux)}`
	local waiting = false
	show(
		"Revive",
		"REVIVE?",
		RobuxStore.art(product),
		{},
		"Back into the fight where you fell. Your cards stay.",
		{
			words = words,
			colour = Chunky.green,
			action = function()
				if waiting then
					return
				end
				waiting = true
				local button = primary
				if button then
					Chunky.repaint(button, Chunky.grey, "...")
				end
				Remotes.event(Remotes.StoreBuy):FireServer("Revive", "Defeat")
				--[[ "use" asks no prompt; if nothing happens the server said no
			     (the run moved on), so the button comes back. ]]
				if offer == "use" then
					task.delay(6, function()
						if current == "Revive" and primary == button and button then
							waiting = false
							Chunky.repaint(button, Chunky.green, words)
						end
					end)
				end
			end,
		},
		{
			words = "NO THANKS",
			colour = Chunky.grey,
			action = close,
		}
	)
	-- Roblox's prompt turned down: the button is pressable again
	local button = primary
	promptWatch = MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(_userId: number, productId: number, purchased: boolean)
			if productId == product.id and not purchased and button and primary == button then
				waiting = false
				Chunky.repaint(button, Chunky.green, words)
			end
		end
	)
end

--[[ The summary says whether this win is when the starter pack is offered. ]]
function RobuxOffer.owe(starter: unknown)
	starterOwed = starter == true
end

--[[ Leaving Victory: the starter pack's one offer first if it is owed,
     then `proceed`. ]]
function RobuxOffer.after(proceed: () -> ())
	local product = StoreRules.product("StarterPack")
	if not starterOwed or not product then
		proceed()
		return
	end
	starterOwed = false
	local bought = false
	local function leave()
		close()
		proceed()
	end
	show(
		"Starter",
		"STARTER PACK",
		RobuxStore.art(product),
		RobuxStore.chips(product),
		"Only once per player. A strong start for your next areas.",
		{
			words = `BUY  {RobuxStore.price(product.robux)}`,
			colour = Chunky.green,
			action = function()
				if bought then
					leave()
				else
					Remotes.event(Remotes.StoreBuy):FireServer(product.key, "Starter")
				end
			end,
		},
		{
			words = "NO THANKS",
			colour = Chunky.grey,
			action = leave,
		}
	)
	onGrant = function(key: string)
		if key == product.key then
			bought = true
			local button = primary
			if button then
				Chunky.repaint(button, Chunky.blue, "CONTINUE")
			end
		end
	end
end

function RobuxOffer.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("RobuxOffer")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "RobuxOffer"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over DEFEAT and Victory (130), under a prize's reveal (150)
	screen.DisplayOrder = 140
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen
	Remotes.event(Remotes.StoreGranted).OnClientEvent:Connect(function(key: unknown)
		local answer = onGrant
		if answer and type(key) == "string" then
			answer(key)
		end
	end)
end

--[[ The run moved on (a revive's room is fighting, or the lobby): the
     revive's offer is over. The starter offer answers for itself. ]]
function RobuxOffer.onRunStateChanged(state: string)
	if current == "Revive" and (state == "Fighting" or state == "Lobby") then
		close()
	end
end

return RobuxOffer
