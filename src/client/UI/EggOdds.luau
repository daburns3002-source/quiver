--!strict
--[[
	An egg's odds, opened before a purchase that gives eggs: ODDS on the
	Starter Pack's STORE tile (`UI/RobuxStore`) and on its after-win offer
	(`UI/RobuxOffer`). Roblox's paid random items policy asks for every
	outcome and its chance before a random item is bought with Robux
	(owner, 2026-11-19: "Yes to all three"), and the Starter Pack sells
	Mossy Eggs.

	One row a pet: its picture (a Mythic not owned yet stays a silhouette,
	as in the hatchery), its name, its rarity and its chance
	(`Util/OddsText`), with the luck running now in the numbers, as the
	hatchery's are (`Util/LiveState`), then the line that they are rounded
	and CLOSE. Chunky panel, every word in Fredoka One.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local LiveState = require(ReplicatedStorage.Shared.Util.LiveState)
local OddsText = require(ReplicatedStorage.Shared.Util.OddsText)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)

local Chunky = require(script.Parent.Chunky)
local Kit = require(script.Parent.Kit)

local EggOdds = {}

local WIDTH = 400
local MARGIN = 12

local gui: ScreenGui? = nil

local function layer(): ScreenGui?
	local existing = gui
	if existing and existing.Parent then
		return existing
	end
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "EggOdds"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the STORE (120) and the offers (140), under a prize's reveal (180)
	screen.DisplayOrder = 170
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen
	return screen
end

function EggOdds.close()
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

function EggOdds.isOpen(): boolean
	local screen = gui
	return screen ~= nil and screen.Enabled
end

--[[ Shows `eggKey`'s pets and their chances. `pets` is the player's own
     (to show a Mythic they hold); nil keeps every Mythic a silhouette. ]]
function EggOdds.open(eggKey: string, pets: { [string]: number }?)
	local screen = layer()
	if not screen then
		return
	end
	screen:ClearAllChildren()
	local pool = EggRules.pool(eggKey, LiveState.luck())
	local name = eggKey
	for _, egg in Eggs.list do
		if egg.key == eggKey then
			name = egg.name
		end
	end

	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local w = WIDTH * 2
	local pad = 40
	local header = 104
	local rowsTop = header + 24
	local rowH = 64
	local roundedTop = rowsTop + math.max(#pool, 1) * rowH + 14
	local roundedH = 70
	local closeTop = roundedTop + roundedH + 16
	local closeH = 92
	local h = closeTop + closeH + 30 + 12
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
	shade.Activated:Connect(EggOdds.close)

	local box = Instance.new("Frame")
	box.Name = "Odds"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, `{name} ODDS`, 0, 0, w, header)

	local function put(item: GuiObject, x: number, y: number, iw: number, ih: number)
		item.Position = UDim2.fromScale(x / w, y / h)
		item.Size = UDim2.fromScale(iw / w, ih / h)
		item.ZIndex = 6
	end
	for i, entry in pool do
		local y = rowsTop + (i - 1) * rowH
		local picture = Kit.image(box, ItemIcons.pet(entry.pet))
		put(picture, pad, y + 4, rowH - 8, rowH - 8)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = picture
		local held = pets ~= nil and (pets[entry.pet] or 0) > 0
		if entry.rarity == "Mythic" and not held then
			picture.ImageColor3 = Color3.new(0, 0, 0)
		end
		local petName = Chunky.text(box, string.upper(entry.name), Chunky.ink, 0)
		put(petName, pad + rowH + 8, y + 10, 330, rowH - 20)
		petName.TextXAlignment = Enum.TextXAlignment.Left
		local rarity = Chunky.text(
			box,
			string.upper(entry.rarity),
			Chunky.rarity[entry.rarity] or Chunky.ink,
			3
		)
		put(rarity, pad + rowH + 346, y + 12, 150, rowH - 24)
		rarity.TextXAlignment = Enum.TextXAlignment.Left
		local chance = Chunky.text(box, OddsText.percent(entry.chance), Chunky.ink, 0)
		put(chance, w - pad - 160, y + 10, 160, rowH - 20)
		chance.TextXAlignment = Enum.TextXAlignment.Right
	end
	local rounded = Chunky.text(box, OddsText.ROUNDED, Chunky.inkSoft, 0)
	put(rounded, pad, roundedTop, w - 2 * pad, roundedH)
	rounded.TextWrapped = true

	Chunky.button(
		sheet,
		"CLOSE",
		Chunky.grey,
		pad + 60,
		closeTop,
		w - 2 * pad - 120,
		closeH,
		EggOdds.close
	)
	screen.Enabled = true
	Chunky.pop(box)
end

return EggOdds
