--!strict
--[[
	Victory's three chests (`Util/VictoryChestRules`; owner, 2026-11-14:
	"there should be more rewards for players"): over the Victory screen,
	once it has played, three shut chests of the level's area. The player
	opens one; the other two then show what they held.

	Under the chests it says the win streak and shows the level's three
	stars (`Util/StarRules`), the ones this win earned popping in.

	It only draws and asks. The server rolled the three as the level was
	won and has sent nothing about them (`Run/VictoryChests`): a tap sends
	which chest, 1 to 3 (`Remotes.VictoryChest`), and the answer says what
	was in each and what the picked one gave, already in the profile. An
	egg or a crate then opens with its own reveal (`UI/Reveal`).

	Mouse and touch tap a chest. Keys 1, 2 and 3 and a gamepad's X, Y and B
	pick the first, second and third, and A the middle one, so a player with
	no pointer is never left behind it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Chunky = require(script.Parent.Chunky)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StarRules = require(ReplicatedStorage.Shared.Util.StarRules)
local VictoryChestRules = require(ReplicatedStorage.Shared.Util.VictoryChestRules)

local VictoryChests = {}

local player = Players.LocalPlayer

--[[ Seconds a chest cannot be picked after they appear, so the tap that
     hurried Victory along is not also a pick; seconds the opened chests
     stay up; and seconds to wait for the server's answer before giving up. ]]
local HEADER = "PICK A CHEST!"
local GUARD = 0.5
local SHOWN = 2.2
local ANSWER = 6

type View = {
	gui: ScreenGui,
	cards: { Frame },
	line: TextLabel,
	area: string,
	shownAt: number,
	asked: boolean,
	answered: boolean,
	input: RBXScriptConnection?,
	--[[ The header's words, and what the picked chest gave, for the end
	     screen to add to what the run paid. ]]
	header: TextLabel?,
	given: VictoryChestRules.Prize?,
	done: ((VictoryChestRules.Prize?) -> ())?,
}

local view: View? = nil

--[[ True while the chests are up: Victory's buttons wait for it. ]]
function VictoryChests.busy(): boolean
	return view ~= nil
end

function VictoryChests.close()
	local v = view
	if not v then
		return
	end
	view = nil
	if v.input then
		v.input:Disconnect()
	end
	v.gui:Destroy()
	if v.done then
		v.done(v.given)
	end
end

local function pick(index: number)
	local v = view
	if not v or v.asked or os.clock() - v.shownAt < GUARD then
		return
	end
	v.asked = true
	v.line.Text = "OPENING..."
	Remotes.event(Remotes.VictoryChest):FireServer(index)
	-- no answer (the offer is gone): the screen is not held for it
	task.delay(ANSWER, function()
		if view == v and not v.answered then
			VictoryChests.close()
		end
	end)
end

--[[ A prize's picture, the big words under it, and how the line under the
     chests says it. ]]
local function look(prize: VictoryChestRules.Prize, area: string): (string, string, string)
	local amount = Chunky.commas(prize.amount)
	if prize.kind == "coins" then
		return ShopAssets.coin, "+" .. amount, `YOU GOT {amount} COINS!`
	elseif prize.kind == "gems" then
		return ShopAssets.gem, "+" .. amount, `YOU GOT {amount} GEMS!`
	elseif prize.kind == "egg" then
		local eggs = GearAssets.areaPictures.eggs
		return eggs[area] or eggs.MossyGlade, "EGG", "YOU GOT AN EGG!"
	end
	local chests = GearAssets.areaPictures.chests
	return chests[area] or chests.MossyGlade, "WEAPON CRATE", "YOU GOT A WEAPON CRATE!"
end

--[[ A card's picture with words under it. ]]
local function fill(card: Frame, asset: string, words: string?, faded: boolean)
	for _, child in card:GetChildren() do
		if child.Name == "Picture" or child.Name == "Words" then
			child:Destroy()
		end
	end
	local picture = Kit.image(card, asset)
	picture.Name = "Picture"
	picture.ZIndex = 30
	picture.ImageTransparency = if faded then 0.45 else 0
	picture.Position = UDim2.fromScale(0.16, if words then 0.07 else 0.16)
	picture.Size = UDim2.fromScale(0.68, 0.68)
	if words then
		local t = Chunky.text(card, words, Chunky.ink, 0)
		t.Name = "Words"
		t.TextTransparency = if faded then 0.4 else 0
		t.Position, t.Size = UDim2.fromScale(0.06, 0.76), UDim2.fromScale(0.88, 0.19)
	end
end

--[[ The server's answer: every chest shows what it held, the picked one
     lit and the others faded; then the screen goes, and an egg or a crate
     opens with its own reveal. ]]
local function answer(chosen: unknown, prizes: unknown, reveal: unknown)
	local v = view
	local index = VictoryChestRules.pick(chosen)
	if not v or v.answered or not index or type(prizes) ~= "table" then
		return
	end
	v.answered = true
	for at, card in v.cards do
		local prize = (prizes :: { any })[at]
		if
			type(prize) == "table"
			and type(prize.kind) == "string"
			and type(prize.amount) == "number"
		then
			local asset, words, said = look(prize, v.area)
			fill(card, asset, words, at ~= index)
			if at == index then
				v.given = { kind = prize.kind, amount = prize.amount }
				if v.header then
					v.header.Text = "CHEST OPENED!"
				end
				v.line.Text = said
				Chunky.outline(card, 9, Chunky.gold)
				Chunky.pop(card)
				Chunky.burst(card)
				Chunky.twinkle(card)
			else
				card.BackgroundColor3 = Chunky.pale
			end
		end
	end
	task.delay(SHOWN, function()
		if view ~= v then
			return
		end
		VictoryChests.close()
		if type(reveal) ~= "table" or type((reveal :: any).results) ~= "table" then
			return
		end
		local r = reveal :: any
		if r.kind == "Egg" and type(r.key) == "string" then
			Reveal.eggs(r.key, r.results)
		elseif r.kind == "Crate" and type(r.key) == "number" then
			Reveal.crates(r.key, r.results)
		end
	end)
end

--[[ What the server said of the level's stars (`Util/StarRules`): the
     bits it held before this win and holds now, and its time. ]]
export type Stars = { had: number, now: number, par: number }

--[[ Shows the three chests. `streak` is the win streak as it now stands,
     said under them, and `stars` the level's stars, shown under that;
     `done` is called when they have gone. ]]
function VictoryChests.open(
	streak: number?,
	stars: Stars?,
	done: ((VictoryChestRules.Prize?) -> ())?
)
	VictoryChests.close()
	local screen = Instance.new("ScreenGui")
	screen.Name = "VictoryChests"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over Victory (130), under the rewards' toast (140) and a reveal (180)
	screen.DisplayOrder = 135
	screen.Parent = player:WaitForChild("PlayerGui")

	-- the dimmer takes every tap meant for Victory's buttons under it
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 0
	dim.Parent = screen

	local sheet = Chunky.sheet(Kit.canvas(screen))
	local up = sheet.upright
	local px, py, pw, ph = 360, 250, 1200, 620
	local size, gap = 300, 50
	if up then
		px, py, pw, ph = 60, 560, 960, 760
		size, gap = 270, 30
	end
	-- room for the level's stars under the streak
	local starry = stars ~= nil
		and type(stars.now) == "number"
		and type(stars.had) == "number"
		and type(stars.par) == "number"
	if starry then
		py -= 45
		ph += 90
	end
	local panel = Chunky.panel(sheet, px, py, pw, ph)
	Chunky.ribbon(
		sheet,
		HEADER,
		if up then 170 else 630,
		py - (if up then 80 else 82),
		if up then 740 else 660,
		if up then 150 else 144
	)
	Chunky.pop(panel)

	local stage = CurrentStage.config()
	local area = if stage and stage.area then stage.area else "MossyGlade"
	local chests: { [string]: string } = EndScreenAssets.chests
	local shut = chests[area] or chests.MossyGlade
	local top = py + (if up then 130 else 100)
	local left = px
		+ (pw - VictoryChestRules.COUNT * size - (VictoryChestRules.COUNT - 1) * gap) / 2
	local cards: { Frame } = {}
	for index = 1, VictoryChestRules.COUNT do
		local card = Chunky.card(sheet, left + (index - 1) * (size + gap), top, size, size)
		card.Name = "Chest" .. index
		card.ZIndex = 10
		fill(card, shut, nil, false)
		Chunky.gleam(card, index * 0.3)
		Chunky.press(card, function()
			pick(index)
		end)
		table.insert(cards, card)
	end

	local line = Chunky.text(sheet.canvas, "TAP A CHEST TO OPEN IT", Chunky.ink, 0)
	line.Name = "Line"
	Chunky.put(sheet, line, px + 40, top + size + 30, pw - 80, 64)
	local share = RunBonus.streak(streak or 0)
	if streak and share > 0 then
		local said = Chunky.text(
			sheet.canvas,
			`WIN STREAK {streak}: NEXT LEVEL {RunBonus.percent(share)} COINS`,
			Chunky.inkSoft,
			0
		)
		said.Name = "Streak"
		Chunky.put(sheet, said, px + 40, top + size + 110, pw - 80, 46)
	end

	--[[ The level's three stars and what each asks: gold if the level
	     holds it, popping if this win earned it. ]]
	if stars and starry then
		local asks = StarRules.words(stars.par)
		local slot = (pw - 80) / #StarRules.ALL
		local sy = top + size + 176
		for at, bit in StarRules.ALL do
			local sx = px + 40 + (at - 1) * slot
			local lit = StarRules.has(stars.now, bit)
			local star = Kit.image(sheet.canvas, EndScreenAssets.star)
			star.Name = "Star" .. at
			star.ZIndex = 30
			Chunky.put(sheet, star, sx, sy, 54, 54)
			if not lit then
				star.ImageColor3 = Color3.new(0, 0, 0)
				star.ImageTransparency = 0.72
			elseif not StarRules.has(stars.had, bit) then
				Chunky.pop(star)
				Chunky.twinkle(star)
			end
			local ask =
				Chunky.text(sheet.canvas, asks[at], if lit then Chunky.ink else Chunky.inkSoft, 0)
			ask.Name = "Ask" .. at
			ask.TextXAlignment = Enum.TextXAlignment.Left
			Chunky.put(sheet, ask, sx + 64, sy + 9, slot - 74, 36)
		end
	end

	local v: View = {
		gui = screen,
		cards = cards,
		line = line,
		area = area,
		shownAt = os.clock(),
		asked = false,
		answered = false,
		input = nil,
		header = nil,
		given = nil,
		done = done,
	}
	for _, label in screen:GetDescendants() do
		if label:IsA("TextLabel") and label.Text == HEADER then
			v.header = label
			break
		end
	end
	view = v
	local keys: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.ButtonX] = 1,
		[Enum.KeyCode.ButtonY] = 2,
		[Enum.KeyCode.ButtonB] = 3,
		[Enum.KeyCode.ButtonA] = 2,
	}
	v.input = UserInputService.InputBegan:Connect(function(input: InputObject)
		local index = keys[input.KeyCode]
		if index then
			pick(index)
		end
	end)
end

function VictoryChests.start()
	Remotes.event(Remotes.VictoryChest).OnClientEvent:Connect(answer)
end

return VictoryChests
