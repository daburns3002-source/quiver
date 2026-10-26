--!strict
--[[
	Loads every upgrade card image before the first hand is dealt (owner,
	2026-10-26: "I also want icons to preload as well, because those take a
	while to load after the upgrade cards pop up").

	Started as the story begins (`Main`), after the story's own frames have
	had the title to load in. Everything in `Config/CardAssets` is fetched,
	the player's class's cards first (its icons, the rarity bodies, banners
	and buttons a hand is made of), then every other icon, for a class
	switch or a Mythic's weapon.

	Roblox only decodes an image it is drawing, so on tiers with
	`warmCardImages` the class's images also sit in 2-pixel, nearly
	transparent labels on a screen of their own for the session (the story
	frames' trick, `UI/StoryCutscene`), and a hand draws them from memory on
	its first frame. The lowest tier only downloads them, to spare its video
	memory.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Device = require(script.Parent.Parent.Parent.Device)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("CardPreload")

local CardPreload = {}

local started = false
local warmGui: ScreenGui? = nil
local warmed: { [string]: boolean } = {}
local fetched: { [string]: boolean } = {}

--[[ Every image id in `CardAssets` but the icons, which go by class. ]]
local function frameImages(): { string }
	local out: { string } = {}
	local function walk(value: any)
		if type(value) == "string" then
			if string.find(value, "^rbxassetid://") then
				table.insert(out, value)
			end
		elseif type(value) == "table" and value ~= CardAssets.icons then
			for _, inner in value do
				walk(inner)
			end
		end
	end
	walk(CardAssets)
	return out
end

local function canDeal(ability: Abilities.Ability, class: string?): boolean
	local classes = ability.classes
	if not classes or not class then
		return true
	end
	return table.find(classes, class) ~= nil
end

--[[ The images a hand for `class` can show: the card frames, then the icon
     of every card the class can be dealt. With no class, every icon. ]]
function CardPreload.imagesFor(class: string?): { string }
	local out = frameImages()
	local seen: { [string]: boolean } = {}
	for _, id in out do
		seen[id] = true
	end
	for _, ability in Abilities.all do
		local id = CardAssets.icons[ability.icon]
		if id and not seen[id] and canDeal(ability, class) then
			seen[id] = true
			table.insert(out, id)
		end
	end
	return out
end

local function warm(ids: { string })
	if not Device.tier().warmCardImages then
		return
	end
	local gui = warmGui
	if not gui then
		local made = Instance.new("ScreenGui")
		made.Name = "CardWarm"
		made.ResetOnSpawn = false
		made.DisplayOrder = -100
		made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		warmGui = made
		gui = made
	end
	for _, id in ids do
		if warmed[id] then
			continue
		end
		warmed[id] = true
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(2, 2)
		image.ImageTransparency = 0.99
		image.Image = id
		image.Parent = gui
	end
end

local function fetch(ids: { string }): number
	local list: { string } = {}
	for _, id in ids do
		if not fetched[id] then
			fetched[id] = true
			table.insert(list, id)
		end
	end
	if #list > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end
	return #list
end

local function classOf(): string?
	local class = Players.LocalPlayer:GetAttribute("Class")
	return if type(class) == "string" then class else nil
end

function CardPreload.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	task.spawn(function()
		local began = os.clock()
		local mine = CardPreload.imagesFor(classOf() or "Ranger")
		warm(mine)
		local count = fetch(mine)
		log.info("%d card images for the class in %.2f s", count, os.clock() - began)
		local rest = fetch(CardPreload.imagesFor(nil))
		log.info("%d more card icons by %.2f s", rest, os.clock() - began)
	end)
	-- a new class (the C key, a weapon of another class) brings its own cards
	player:GetAttributeChangedSignal("Class"):Connect(function()
		local class = classOf()
		if class then
			warm(CardPreload.imagesFor(class))
		end
	end)
end

return CardPreload
