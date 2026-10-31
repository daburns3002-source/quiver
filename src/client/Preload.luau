--!strict
--[[
	One place for "fetch this content before it is needed".

	There were three unrelated preloaders before this (`Fx/RoomPreload`,
	`UI/Cards/CardPreload`, `UI/StoryCutscene`) and each had grown its own copy
	of the same three things: a set of ids already asked for, a `pcall` round
	`ContentProvider:PreloadAsync`, and the warm-label trick below. They are all
	here now, so a fix lands once.

	Two different jobs, which are easy to confuse:

	- **Fetching** (`fetch`, `await`) downloads and decodes an asset.
	  `ContentProvider:PreloadAsync` does this whether or not anything is
	  drawing it, and blocks until it is done — so it is always called off the
	  frame, and `await` is the one that may be waited on, because it carries a
	  deadline. There is no way to cancel it, so a slow network shows up as
	  `await` returning false, never as a hang.

	- **Warming** (`warm`, `cool`) keeps an asset in video memory. Roblox only
	  holds the decoded texture for an image something is *drawing*, so a
	  fetched image can still cost a hitch on first use. A warm image sits in a
	  2-pixel, 99%-transparent label on a screen of its own, which draws it
	  without showing it. That costs VRAM, so warm sets are bounded by the
	  caller (`Config/DeviceTiers`) and dropped with `cool` once past.

	Content only: nothing here decides what is drawn, and nothing gameplay
	reads it.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("Preload")

local Preload = {}

--[[ Every id `fetch` has already asked for, so a second caller wanting the
     same arena or the same card icon asks for nothing again. ]]
local fetched: { [string]: boolean } = {}

--[[ The warm sets by name, each its screen and the label holding each id. A
     set is one caller's business ("Story", "Cards"), so one can be cooled
     without disturbing another. ]]
type WarmSet = { gui: ScreenGui, labels: { [string]: ImageLabel } }
local warmSets: { [string]: WarmSet } = {}

--[[ Whether `value` is an asset id this module can fetch. Config modules hold
     plenty of other strings (names, words, colours' keys) and handing one to
     `PreloadAsync` is an error, not a no-op. ]]
local function isAssetId(value: any): boolean
	return type(value) == "string" and string.find(value, "^rbxassetid://") ~= nil
end

--[[ Every asset id inside `value`, walking tables, in no particular order.
     `skip` is a table not to descend into, for a caller that handles part of
     its config itself (`CardPreload` and its icons). ]]
function Preload.idsIn(value: any, skip: any?): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function walk(inner: any)
		if isAssetId(inner) then
			if not seen[inner] then
				seen[inner] = true
				table.insert(out, inner)
			end
		elseif type(inner) == "table" and inner ~= skip then
			for _, nested in inner :: { [any]: any } do
				walk(nested)
			end
		end
	end
	walk(value)
	return out
end

--[[ The ids of `list` not already asked for, marked as asked. Separate from
     `fetch` so a caller can count what is actually new before deciding to
     spend a frame on it. ]]
local function unfetched(list: { string }): { string }
	local out: { string } = {}
	for _, id in list do
		if isAssetId(id) and not fetched[id] then
			fetched[id] = true
			table.insert(out, id)
		end
	end
	return out
end

--[[ Downloads and decodes every id of `list` not already asked for. Blocks
     until Roblox is done, so this belongs in a spawned task or inside
     `await`; returns how many were new.

	 Instances may be passed too (an arena model, whose meshes and textures
	 Roblox walks for itself) by handing them straight to `fetchInstances`. ]]
function Preload.fetch(list: { string }): number
	local todo = unfetched(list)
	if #todo == 0 then
		return 0
	end
	local ok, problem = pcall(function()
		ContentProvider:PreloadAsync(todo)
	end)
	if not ok then
		log.warn("%d assets did not load: %s", #todo, tostring(problem))
	end
	return #todo
end

--[[ The same for instances, whose own content Roblox finds (an arena model's
     meshes and textures). Not deduplicated: an instance is asked for once by
     whoever parked it. ]]
function Preload.fetchInstances(list: { Instance })
	if #list == 0 then
		return
	end
	local ok, problem = pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	if not ok then
		log.warn("%d instances did not load: %s", #list, tostring(problem))
	end
end

--[[ Fetches `list` in a task of its own, and runs `done` with how many were
     new once it is in. For everything that must not hold up a frame. ]]
function Preload.fetchAsync(list: { string }, done: ((number) -> ())?)
	task.spawn(function()
		local count = Preload.fetch(list)
		if done then
			done(count)
		end
	end)
end

--[[ Fetches `list` and waits up to `seconds` for it. True when it is all in,
     false when the deadline passed first — the fetch carries on in the
     background either way, because `PreloadAsync` cannot be called off.

	 This is the only way anything here may be waited on: a caller that blocks
	 on a bare `fetch` blocks for as long as the network takes, which on a
	 phone is unbounded. ]]
function Preload.await(list: { string }, seconds: number): boolean
	local todo = unfetched(list)
	if #todo == 0 then
		return true
	end
	local finished = false
	task.spawn(function()
		local ok, problem = pcall(function()
			ContentProvider:PreloadAsync(todo)
		end)
		if not ok then
			log.warn("%d assets did not load: %s", #todo, tostring(problem))
		end
		finished = true
	end)
	local deadline = os.clock() + seconds
	while not finished and os.clock() < deadline do
		task.wait(0.05)
	end
	if not finished then
		log.info("%d assets still loading after %.1f s", #todo, seconds)
	end
	return finished
end

--[[ The screen a warm set's labels live on, made on first use. Its own
     ScreenGui, under everything, so cooling a set cannot take anything else
     with it. ]]
local function warmGui(name: string): WarmSet
	local set = warmSets[name]
	if set then
		return set
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = `Warm_{name}`
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local made: WarmSet = { gui = gui, labels = {} }
	warmSets[name] = made
	return made
end

--[[ Keeps every id of `list` drawn, out of sight, in the set called `name`.
     Already-warm ids are left alone, so this may be called every frame with a
     moving window. ]]
function Preload.warm(name: string, list: { string })
	if #list == 0 then
		return
	end
	local set = warmGui(name)
	for _, id in list do
		if not isAssetId(id) or set.labels[id] then
			continue
		end
		local image = Instance.new("ImageLabel")
		image.Name = "Warm"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Size = UDim2.fromOffset(2, 2)
		image.ImageTransparency = 0.99
		image.Image = id
		image.Parent = set.gui
		set.labels[id] = image
	end
end

--[[ Drops the warm labels for `list` from the set called `name`, freeing their
     video memory. The ids stay fetched, so warming one again is free of the
     network. ]]
function Preload.cool(name: string, list: { string })
	local set = warmSets[name]
	if not set then
		return
	end
	for _, id in list do
		local label = set.labels[id]
		if label then
			label:Destroy()
			set.labels[id] = nil
		end
	end
end

--[[ Drops a whole warm set and its screen. ]]
function Preload.coolAll(name: string)
	local set = warmSets[name]
	if not set then
		return
	end
	set.gui:Destroy()
	warmSets[name] = nil
end

return Preload
