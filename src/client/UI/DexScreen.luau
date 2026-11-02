--!strict
--[[
	The Dex Hall's three books (owner, 2026-10-25: Enemy, Weapon and Pet
	codexes, "a 2D book with a little page turn frame animation every time
	the page is turned", entries not yet found drawn as black silhouettes;
	2026-11-01: "start on the dex screens").

	Codex's spread is one finished picture, so this draws it whole and puts
	only the live furniture on it: the chosen entry down the left page, nine
	slots on the right, and the tabs and arrows round the outside. Where
	each panel sits is measured off the art (`Config/Dex`); what goes in
	them is `Util/DexBook`, which is three readings of configs the rest of
	the game already keeps.

	A locked entry is its own picture tinted black. That is the whole trick
	of a silhouette here -- the shape is the answer, so it has to be the
	real picture and not a stand-in.

	Everything is built inside `draw`, because `UI/StationScreen` empties
	the canvas before every redraw: anything made once in `start` would be
	destroyed the first time the screen opened.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local Kit = require(script.Parent.Kit)
local StationScreen = require(script.Parent.StationScreen)

local DexScreen = {}

--[[ Nine, and the same nine in all three books; `tests/DexBook.spec`
     holds the three grids to that. ]]
local PER_PAGE = Dex.books[Dex.order[1]].grid.columns * Dex.books[Dex.order[1]].grid.rows
local WHITE = Color3.new(1, 1, 1)

local screen: StationScreen.Screen? = nil
--[[ Which book is open, which page of it, and which entry is written out
     on the left. The page and the choice reset with the book, because
     entry 4 of the enemies has nothing to do with entry 4 of the pets. ]]
local book = Dex.order[1]
local page = 1
local chosen: string? = nil
--[[ True while the turn frames are running, so a second press cannot start
     another turn over the top of the first. ]]
local turning = false

function DexScreen.open()
	if screen then
		screen.open()
	end
end

function DexScreen.close()
	if screen then
		screen.close()
	end
end

function DexScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end

function DexScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("DexScreen", "DexHall", "READ THE DEXES")
	screen = s

	s.draw = function()
		--[[ Every box comes from the open book: the three spreads look
		     alike but are drawn differently, so one shared layout put the
		     enemy grid out of its frames. ]]
		local art = Dex.books[book]
		local all = DexBook.entries(book, s.profile)
		local pages = DexBook.pages(all, PER_PAGE)
		page = math.clamp(page, 1, pages)
		local shown = DexBook.page(all, page, PER_PAGE)
		local found, total = DexBook.found(all)

		--[[ The book, held to the art's own shape so every box below lands
		     where it was measured however the window is sized. It sits a
		     little low, leaving the top of the screen for the tabs. ]]
		local stage = Instance.new("Frame")
		stage.Name = "Book"
		stage.BackgroundTransparency = 1
		stage.AnchorPoint = Vector2.new(0.5, 0.5)
		stage.Position = UDim2.fromScale(0.5, 0.55)
		stage.Size = UDim2.fromScale(0.9, 0.82)
		stage.Parent = s.canvas
		local shape = Instance.new("UIAspectRatioConstraint")
		shape.AspectRatio = Dex.canvas.X / Dex.canvas.Y
		shape.Parent = stage

		local spread = Instance.new("ImageLabel")
		spread.Name = "Spread"
		spread.BackgroundTransparency = 1
		spread.Image = art.spread
		spread.Size = UDim2.fromScale(1, 1)
		spread.ZIndex = 1
		spread.Parent = stage

		local function place(item: GuiObject, box: Dex.Box)
			item.Position = UDim2.fromScale(box.x / Dex.canvas.X, box.y / Dex.canvas.Y)
			item.Size = UDim2.fromScale(box.w / Dex.canvas.X, box.h / Dex.canvas.Y)
		end

		local function pageText(
			name: string,
			box: Dex.Box,
			colour: Color3,
			biggest: number
		): TextLabel
			local label = Instance.new("TextLabel")
			label.Name = name
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Arcade
			label.TextColor3 = colour
			label.TextScaled = true
			label.TextWrapped = true
			label.ZIndex = 3
			label.Parent = stage
			place(label, box)
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = biggest
			limit.Parent = label
			return label
		end

		--[[ With nothing picked, the page writes out its first entry, so
		     the left page is never blank. ]]
		local pick: DexBook.Entry? = nil
		for _, entry in shown do
			if entry.key == chosen then
				pick = entry
			end
		end
		pick = pick or shown[1]

		if pick then
			local picture = Instance.new("ImageLabel")
			picture.Name = "Picture"
			picture.BackgroundTransparency = 1
			picture.ScaleType = Enum.ScaleType.Fit
			picture.Image = pick.picture
			picture.ImageColor3 = if pick.unlocked then WHITE else Dex.silhouette
			picture.ZIndex = 3
			picture.Parent = stage
			place(picture, art.picture)

			pageText("Name", art.plaque, Dex.nameText, 44).Text = if pick.unlocked
				then pick.name
				else Dex.unknownName
			local line = pageText("Line", art.description, Dex.descriptionText, 30)
			line.Text = if pick.unlocked then pick.description else Dex.unknownLine
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0.04, 0)
			pad.PaddingRight = UDim.new(0.04, 0)
			pad.PaddingTop = UDim.new(0.08, 0)
			pad.PaddingBottom = UDim.new(0.08, 0)
			pad.Parent = line
		end

		--[[ The right page's nine slots. A short last page leaves the rest
		     of its slots empty paper rather than padding them. ]]
		local slots: { ImageButton } = {}
		for index, entry in shown do
			local row = math.floor((index - 1) / art.grid.columns)
			local column = (index - 1) % art.grid.columns
			local slot = Instance.new("ImageButton")
			slot.Name = `Slot{index}`
			slot.BackgroundTransparency = 1
			slot.AutoButtonColor = false
			slot.ScaleType = Enum.ScaleType.Fit
			slot.Image = entry.icon
			slot.ImageColor3 = if entry.unlocked then WHITE else Dex.silhouette
			slot.ZIndex = 3
			slot.Parent = stage
			place(slot, {
				x = art.grid.x + column * art.grid.stepX,
				y = art.grid.y + row * art.grid.stepY,
				w = art.grid.w,
				h = art.grid.h,
			})
			--[[ Connected straight to the button, not through `s.connect`:
			     the slot is remade every draw, so the connection should go
			     with it rather than pile up for the screen's lifetime. ]]
			slot.Activated:Connect(function()
				if turning then
					return
				end
				chosen = entry.key
				s.draw()
			end)
			table.insert(slots, slot)
		end

		--[[ The tabs over the book. The open one sits bright, the other
		     two go back. ]]
		local tabs = Instance.new("Frame")
		tabs.Name = "Tabs"
		tabs.BackgroundTransparency = 1
		--[[ Left of centre: `StationScreen`'s own draw puts the coin and
		     gem pills in the top right, and centred tabs ran under them. ]]
		tabs.AnchorPoint = Vector2.new(0.5, 0)
		tabs.Position = UDim2.fromScale(0.4, 0.012)
		tabs.Size = UDim2.fromScale(0.42, 0.068)
		tabs.ZIndex = 6
		tabs.Parent = s.canvas
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.Padding = UDim.new(0.02, 0)
		row.Parent = tabs
		for _, name in Dex.order do
			local tab = Kit.nativeButton(tabs, Dex.books[name].title, Kit.colour("Rare"), function()
				if turning or book == name then
					return
				end
				book = name
				page = 1
				chosen = nil
				s.draw()
			end)
			tab.Size = UDim2.fromScale(0.31, 1)
			tab.BackgroundTransparency = if name == book then 0 else 0.5
		end

		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.Arcade
		count.Text = `FOUND {found}/{total}    PAGE {page}/{pages}`
		count.TextColor3 = Dex.countText
		count.TextScaled = true
		count.AnchorPoint = Vector2.new(0.5, 0)
		count.Position = UDim2.fromScale(0.4, 0.086)
		count.Size = UDim2.fromScale(0.34, 0.032)
		count.ZIndex = 6
		count.Parent = s.canvas

		--[[ A page turn: the new page is chosen first, then the six frames
		     play over the grid, then the book is redrawn on the new nine.
		     The slots go first so none shows through the paper. ]]
		local function turn(step: number)
			if turning then
				return
			end
			page += step
			chosen = nil
			turning = true
			for _, slot in slots do
				slot.Visible = false
			end
			task.spawn(function()
				for _, frame in art.turn do
					--[[ The screen may have closed, or another draw may
					     have replaced this book; either way its spread is
					     gone and there is nothing left to animate. ]]
					if spread.Parent == nil then
						break
					end
					spread.Image = frame
					task.wait(Dex.turnFrame)
				end
				turning = false
				s.draw()
			end)
		end

		local function arrow(x: number, words: string, step: number)
			local button = Kit.nativeButton(s.canvas, words, Kit.colour("Common"), function()
				turn(step)
			end)
			--[[ Under the right page, which is the one that turns. ]]
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Position = UDim2.fromScale(x, 0.985)
			button.Size = UDim2.fromScale(0.08, 0.052)
			button.ZIndex = 6
		end
		if page > 1 then
			arrow(0.60, "<", -1)
		end
		if page < pages then
			arrow(0.71, ">", 1)
		end
	end
end

return DexScreen
