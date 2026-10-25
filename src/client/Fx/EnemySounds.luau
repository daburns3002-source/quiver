--!strict
--[[
	The bosses' and Thornwood's enemies' sounds (round 18 of the audition,
	the owner's picks 2026-10-25; `Config/Sounds`), played from what this
	client already sees of each body:

	- the clip it is playing (`ModelClip`, set by the server: a boss's
	  beats, an enemy's wind-up, a Lurker's Emerge);
	- the blows that show no wind-up (`AttackAt`, a melee bite or bash);
	- a volley leaving (`ShotAt`, the Burr Thistle's spit);
	- arriving and diving (`Targetable`: a Thornling landing, a Lurker
	  going under);
	- a fallen body playing Death (a Sow's Boarlets bursting out).

	The Web Walker's spin sound is two seconds long and repeats for as long
	as the web turns. Presentation only.
]]

local CollectionService = game:GetService("CollectionService")

local SoundFx = require(script.Parent.SoundFx)

local EnemySounds = {}

--[[ Model name → the clip that starts each sound. ]]
local CLIPS: { [string]: { [string]: string } } = {
	SlimeKing = {
		Bounce_Windup = "boss_king_bounce_windup",
		Bounce_Launch = "boss_king_bounce_launch",
		Bounce_Land = "boss_king_bounce_slam",
		Lash_Strike = "boss_king_lash",
		Lash_Strike_L = "boss_king_lash",
		Lash_Pull = "boss_king_grab",
		Lash_Pull_L = "boss_king_grab",
		Lash_ChestBump = "boss_king_chest_bump",
		Lash_ChestBump_L = "boss_king_chest_bump",
		-- a missed lash holds its fist on the floor, spattering goo
		Lash_Hold = "boss_king_goo",
		Lash_Hold_L = "boss_king_goo",
	},
	Broodmother = {
		WebSpin_Windup = "boss_brood_web_windup",
		WebSpin_Hold = "boss_brood_web_spin",
		WebSpin_End = "boss_brood_web_break",
		ShootWeb = "boss_brood_web_shot",
		-- she only moves while her web drags someone in
		Move = "boss_brood_web_pull",
		Summon = "boss_brood_summon",
	},
	BrambleBoar = {
		["Attack wind-up"] = "enemy_boar_gore",
		Charge = "enemy_boar_charge",
	},
	BrambleLurker = {
		["Attack wind-up"] = "enemy_lurker_spray",
		Emerge = "enemy_lurker_emerge",
	},
	--[[ A fallen Sow plays Death as its Boarlets tumble out. ]]
	BrambleSowFallen = { Death = "enemy_sow_drop" },
}

--[[ Model name → the sound of a blow with no wind-up. ]]
local ATTACKS: { [string]: string } = {
	BrambleSow = "enemy_sow_attack",
	Boarlet = "enemy_boarlet_bite",
	Thornling = "enemy_thornling_bite",
}

--[[ Model name → the sound of its volley leaving (`ShotAt`), timed to the
     shots: the Burr Thistle's three "ptoo"s are its three burrs. ]]
local SHOTS: { [string]: string } = { BurrThistle = "enemy_thistle_spit" }

--[[ Model name → sounds for arriving (Targetable true) and diving (false). ]]
local ARRIVE: { [string]: string } = { Thornling = "enemy_thornling_hatch" }
local DIVE: { [string]: string } = { BrambleLurker = "enemy_lurker_dive" }

--[[ The spin loop: seconds between its plays, and the clip it lasts for. ]]
local SPIN_SOUND, SPIN_CLIP, SPIN_EVERY = "boss_brood_web_spin", "WebSpin_Hold", 2

local watched: { [Model]: boolean } = {}

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = true
	local name = model.Name
	local clips = CLIPS[name]
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
	local attack = ATTACKS[name]
	if attack then
		model:GetAttributeChangedSignal("AttackAt"):Connect(function()
			SoundFx.play(attack)
		end)
	end
	local shot = SHOTS[name]
	if shot then
		model:GetAttributeChangedSignal("ShotAt"):Connect(function()
			SoundFx.play(shot)
		end)
	end
	if ARRIVE[name] or DIVE[name] then
		model:GetAttributeChangedSignal("Targetable"):Connect(function()
			local sound = if model:GetAttribute("Targetable") == true
				then ARRIVE[name]
				else DIVE[name]
			if sound then
				SoundFx.play(sound)
			end
		end)
	end
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			watched[model] = nil
		end
	end)
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
