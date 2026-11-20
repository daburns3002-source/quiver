--!strict
--[[
	The reward pick panel (`Util/RewardPickRules`; owner, 2026-11-19: "make
	sure that the player has a choice BETWEEN THE MYTHICS AND LEGENDARIES FOR
	ALL CLASSES for the endless rewards and the battlepass"). Endless room
	100 and the season pass's premium tier 30 each owe a pick of a themed
	set: this shows that set's four weapons side by side, one for each class
	with the class under it, and TAKE IT asks the server for the one chosen
	(`Remotes.RewardPick`, `Wallet.pickReward`). The weapon then stands
	alone on a NEW WEAPON! card.

	Shows only, and asks. What is owed is the server's (the profile's
	`rewardPicks`); it comes up whenever one is owed and the player stands
	in the lobby, never over a fight, and after the tournament's panel if
	that is up. Closing it puts it off until the next return to the lobby.
	The weapons' own 2D pictures (`Util/ItemIcons`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardPickRules = require(ReplicatedStorage.Shared.Util.RewardPickRules)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local Chunky = require(script.Parent.Chunky)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local RewardPick = {}

--[[ The panel, in points: this wide at most, `MARGIN` clear of the
     screen's edges. ]]
local WIDTH = 560
local MARGIN = 12

local gui: ScreenGui? = nil
local profile: SaveSchema.Profile? = nil
--[[ The pick on screen, the weapon asked for on it, and whether its NEW
     WEAPON! card is up. ]]
local current: string? = nil
local asked: string? = nil
local taken = false
--[[ Picks closed with the X, put off until the next return to the lobby. ]]
local later: { [string]: boolean } = {}
--[[ The tournament's prize panel, which goes first. ]]
local tournament: ScreenGui? = nil

local show: () -> ()

local function clear()
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

local function close()
	current = nil
	asked = nil
	taken = false
	clear()
	task.defer(show)
end

--[[ Standing in the lobby, off the title and the story. ]]
local function inLobby(): boolean
	return Workspace:GetAttribute("InLobby") == true
		and Players.LocalPlayer:GetAttribute("Arrived") == true
end

--[[ The dark behind the panel, and its box, `w` by `h` points before
     fitting, with its sheet. ]]
local function frame(screen: ScreenGui, w: number, h: number): (Frame, Chunky.Sheet)
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = RunHudRules.fit(view, w, h, MARGIN)
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Pick"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(w * fit, h * fit)
	box.Parent = screen
	return box, Chunky.pointSheet(box, w, h)
end

--[[ A line of words across the sheet at `top`, `tall` sheet pixels. ]]
local function line(
	sheet: Chunky.Sheet,
	words: string,
	colour: Color3,
	top: number,
	tall: number
): TextLabel
	local pad = 44
	local text = Chunky.text(sheet.canvas, words, colour, 0)
	text.Position = UDim2.fromScale(pad / sheet.w, top / sheet.h)
	text.Size = UDim2.fromScale(1 - 2 * pad / sheet.w, tall / sheet.h)
	return text
end

--[[ A weapon's rarity tile in a slot at `x`, `y`, `size` sheet pixels
     square. ]]
local function slotAt(sheet: Chunky.Sheet, name: string, x: number, y: number, size: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = name
	slot.BackgroundTransparency = 1
	slot.ZIndex = 7
	Chunky.put(sheet, slot, x, y, size, size)
	return slot
end

--[[ The weapon just taken, alone: its tile, name and rarity. ]]
local function showTaken(screen: ScreenGui, weapon: string)
	local entry = ShopRules.find(weapon)
	local w = WIDTH * 2
	local pad = 40
	local header = 104
	local size = 360
	local tileTop = header + 30
	local nameTop = tileTop + size + 20
	local rarityTop = nameTop + 62
	local buttonTop = rarityTop + 60
	local h = buttonTop + 110 + 36 + 12

	local box, sheet = frame(screen, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "NEW WEAPON!", 0, 0, w, header)
	local rarity = if entry then entry.rarity else "Legendary"
	local slot = slotAt(sheet, weapon, (w - size) / 2, tileTop, size)
	Chunky.twinkle(Chunky.tile(slot, rarity, ItemIcons.weapon(weapon), "NEW!"))
	line(sheet, if entry then entry.label else weapon, Chunky.ink, nameTop, 56)
	local class = if entry then ` FOR THE {string.upper(entry.class)}` else ""
	line(sheet, `{string.upper(rarity)}{class}`, Chunky.inkSoft, rarityTop, 44)
	Chunky.button(sheet, "COLLECT", Chunky.green, pad, buttonTop, w - 2 * pad, 110, close)
	Chunky.pop(box)
	SoundFx.play("new_item")
end

--[[ Pick `id`'s set: four tiles, one a class, and TAKE IT. ]]
local function showPick(screen: ScreenGui, id: string, setKey: string)
	local mine = profile
	if not mine then
		return
	end
	local set = ShopRules.set(setKey)
	local options = RewardPickRules.options(setKey)
	local w = WIDTH * 2
	local pad = 40
	local gap = 24
	local header = 104
	local fromTop = header + 20
	local setTop = fromTop + 58
	-- clear of the words above: the tiles' glow reaches past their edge
	local tilesTop = setTop + 76
	local size = (w - 2 * pad - 3 * gap) / 4
	local classTop = tilesTop + size + 8
	local nameTop = classTop + 54
	local buttonTop = nameTop + 60
	local h = buttonTop + 110 + 36 + 12

	local box, sheet = frame(screen, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "PICK YOUR WEAPON", 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, function()
		later[id] = true
		close()
	end)
	line(sheet, `{RewardPickRules.from(id)} REWARD`, Chunky.ink, fromTop, 50)
	line(
		sheet,
		`{if set then set.name else setKey}: ONE WEAPON, ANY CLASS`,
		Chunky.inkSoft,
		setTop,
		42
	)
	local chosenName = line(sheet, "TAP A WEAPON", Chunky.inkSoft, nameTop, 48)

	local chosen: string? = nil
	local ring: Frame? = nil
	local take: Frame? = nil
	-- the row centred when a class is short (a set still being built)
	local left = (w - #options * size - (#options - 1) * gap) / 2
	for n, entry in options do
		local x = left + (n - 1) * (size + gap)
		local slot = slotAt(sheet, entry.weapon, x, tilesTop, size)
		local owned = mine.weapons[entry.weapon] == true
		local open = RewardPickRules.canTake(entry.weapon, mine.weapons)
		local caption = if not owned then nil elseif open then "+1 COPY" else "OWNED"
		local made = Chunky.tile(
			slot,
			entry.rarity,
			ItemIcons.weapon(entry.weapon),
			caption,
			false,
			not open
		)
		local class = Chunky.text(sheet.canvas, string.upper(entry.class), Chunky.ink, 0)
		Chunky.put(sheet, class, x, classTop, size, 40)
		if not open then
			continue
		end
		Chunky.twinkle(made)
		Chunky.press(slot, function()
			chosen = entry.weapon
			if ring then
				ring:Destroy()
			end
			ring = Chunky.select(slot)
			chosenName.Text = `{entry.label}, {string.upper(entry.rarity)}`
			local button = take
			if button then
				Chunky.repaint(button, Chunky.green, "TAKE IT")
			end
		end)
	end

	take = Chunky.button(
		sheet,
		"TAKE IT",
		Chunky.inkSoft,
		pad,
		buttonTop,
		w - 2 * pad,
		110,
		function()
			local weapon = chosen
			if weapon and not asked then
				asked = weapon
				Remotes.event(Remotes.RewardPick):FireServer(weapon)
				-- a refused ask changes nothing: TAKE IT works again
				task.delay(3, function()
					if current == id and not taken and asked == weapon then
						asked = nil
					end
				end)
			end
		end
	)
	Chunky.pop(box)
	SoundFx.play("new_item")
end

function show()
	local screen = gui
	local mine = profile
	if not screen or not mine or current or not inLobby() then
		return
	end
	if tournament and tournament.Enabled then
		return
	end
	local id, set = RewardPickRules.next(mine.rewardPicks, later)
	if not id or not set then
		return
	end
	current = id
	asked = nil
	showPick(screen, id, set)
	screen.Enabled = true
end

--[[ The profile came back: the pick on screen may have been taken. ]]
local function onProfile()
	local mine = profile
	local id = current
	local screen = gui
	if not mine or not id or not screen then
		show()
		return
	end
	if taken or mine.rewardPicks[id] ~= nil then
		return
	end
	-- taken (here, or by another of the player's screens): show what came
	local weapon = asked
	clear()
	if weapon and mine.weapons[weapon] then
		taken = true
		showTaken(screen, weapon)
		screen.Enabled = true
	else
		close()
	end
end

function RewardPick.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("RewardPick")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "RewardPick"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- as the tournament's and the Endless prize's panels: over the lobby's
	-- screens, under a reveal
	screen.DisplayOrder = 150
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local function watch(child: Instance)
		if child.Name == "TournamentPrize" and child:IsA("ScreenGui") then
			tournament = child
			child:GetPropertyChangedSignal("Enabled"):Connect(show)
		end
	end
	for _, child in playerGui:GetChildren() do
		watch(child)
	end
	playerGui.ChildAdded:Connect(watch)

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next_: unknown)
		if type(next_) == "table" then
			profile = next_ :: any
			onProfile()
		end
	end)
	-- back in the lobby: picks put off come up again; out of it (a run
	-- starting), the panel goes, the pick still owed
	local function arrived()
		if inLobby() then
			table.clear(later)
		elseif current then
			current = nil
			asked = nil
			taken = false
			clear()
		end
		show()
	end
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(arrived)
	Players.LocalPlayer:GetAttributeChangedSignal("Arrived"):Connect(arrived)
end

return RewardPick
