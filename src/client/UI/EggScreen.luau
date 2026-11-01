--!strict
--[[
	The Egg Hatchery, as Tap Simulator Reborn's egg stand (`UI/HatchStand`;
	owner, 2026-10-27; docs/EGG-HATCH-REFERENCE.md): HATCH 1 and HATCH 3,
	AUTO, the egg picker. The server rolls the eggs; this screen only
	previews the pool and shows its answer (`UI/Reveal`).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local StationScreen = require(script.Parent.StationScreen)
local EggScreen = {}
local screen: StationScreen.Screen? = nil
local selected = 1
function EggScreen.open()
	if screen then
		screen.open()
	end
end
function EggScreen.close()
	if screen and not Reveal.busy() then
		screen.close()
	end
end
function EggScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end
function EggScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("EggScreen", "EggHatchery", "HATCH EGGS")
	screen = s
	local dim = s.canvas.Parent :: GuiObject
	local layer = Instance.new("ScreenGui")
	layer.Name = "HatcheryBackground"
	layer.IgnoreGuiInset = true
	layer.ScreenInsets = Enum.ScreenInsets.None
	layer.ResetOnSpawn = false
	layer.DisplayOrder = s.gui.DisplayOrder - 1
	layer.Enabled = false
	layer.Parent = s.gui.Parent
	local backdrop = Kit.image(layer, GearAssets.backgrounds.hatchery)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ScaleType = Enum.ScaleType.Crop
	backdrop.ResampleMode = Enum.ResamplerMode.Default
	--[[ Codex's screens stand on an empty dark background: the area's
	     scene belongs inside the odds panel and nowhere else (owner,
	     2026-10-31, on the full-screen art). The layer stays, because it is
	     what covers Roblox's own top bar; what it carries goes dark. ]]
	local veil = Instance.new("Frame")
	veil.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 50
	veil.Parent = layer
	s.connect(dim:GetPropertyChangedSignal("Visible"), function()
		layer.Enabled = dim.Visible and GearAssets.backgrounds.hatchery ~= ""
	end)
	s.gui.Destroying:Once(function()
		layer:Destroy()
	end)
	-- whether a press of `count` can hatch the selected egg now
	local function affordable(count: number): boolean
		local p = s.profile
		local egg = Eggs.list[selected]
		return p ~= nil
			and EggRules.open(egg, p.bossesBeaten)
			and #EggRules.pool(egg.key) > 0
			and p.coins >= egg.price * count
	end
	local function press(count: number)
		if affordable(count) then
			local key = Eggs.list[selected].key
			Reveal.request(function()
				Remotes.event(Remotes.HatchEgg):FireServer(key, count)
			end)
		end
	end
	local control = HatchStand.controller(s, Eggs.counts, press, affordable, function()
		return true
	end)
	s.draw = function()
		local p = s.profile
		local egg = Eggs.list[selected]
		local pool = EggRules.pool(egg.key)
		local unlocked = EggRules.open(egg, if p then p.bossesBeaten else {})
		local tiles = {}
		for _, entry in pool do
			local owned = p ~= nil and (p.pets[entry.pet] or 0) > 0
			table.insert(tiles, {
				rarity = entry.rarity,
				icon = GearAssets.pets[entry.pet] or "",
				key = entry.pet,
				chance = entry.chance,
				owned = owned,
				-- the Mythic stays a shape until somebody pulls it
				silhouette = entry.rarity == "Mythic" and not owned,
			})
		end
		HatchStand.draw(s, {
			title = egg.name,
			price = egg.price,
			picker = egg.name,
			onPick = function()
				selected = selected % #Eggs.list + 1
				s.open()
			end,
			tiles = tiles,
			locked = if not unlocked
				then "BEAT KING BLOBLIN"
				elseif #pool == 0 then "COMING SOON"
				else nil,
			pity = if p then p.pity.eggs else 0,
			picture = GearAssets.eggs[egg.key].whole,
			backdrop = GearAssets.backgrounds.hatchery,
			counts = Eggs.counts,
			verb = "HATCH",
			noun = "PETS",
		}, control, press, affordable)
	end
	s.connect(Remotes.event(Remotes.EggHatched).OnClientEvent, function(key, results)
		if type(key) == "string" and type(results) == "table" then
			Reveal.eggs(key, results, if s.profile then s.profile.pets else nil)
		end
	end)
end
return EggScreen
