--!strict
--[[
	The themed sets' seven daggers' own effects (owner, 2026-11-18;
	docs/CLASS-CARDS.md "The themed daggers' seven"): each a card only its
	dagger carries (`weaponOnly`), never dealt by a draft or an Angel, on
	with its dagger and off without, at the numbers the owner said yes to,
	and no worth more than the strikes it rides on. The Combo Counter's
	count is driven through `Combat/AssassinUpgrades` itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local AssassinRules = require(ReplicatedStorage.Shared.Combat.AssassinRules)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

--[[ Each dagger, its card, and the `UpgradeStats` key the card sets. ]]
local DAGGERS: { { weapon: string, card: string, key: string } } = {
	{ weapon = "TwinkleDaggers", card = "WishingStar", key = "wishingStar" },
	{ weapon = "SpurDaggers", card = "SpurRowel", key = "spurRowel" },
	{ weapon = "SquirtDaggers", card = "SplashWave", key = "splashWave" },
	{ weapon = "TokenDaggers", card = "ComboCounter", key = "comboCounter" },
	{ weapon = "CometDaggers", card = "CometCrash", key = "cometCrash" },
	{ weapon = "BellchimeDaggers", card = "BellChime", key = "bellChime" },
	{ weapon = "EmbershardDaggers", card = "LavaBurst", key = "lavaBurst" },
}

local function level(id: string): number
	return Abilities.byId[id].levels[1]
end

return function(t: TestRunner.Helper)
	t.test("each themed dagger carries its own card, and nothing else does", function()
		local seven: { [string]: boolean } = {}
		for _, row in DAGGERS do
			seven[row.card] = true
			local stats = (WeaponStats.weapons :: any)[row.weapon]
			t.notNil(stats, `{row.weapon} is no weapon`)
			local innate: { [string]: number } = stats and stats.innate or {}
			t.equal(innate[row.card], 1, `{row.weapon} does not carry {row.card}`)
			local count = 0
			for _ in innate do
				count += 1
			end
			t.equal(count, 1, `{row.weapon} carries more than its own`)
			local card = Abilities.byId[row.card]
			t.isTrue(card.weaponOnly == true, `{row.card} could be dealt`)
			t.equal(card.rarity, "Legendary", row.card)
			t.equal(card.group, "dagger", row.card)
			local classes: { string } = card.classes or {}
			t.isTrue(#classes == 1 and classes[1] == "Assassin", `{row.card} is not the Assassin's`)
			t.equal(#card.levels, 1, `{row.card} has more than one level`)
			t.notNil(CardAssets.icons[card.icon], `{row.card} has no icon`)
		end
		for _, card in Abilities.all do
			if card.weaponOnly then
				t.isTrue(seven[card.id] == true, `{card.id} is weapon-only but no themed dagger's`)
			end
		end
	end)

	t.test("no draft and no Angel deals one", function()
		local Loadout = (require :: any)(ServerScriptService.Server.Run.Loadout)
		local random = Random.new(20261118)
		for _ = 1, 300 do
			local state = Loadout.new()
			state.class = "Assassin"
			for _, id in Loadout.rollOffer(state, false, random) do
				t.isFalse(Abilities.byId[id].weaponOnly == true, `{id} was dealt`)
			end
			local angel = Loadout.new()
			angel.class = "Assassin"
			for _, id in Loadout.openAngel(angel, random) or {} do
				t.isFalse(Abilities.byId[id].weaponOnly == true, `{id} was offered by an Angel`)
			end
		end
	end)

	t.test("each is on with its dagger and off without", function()
		local plain = AbilityEffects.serverStats({}, "Assassin").upgrades :: any
		local other = AbilityEffects.serverStats({}, "Assassin", "SplinterDaggers").upgrades :: any
		for _, row in DAGGERS do
			t.equal(plain[row.key], 0, `{row.key} without a dagger`)
			t.equal(other[row.key], 0, `{row.key} with the class's own daggers`)
			local held = AbilityEffects.serverStats({}, "Assassin", row.weapon).upgrades :: any
			t.near(held[row.key], level(row.card), 1e-9, `{row.weapon} gives {row.key}`)
			for _, rest in DAGGERS do
				if rest ~= row then
					t.equal(held[rest.key], 0, `{row.weapon} also gives {rest.key}`)
				end
			end
		end
	end)

	--[[ What the owner said yes to (2026-11-18). ]]
	t.test("the numbers are the ones the owner said yes to", function()
		local daggers = Balance.Player.daggers
		t.equal(daggers.star.every, 5)
		t.equal(daggers.star.radius, 6)
		t.near(level("WishingStar"), 0.8, 1e-9)
		t.equal(level("SpurRowel"), 3)
		t.near(daggers.spur.damage, 0.5, 1e-9)
		t.equal(daggers.splash.every, 3)
		t.equal(daggers.splash.radius, 5)
		t.near(daggers.splash.slow, 0.3, 1e-9)
		t.equal(daggers.splash.duration, 2)
		t.near(level("SplashWave"), 0.4, 1e-9)
		t.near(daggers.combo.step, 0.03, 1e-9)
		t.near(level("ComboCounter"), 0.3, 1e-9)
		t.near(daggers.comet.delay, 1.5, 1e-9)
		t.equal(daggers.comet.radius, 5)
		t.near(level("CometCrash"), 0.6, 1e-9)
		t.equal(daggers.bell.every, 6)
		t.equal(daggers.bell.radius, 8)
		t.near(daggers.bell.damage, 0.4, 1e-9)
		t.near(level("BellChime"), 0.8, 1e-9)
		t.isTrue(daggers.bell.boss > 0 and daggers.bell.boss < 1, "a boss is slowed, not held")
		t.equal(daggers.lava.length, 10)
		t.near(level("LavaBurst"), 0.5, 1e-9)
		t.equal(daggers.lava.burn, 3)
		t.isTrue(
			daggers.star.delay > 0 and daggers.star.delay < daggers.comet.delay,
			"the star falls fast"
		)
	end)

	t.test("the combo counts to ten at +3% each, and stops", function()
		local step = Balance.Player.daggers.combo.step
		local most = level("ComboCounter")
		t.equal(AssassinRules.comboFull(step, most), 10)
		t.equal(AssassinRules.comboBonus(0, step, most), 0)
		t.near(AssassinRules.comboBonus(4, step, most), 0.12, 1e-9)
		t.near(AssassinRules.comboBonus(10, step, most), 0.3, 1e-9)
		t.near(AssassinRules.comboBonus(25, step, most), 0.3, 1e-9)
	end)

	--[[ The count as the server keeps it: a strike that struck something
	     adds one, one that struck nothing does not, a hit taken empties it,
	     and a new run starts it again. ]]
	t.test("the Token Daggers' count rises with strikes and a hit empties it", function()
		local AssassinUpgrades = (require :: any)(
			ServerScriptService.Server.Combat.AssassinUpgrades
		)
		local player = Instance.new("Folder")
		local session = {
			player = player,
			loadout = {},
			alive = true,
			damage = 10,
			upgrades = AbilityEffects.serverStats({}, "Assassin", "TokenDaggers").upgrades,
		}
		local enemy = { model = Instance.new("Model"), position = Vector3.zero, halfWidth = 1 }
		local function blow(struck: { any })
			AssassinUpgrades.afterBlow(session, Vector3.zero, Vector3.zAxis, os.clock(), {
				struck = struck,
				blow = 10,
				stab = false,
				ahead = 4.5,
			})
		end
		t.equal(AssassinUpgrades.comboScale(session), 1)
		for _ = 1, 4 do
			blow({ enemy })
		end
		t.equal(player:GetAttribute("ComboCount"), 4)
		t.near(AssassinUpgrades.comboScale(session), 1.12, 1e-9)
		blow({})
		t.equal(player:GetAttribute("ComboCount"), 4, "a swing at nothing counted")
		for _ = 1, 12 do
			blow({ enemy })
		end
		t.equal(player:GetAttribute("ComboCount"), 10)
		t.near(AssassinUpgrades.comboScale(session), 1.3, 1e-9)
		AssassinUpgrades.onHurt(session)
		t.equal(player:GetAttribute("ComboCount"), 0)
		t.equal(AssassinUpgrades.comboScale(session), 1)
		blow({ enemy })
		blow({ enemy })
		session.loadout = {}
		t.equal(AssassinUpgrades.comboScale(session), 1, "a new run kept the last one's count")
		blow({ enemy })
		t.equal(player:GetAttribute("ComboCount"), 1)
		player:Destroy()
		enemy.model:Destroy()
	end)

	--[[ Embershard's lava runs on from the double stab down a lane. ]]
	t.test("the lava runs a lane on from the stab", function()
		local lava = Balance.Player.daggers.lava
		local swing = Classes.Assassin.swing :: Classes.Swing
		local ahead = swing.slamAhead
		local along = function(at: Vector3)
			return SwingBox.waveAlong(
				Vector3.zero,
				Vector3.zAxis,
				ahead,
				lava.length,
				lava.width,
				at,
				1
			)
		end
		t.notNil(along(Vector3.new(0, 0, ahead + 5)), "in the lane")
		t.notNil(along(Vector3.new(0, 0, ahead + lava.length)), "at its end")
		t.isNil(along(Vector3.new(0, 0, ahead + lava.length + 3)), "past its end")
		t.isNil(along(Vector3.new(lava.width, 0, ahead + 5)), "off to the side")
		t.isTrue(lava.length > swing.reach, "the lava runs past the daggers' own reach")
	end)

	--[[ Pets and weapons carry a player's power (PR #342): each effect is
	     weighed, on one enemy, against the daggers' own strikes. ]]
	t.test("no effect is worth more than the strikes it rides on", function()
		local daggers = Balance.Player.daggers
		local class = Classes.Assassin
		local swing = class.swing :: Classes.Swing
		local cooldown = Balance.Player.attackCooldown * class.cooldownScale
		local average = 0
		for _, each in swing.damage do
			average += each / #swing.damage
		end
		local stab = swing.damage[#swing.damage]
		local perSecond = average / cooldown
		local combo = #swing.damage * cooldown
		local function under(worth: number, share: number, name: string)
			t.isTrue(worth < perSecond * share, `{name}: {worth} a second against {perSecond}`)
		end
		under(level("WishingStar") / (daggers.star.every * cooldown), 0.3, "Wishing Star")
		under(daggers.spur.damage / combo, 0.3, "Spur Rowel")
		under(level("SplashWave") / (daggers.splash.every * cooldown), 0.3, "Splash Wave")
		t.isTrue(level("ComboCounter") <= 0.3, "Combo Counter")
		under(
			level("CometCrash") * stab / math.max(daggers.comet.delay, cooldown),
			0.4,
			"Comet Crash"
		)
		under(daggers.bell.damage / (daggers.bell.every * cooldown), 0.3, "Bell Chime")
		under(
			(level("LavaBurst") * stab) / combo + stab * Balance.Burn.rate,
			0.45,
			"Lava Burst and its burn"
		)
		t.isTrue(level("BellChime") < daggers.bell.every * cooldown, "a bell never holds for good")
	end)
end
