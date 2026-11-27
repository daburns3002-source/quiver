--!strict
--[[
	Which sound each enemy makes, and when (`Config/Sounds` names), as
	`Fx/EnemySounds` plays them from what the client already sees of a
	body. Keyed by model name, which is the enemy's `displayName`
	(`Enemies/EnemyModel`): the Mossy Glade's Charger, Spitter and Lurker
	are `MeleeCharger`, `SpreadShooter` and `Burrower` in `Balance`.

	The bosses and Thornwood came first (round 18 of the audition, the
	owner's picks 2026-10-25); round 35 (2026-11-26) gave a sound to every
	enemy that still had none: the Mossy Glade's, the Bogheart's, the Hollow
	Fisherman, the benched Lancer, and the Old Tollcrab's and Grandmother
	Gulp's moves.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local EnemySounds = {}

--[[ How fast the Old Tollcrab scuttles, for when each dash starts. ]]
local function scuttleSpeed(): number
	local boss = Balance.Enemies.OldTollcrab.boss
	local scuttle = boss and boss.scuttle
	return if scuttle then scuttle.speed else 34
end

--[[ The clip that starts each sound (`ModelClip`, set by the server: a
     boss's beats, an enemy's wind-up, a Lurker's Emerge). ]]
EnemySounds.clips = {
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
} :: { [string]: { [string]: string } }

--[[ A blow that lands with no wind-up to hear (`AttackAt`): a bite, a
     bash, a bump. ]]
EnemySounds.attacks = {
	BrambleSow = "enemy_sow_attack",
	Boarlet = "enemy_boarlet_bite",
	Thornling = "enemy_thornling_bite",
	Charger = "enemy_charger_bite",
	BabySlime = "enemy_baby_slime_bite",
	BroodSlime = "enemy_brood_slime_bite",
	SporePuff = "enemy_spore_puff_bite",
	Shellback = "enemy_shellback_bash",
} :: { [string]: string }

--[[ A volley leaving (`ShotAt`), timed to the shots: the Burr Thistle's
     three "ptoo"s are its three burrs. ]]
EnemySounds.shots = {
	BurrThistle = "enemy_thistle_spit",
	Spitter = "enemy_spitter_spit",
	Lurker = "enemy_burrower_clods",
	Lancer = "enemy_lancer_lance",
	Glowcap = "enemy_glowcap_spores",
	HollowFisherman = "enemy_fisherman_cast",
} :: { [string]: string }

--[[ Arriving (Targetable true) and diving (false). ]]
EnemySounds.arrive = { Thornling = "enemy_thornling_hatch" } :: { [string]: string }
EnemySounds.dive = { BrambleLurker = "enemy_lurker_dive" } :: { [string]: string }

export type Tell = {
	--[[ The boss whose move shows this telegraph: it sounds only while
	     that boss is in the room. ]]
	boss: string,
	sound: string,
	--[[ Played when the dash starts, not as its lane is drawn: the lane's
	     time less the dash's own (its length over this speed). ]]
	dashSpeed: number?,
}

--[[ The Old Tollcrab and Grandmother Gulp play no clips, so their moves
     are heard from the telegraphs the server shows for them
     (`Remotes.EnemyTelegraph`), by kind. A Lane is any lash's too, so it
     sounds only with the Tollcrab in the room. Gulp's three globs leave
     together and are one sound (its `minGap`); each take lands its splat
     0.75 s in, her `spit.flight`. ]]
EnemySounds.tells = {
	TollTell = { boss = "OldTollcrab", sound = "boss_toll_raise" },
	TollRing = { boss = "OldTollcrab", sound = "boss_toll_ring" },
	EchoTell = { boss = "OldTollcrab", sound = "boss_toll_rap" },
	EchoStrike = { boss = "OldTollcrab", sound = "boss_toll_echo" },
	Lane = { boss = "OldTollcrab", sound = "boss_toll_scuttle", dashSpeed = scuttleSpeed() },
	GulpGlob = { boss = "GrandmotherGulp", sound = "boss_gulp_spit" },
	SlimeTrail = { boss = "GrandmotherGulp", sound = "boss_gulp_slide" },
	GulpInhale = { boss = "GrandmotherGulp", sound = "boss_gulp_inhale" },
} :: { [string]: Tell }

--[[ Seconds after a telegraph of `kind` that its sound plays: 0 but for a
     dash, which waits out the lane's warning (`duration` is the warning
     and the dash together, `length` the dash's). ]]
function EnemySounds.tellDelay(tell: Tell, duration: number, length: number?): number
	local speed = tell.dashSpeed
	if not speed or type(length) ~= "number" then
		return 0
	end
	return math.max(0, duration - length / speed)
end

return table.freeze(EnemySounds)
