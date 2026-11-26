--!strict
--[[
	The enemies' and bosses' sounds (`Config/EnemySounds` says which, by
	model name; `Config/Sounds` holds them), played from what this client
	already sees of each body:

	- the clip it is playing (`ModelClip`, set by the server: a boss's
	  beats, an enemy's wind-up, a Lurker's Emerge);
	- the blows that show no wind-up (`AttackAt`, a melee bite or bash);
	- a volley leaving (`ShotAt`, the Burr Thistle's spit);
	- arriving and diving (`Targetable`: a Thornling landing, a Lurker
	  going under);
	- a fallen body playing Death (a Sow's Boarlets bursting out);
	- and, for the bosses that play no clips (the Old Tollcrab, Grandmother
	  Gulp), the telegraphs their moves show (`onTelegraph`), while that
	  boss is in the room.

	The Web Walker's spin sound is two seconds long and repeats for as long
	as the web turns. Presentation only.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.EnemySounds)
local SoundFx = require(script.Parent.SoundFx)

local EnemySounds = {}

--[[ The spin loop: seconds between its plays, and the clip it lasts for. ]]
local SPIN_SOUND, SPIN_CLIP, SPIN_EVERY = "boss_brood_web_spin", "WebSpin_Hold", 2

local watched: { [Model]: boolean } = {}
--[[ How many bodies of each name are being watched: whether a boss is in
     the room, for the telegraphs only its moves sound on. ]]
local present: { [string]: number } = {}

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = true
	local name = model.Name
	present[name] = (present[name] or 0) + 1
	local clips = Config.clips[name]
	if clips then
		model:GetAttributeChangedSignal("ModelClip"):Connect(function()
			local clip = model:GetAttribute("ModelClip")
			local sound = if type(clip) == "string" then clips[clip] else nil
			if not sound then
				return
			end
			SoundFx.play(sound)
			if sound == SPIN_SOUND then
				task.spawn(function()
					while true do
						task.wait(SPIN_EVERY)
						if not model.Parent or model:GetAttribute("ModelClip") ~= SPIN_CLIP then
							return
						end
						SoundFx.play(sound)
					end
				end)
			end
		end)
		-- a fallen body is made already playing its clip
		local clip = model:GetAttribute("ModelClip")
		local sound = if type(clip) == "string" then clips[clip] else nil
		if sound then
			SoundFx.play(sound)
		end
	end
	local attack = Config.attacks[name]
	if attack then
		model:GetAttributeChangedSignal("AttackAt"):Connect(function()
			SoundFx.play(attack)
		end)
	end
	local shot = Config.shots[name]
	if shot then
		model:GetAttributeChangedSignal("ShotAt"):Connect(function()
			SoundFx.play(shot)
		end)
	end
	if Config.arrive[name] or Config.dive[name] then
		model:GetAttributeChangedSignal("Targetable"):Connect(function()
			local sound = if model:GetAttribute("Targetable") == true
				then Config.arrive[name]
				else Config.dive[name]
			if sound then
				SoundFx.play(sound)
			end
		end)
	end
	model.AncestryChanged:Connect(function()
		if not model.Parent and watched[model] then
			watched[model] = nil
			present[name] = math.max(0, (present[name] or 1) - 1)
		end
	end)
end

--[[ `Remotes.EnemyTelegraph`'s arguments (`TelegraphRenderer.onTelegraph`
     draws the same): a boss move's telegraph plays its sound, a dash's
     once its lane's warning is out. ]]
function EnemySounds.onTelegraph(
	_origin: Vector3,
	_direction: Vector3,
	duration: number,
	kind: string,
	a: number?
)
	local tell = Config.tells[kind]
	if not tell or (present[tell.boss] or 0) == 0 then
		return
	end
	local delay = Config.tellDelay(tell, duration, a)
	if delay > 0 then
		task.delay(delay, SoundFx.play, tell.sound)
	else
		SoundFx.play(tell.sound)
	end
end

function EnemySounds.start(root: Instance)
	--[[ Every body that plays clips is tagged; a melee enemy may not be,
	     so the enemies folder is followed too. ]]
	for _, model in CollectionService:GetTagged("ModelClips") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("ModelClips"):Connect(watch)
	local function follow(folder: Instance)
		if folder.Name ~= "Enemies" then
			return
		end
		for _, child in folder:GetChildren() do
			watch(child)
		end
		folder.ChildAdded:Connect(watch)
	end
	for _, child in root:GetChildren() do
		follow(child)
	end
	root.ChildAdded:Connect(follow)
end

return EnemySounds
