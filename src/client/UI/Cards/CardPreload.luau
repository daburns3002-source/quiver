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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Device = require(script.Parent.Parent.Parent.Device)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Preload = require(script.Parent.Parent.Parent.Preload)

local log = Log.forTag("CardPreload")

local CardPreload = {}

local WARM = "Cards"

local started = false

--[[ Every image id in `CardAssets` but the icons, which go by class. ]]
local function frameImages(): { string }
	return Preload.idsIn(CardAssets, CardAssets.icons)
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
	Preload.warm(WARM, ids)
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
		local count = Preload.fetch(mine)
		log.info("%d card images for the class in %.2f s", count, os.clock() - began)
		local rest = Preload.fetch(CardPreload.imagesFor(nil))
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
