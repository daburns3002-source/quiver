--!strict
--[[
	What an Endless milestone just gave (`Remotes.EndlessPrize`; owner,
	2026-11-11: "MAKE IT MORE LIKE 5 EGGS AND 5 CRATES ... I WANT IT TO FEEL
	NECESSARY TO BEAT THESE ROOMS"): a chunky panel (`UI/Chunky`) that pops
	in over the run with every pet and weapon on its rarity's tile, five to a
	row, the new ones marked, the rarest sparkling.

	Shows only. The server has already hatched the eggs and opened the
	crates and put everything in the profile (`Server/Data/EndlessPrizes`);
	closing this, or never seeing it, changes nothing. It closes on COLLECT,
	after `SHOW` seconds, or the moment the next floor's fight starts, so it
	never sits over a fight.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local Chunky = require(script.Parent.Chunky)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local EndlessPrize = {}

--[[ Seconds it stays up if nobody presses COLLECT. ]]
local SHOW = 14
--[[ The panel, in points: this wide at most, `MARGIN` clear of the
     screen's edges, five tiles to a row. ]]
local WIDTH = 520
local MARGIN = 12
local COLUMNS = 5

type Prize = { rarity: string, picture: string, new: boolean }

local gui: ScreenGui? = nil
--[[ Bumped on every show and close, so an old timer never shuts a newer
     panel. ]]
local showing = 0

local function close()
	showing += 1
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

--[[ The server's lists as tiles to draw. Anything that is not the shape
     the server sends is left out rather than trusted. ]]
local function prizes(pets: unknown, weapons: unknown): { Prize }
	local out: { Prize } = {}
	if type(pets) == "table" then
		for _, entry in pets :: { any } do
			local key = if type(entry) == "table" then entry.pet else nil
			if type(key) == "string" then
				table.insert(out, {
					rarity = EggRules.rarity(key),
					picture = (GearAssets.pets :: { [string]: string })[key] or "",
					new = entry.new == true,
				})
			end
		end
	end
	if type(weapons) == "table" then
		for _, entry in weapons :: { any } do
			local key = if type(entry) == "table" then entry.weapon else nil
			local found = if type(key) == "string" then ShopRules.find(key) else nil
			if found then
				table.insert(out, {
					rarity = found.rarity,
					picture = (ShopAssets.weapons :: { [string]: string })[found.weapon] or "",
					new = entry.new == true,
				})
			end
		end
	end
	return out
end

local function show(floor: number, name: string, list: { Prize })
	local screen = gui
	if not screen or #list == 0 then
		return
	end
	close()
	local mine = showing

	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)

	-- Laid out in sheet pixels, two to a point at full width.
	local w = WIDTH * 2
	local pad, gap = 40, 16
	local tile = (w - 2 * pad - (COLUMNS - 1) * gap) / COLUMNS
	local rows = math.ceil(#list / COLUMNS)
	local header = 104
	local nameTop = header + 20
	local gridTop = nameTop + 64
	local buttonTop = gridTop + rows * tile + (rows - 1) * gap + 28
	local h = buttonTop + 110 + 36 + 12
	local fit = RunHudRules.fit(view, WIDTH, h / 2, MARGIN)

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Prize"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	-- floor 0 is a Soulstone shop purchase, -1 a Robux product's eggs
	-- (`Remotes.EndlessPrize`)
	local title = if floor > 0
		then `FLOOR {floor} REWARD!`
		elseif floor < 0 then "THANK YOU!"
		else "SOULSTONE SHOP"
	Chunky.ribbon(sheet, title, 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, close)
	local line = Chunky.text(box, name, Chunky.ink, 0)
	line.Position = UDim2.fromScale(pad / w, nameTop / h)
	line.Size = UDim2.fromScale(1 - 2 * pad / w, 52 / h)

	for n, prize in list do
		local column = (n - 1) % COLUMNS
		local row = math.floor((n - 1) / COLUMNS)
		--[[ A last row that is not full is centred. ]]
		local inRow = math.min(COLUMNS, #list - row * COLUMNS)
		local left = (w - inRow * tile - (inRow - 1) * gap) / 2
		local slot = Instance.new("Frame")
		slot.Name = "Slot"
		slot.BackgroundTransparency = 1
		slot.ZIndex = 6
		Chunky.put(
			sheet,
			slot,
			left + column * (tile + gap),
			gridTop + row * (tile + gap),
			tile,
			tile
		)
		local made =
			Chunky.tile(slot, prize.rarity, prize.picture, if prize.new then "NEW!" else nil)
		if prize.rarity == "Legendary" or prize.rarity == "Mythic" then
			Chunky.twinkle(made)
		end
		-- each lands a beat after the one before it
		local grow = Instance.new("UIScale")
		grow.Scale = 0
		grow.Parent = slot
		task.delay(0.25 + n * 0.07, function()
			if showing == mine and grow.Parent then
				TweenService:Create(
					grow,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end)
	end

	Chunky.button(sheet, "COLLECT", Chunky.green, pad, buttonTop, w - 2 * pad, 110, close)

	screen.Enabled = true
	Chunky.pop(box)
	SoundFx.play("new_item")
	task.delay(SHOW, function()
		if showing == mine then
			close()
		end
	end)
end

--[[ The next floor's fight has started: out of its way. ]]
function EndlessPrize.onRunStateChanged(state: string)
	if state == "Fighting" or state == "Lobby" then
		close()
	end
end

function EndlessPrize.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("EndlessPrize")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "EndlessPrize"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	--[[ Over the checkpoint it usually arrives with (101), under a reveal
	     (180). ]]
	screen.DisplayOrder = 150
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	Remotes.event(Remotes.EndlessPrize).OnClientEvent
		:Connect(function(floor: unknown, name: unknown, pets: unknown, weapons: unknown)
			if type(floor) == "number" and type(name) == "string" then
				show(floor, name, prizes(pets, weapons))
			end
		end)
end

return EndlessPrize
