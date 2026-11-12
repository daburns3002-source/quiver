--!strict
--[[
	The Soulstone shop's screen (`Config/SoulstoneShop`,
	`Util/SoulstoneShopRules`; owner, 2026-11-11: Soulstones buy eggs and
	crates). Opened from the Endless portal's screen (`UI/PortalScreen`).

	A chunky panel (`UI/Chunky`): the Soulstones held, on a pill, and a row
	for everything on offer with a button for each count a press may buy.
	A button the player cannot afford is grey and still says its price, so
	the shop also says what the next run is for.

	It decides nothing. A press sends `Remotes.SoulstoneBuy`; the server
	checks the offer, the count and the Soulstones, rolls what comes out and
	sends it back to `UI/EndlessPrize` to show. The balance here redraws when
	the profile does.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.SoulstoneShop)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local SoulstoneShopRules = require(ReplicatedStorage.Shared.Util.SoulstoneShopRules)

local Chunky = require(script.Parent.Chunky)

local SoulstoneShop = {}

--[[ The panel, in points: this wide at most and `MARGIN` clear of the
     screen's edges. ]]
local WIDTH = 520
local MARGIN = 12

local gui: ScreenGui? = nil
local profile: SaveSchema.Profile? = nil
local isOpen = false

--[[ A Soulstone: a purple gem cut as a diamond, drawn rather than
     uploaded. Fills `parent`, which should be square. ]]
local function gem(parent: GuiObject, z: number)
	for layer, share in { 0.7, 0.5 } do
		local facet = Instance.new("Frame")
		facet.Name = "Soulstone"
		facet.AnchorPoint = Vector2.new(0.5, 0.5)
		facet.BorderSizePixel = 0
		facet.BackgroundColor3 = if layer == 1
			then Chunky.shade(Chunky.purple)
			else Chunky.purple:Lerp(Color3.new(1, 1, 1), 0.25)
		facet.Position = UDim2.fromScale(0.5, 0.5)
		facet.Size = UDim2.fromScale(share, share)
		facet.Rotation = 45
		facet.ZIndex = z + layer
		facet.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.18, 0)
		corner.Parent = facet
	end
end

local function close()
	isOpen = false
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

local function draw(): Frame?
	local screen = gui
	if not screen then
		return nil
	end
	screen:ClearAllChildren()
	local p = profile
	local held = if p then p.soulstones else 0
	local class = Players.LocalPlayer:GetAttribute("Class")
	local offers = SoulstoneShopRules.offers(
		if p then p.bossesBeaten else {},
		if type(class) == "string" then class else nil
	)

	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- Laid out in sheet pixels, two to a point at full width.
	local w = WIDTH * 2
	local pad = 36
	local header = 104
	local pillTop = header + 22
	local rowsTop = pillTop + 92
	local rowH, rowGap = 132, 14
	local h = rowsTop + #offers * (rowH + rowGap) + 24 + 12
	local fit = math.min(1, (view.X - 2 * MARGIN) / WIDTH, (view.Y - 2 * MARGIN) / (h / 2))

	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Shop"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "SOULSTONE SHOP", 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, close)

	-- What is held: a gem on a cream pill.
	local pill = Instance.new("Frame")
	pill.Name = "Held"
	pill.BorderSizePixel = 0
	pill.BackgroundColor3 = Chunky.panelTop
	pill.ZIndex = 6
	Chunky.put(sheet, pill, pad, pillTop, 420, 72)
	Chunky.round(pill, 36)
	Chunky.outline(pill, 5)
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(72 / 420, 1)
	icon.ZIndex = 7
	icon.Parent = pill
	gem(icon, 7)
	local amount =
		Chunky.text(pill, Chunky.commas(held), Chunky.purple, 4, Chunky.shade(Chunky.purple))
	amount.Position, amount.Size = UDim2.fromScale(0.2, 0.12), UDim2.fromScale(0.74, 0.76)
	amount.TextXAlignment = Enum.TextXAlignment.Left
	local earn = Chunky.text(box, "EARNED IN ENDLESS", Chunky.ink, 0)
	earn.Position = UDim2.fromScale((pad + 440) / w, (pillTop + 14) / h)
	earn.Size = UDim2.fromScale(1 - (2 * pad + 440) / w, 44 / h)
	earn.TextXAlignment = Enum.TextXAlignment.Right

	for n, offer in offers do
		local y = rowsTop + (n - 1) * (rowH + rowGap)
		local card = Chunky.card(sheet, pad, y, w - 2 * pad, rowH)
		local name = Chunky.text(card, offer.name, Chunky.ink, 0)
		name.Position, name.Size = UDim2.fromScale(0.03, 0.2), UDim2.fromScale(0.36, 0.6)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local buttonW, buttonGap = 262, 14
		local right = w - pad - 20
		for i = #Config.counts, 1, -1 do
			local count = Config.counts[i]
			local cost = offer.price * count
			local x = right - buttonW
			right = x - buttonGap
			Chunky.button(
				sheet,
				`{count} FOR {Chunky.commas(cost)}`,
				if held >= cost then Chunky.purple else Chunky.grey,
				x,
				y + 22,
				buttonW,
				rowH - 44,
				function()
					Remotes.event(Remotes.SoulstoneBuy):FireServer(offer.kind, offer.key, count)
				end
			)
		end
	end
	screen.Enabled = true
	return box
end

--[[ Opens the shop over whatever screen asked for it. ]]
function SoulstoneShop.open()
	isOpen = true
	local box = draw()
	if box then
		Chunky.pop(box)
	end
end

function SoulstoneShop.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SoulstoneShop")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SoulstoneShop"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	--[[ Over the portal's screen it opens from, under the prize it sells
	     (`UI/EndlessPrize`, 150). ]]
	screen.DisplayOrder = 120
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next_)
		profile = next_
		if isOpen then
			draw()
		end
	end)
	--[[ A run starting shuts it: there is nothing to buy mid-fight. ]]
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(function()
		if Workspace:GetAttribute("InLobby") ~= true then
			close()
		end
	end)
end

return SoulstoneShop
