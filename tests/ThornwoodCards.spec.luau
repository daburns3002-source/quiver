--!strict
--[[
	Thornwood's six cards (owner, 2026-11-18: "Build the six new";
	`Config/Abilities`, docs/CLASS-CARDS.md): that each is a card of its own
	class with a picture, that its level reaches the stat the server reads,
	and what `ClassUpgrades.dress` puts on a shot for the four that ride
	one. The two on the Warden's slam (Boar Rush, Ruin Cracks) land in
	`Combat/MeleeSystem`, which needs live enemies: seen in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local TestRunner = require(script.Parent.TestRunner)

--[[ Each card's classes. The two on a combo's last blow are both melee
     classes': the Warden's slam and the Assassin's double stab. ]]
local CARDS: { [string]: { string } } = {
	WebSnare = { "Ranger" },
	ThornBurst = { "Ranger" },
	RootHold = { "Arcanist" },
	BurrBlight = { "Arcanist" },
	BoarRush = { "Warden", "Assassin" },
	RuinCracks = { "Warden", "Assassin" },
}

return function(t: TestRunner.Helper)
	t.test("each is a card of its own classes, dealt, with a picture", function()
		for id, classes in CARDS do
			local card = Abilities.byId[id]
			t.notNil(card, `{id} is no card`)
			if card then
				local dealt = table.clone(card.classes or {})
				table.sort(dealt)
				local wanted = table.clone(classes)
				table.sort(wanted)
				t.equal(table.concat(dealt, ","), table.concat(wanted, ","), `{id}'s classes`)
				t.isTrue(card.benched ~= true, `{id} is benched`)
				t.equal(#card.levels, #card.stats, `{id} has a level with no words`)
				local picture = (CardAssets.icons :: any)[card.icon]
				t.isTrue(
					type(picture) == "string" and picture ~= "",
					`{id} has no picture ({card.icon})`
				)
			end
		end
	end)

	t.test("a card's level is the number the server reads", function()
		local function level(id: string, at: number): number
			return Abilities.byId[id].levels[at]
		end
		local ranger = AbilityEffects.serverStats({ WebSnare = 1, ThornBurst = 2 }, "Ranger")
		t.near(ranger.upgrades.webSnare, level("WebSnare", 1), 1e-9)
		t.near(ranger.upgrades.thornBurst, level("ThornBurst", 2), 1e-9)
		local arcanist = AbilityEffects.serverStats({ RootHold = 1, BurrBlight = 2 }, "Arcanist")
		t.near(arcanist.upgrades.rootHold, level("RootHold", 1), 1e-9)
		t.near(arcanist.upgrades.burrBlight, level("BurrBlight", 2), 1e-9)
		local warden = AbilityEffects.serverStats({ BoarRush = 2, RuinCracks = 1 }, "Warden")
		t.near(warden.melee.boarRush, level("BoarRush", 2), 1e-9)
		t.near(warden.melee.ruinCracks, level("RuinCracks", 1), 1e-9)
		-- and nothing without the cards
		local plain = AbilityEffects.serverStats({}, "Ranger")
		t.equal(plain.upgrades.webSnare, 0)
		t.equal(plain.upgrades.thornBurst, 0)
		t.equal(plain.upgrades.rootHold, 0)
		t.equal(plain.upgrades.burrBlight, 0)
		t.equal(plain.melee.boarRush, 0)
		t.equal(plain.melee.ruinCracks, 0)
	end)

	t.test("the numbers behind them make sense", function()
		local thornwood = Balance.Player.thornwood
		t.isTrue(thornwood.web.duration > 0)
		t.isTrue(thornwood.thorn.every >= 2 and thornwood.thorn.radius > 0)
		t.isTrue(thornwood.root.every >= 2)
		t.isTrue(thornwood.root.boss > 0 and thornwood.root.boss < 1, "a boss is slowed, not held")
		t.isTrue(thornwood.blight.stacks >= 1 and thornwood.blight.duration > 0)
		t.isTrue(thornwood.ruin.duration > 0)
		-- a web never roots: it slows
		for _, slow in Abilities.byId.WebSnare.levels do
			t.isTrue(slow > 0 and slow < 1)
		end
	end)

	--[[ What rides a shot. A session here is only its upgrades: `dress`
	     and `afterVolley` read nothing else without the other cards. ]]
	t.test("Web Snare and Burr Blight dress every shot", function()
		local ClassUpgrades = (require :: any)(ServerScriptService.Server.Combat.ClassUpgrades)
		local function session(upgrades: { [string]: number }): any
			local held = AbilityEffects.serverStats({}, "Ranger").upgrades :: any
			for key, value in upgrades do
				held[key] = value
			end
			return { upgrades = held }
		end
		local plain: any = {}
		ClassUpgrades.dress(session({}), plain)
		t.isNil(plain.web)
		t.isNil(plain.thorn)
		t.isNil(plain.root)
		t.isNil(plain.blight)

		local webbed: any = {}
		ClassUpgrades.dress(session({ webSnare = 0.3 }), webbed)
		t.near(webbed.slow, 0.7, 1e-9)
		t.equal(webbed.slowDuration, Balance.Player.thornwood.web.duration)
		t.equal(webbed.web, true)

		local blighted: any = {}
		ClassUpgrades.dress(session({ burrBlight = 0.4 }), blighted)
		t.near(blighted.blight, 0.4, 1e-9)
	end)

	t.test("Thorn Burst rides every third volley, Root Hold every fourth", function()
		local ClassUpgrades = (require :: any)(ServerScriptService.Server.Combat.ClassUpgrades)
		local held = AbilityEffects.serverStats({}, "Ranger").upgrades :: any
		held.thornBurst = 0.6
		held.rootHold = 1
		local session: any = { upgrades = held }
		local thorns: { boolean } = {}
		local roots: { boolean } = {}
		for volley = 1, 12 do
			local params: any = { splashRadius = 0, splashScale = 0 }
			ClassUpgrades.dress(session, params)
			thorns[volley] = params.thorn == true
			roots[volley] = (params.root or 0) > 0
			if params.thorn then
				t.equal(params.splashRadius, Balance.Player.thornwood.thorn.radius)
				t.near(params.splashScale, 0.6, 1e-9)
			else
				t.equal(params.splashRadius, 0, "a burst on a volley that has none")
			end
			ClassUpgrades.afterVolley(
				session,
				Vector3.zero,
				Vector3.new(0, 0, -1),
				Vector3.new(0, 0, -10),
				volley
			)
		end
		for volley = 1, 12 do
			t.equal(
				thorns[volley],
				volley % Balance.Player.thornwood.thorn.every == 0,
				`volley {volley}`
			)
			t.equal(
				roots[volley],
				volley % Balance.Player.thornwood.root.every == 0,
				`volley {volley}`
			)
		end
	end)

	--[[ A Thorn Burst is never smaller than Blast Arrows' own blast on the
	     same arrow: the bigger of each wins. ]]
	t.test("a burst keeps a bigger blast already on the shot", function()
		local ClassUpgrades = (require :: any)(ServerScriptService.Server.Combat.ClassUpgrades)
		local held = AbilityEffects.serverStats({}, "Ranger").upgrades :: any
		held.thornBurst = 0.6
		local session: any = { upgrades = held }
		for _ = 1, Balance.Player.thornwood.thorn.every - 1 do
			ClassUpgrades.afterVolley(session, Vector3.zero, Vector3.zAxis, Vector3.zAxis, 0)
		end
		local params: any = { splashRadius = 99, splashScale = 2 }
		ClassUpgrades.dress(session, params)
		t.equal(params.thorn, true)
		t.equal(params.splashRadius, 99)
		t.equal(params.splashScale, 2)
	end)
end
