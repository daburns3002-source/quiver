--!strict
--[[
	Each class's card pool (`Ability.classes`; docs/CLASS-CARDS.md). A card
	that only means something for one weapon must be dealt to that class
	alone, or a Warden drafts Multishot and wastes the pick; and each class
	needs enough cards that a draft can always deal a full hand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local TestRunner = require(script.Parent.TestRunner)
local Types = require(ReplicatedStorage.Shared.Types)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)

local HAND = 3

local function pool(class: string): { Abilities.Ability }
	local out = {}
	for _, ability in Abilities.all do
		if ability.filler then
			continue
		end
		if not ability.classes or table.find(ability.classes, class) then
			table.insert(out, ability)
		end
	end
	return out
end

--[[ An Arcanist's cast, built the way FiringSystem builds it. ]]
local function cast(counts: { [string]: number }): { Types.ShotSpec }
	local pipeline = ShotPipeline.new()
	for _, stage in AbilityEffects.stages(counts, "Arcanist") do
		pipeline:addStage(stage)
	end
	return pipeline:build({
		damage = Balance.Player.baseDamage,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, -1),
	})
end

local function max(id: string): { [string]: number }
	return { [id] = #Abilities.byId[id].levels }
end

return function(t: TestRunner.Helper)
	t.test("every card's classes exist", function()
		for _, ability in Abilities.all do
			local classes: { string } = ability.classes or {}
			for _, class in classes do
				t.notNil(Classes[class], `{ability.id} is dealt to unknown class {class}`)
			end
		end
	end)

	--[[ Arrow cards shape a volley of arrows, blade cards a swing, spell
	     cards an orb: each belongs to the one class that has that attack. ]]
	t.test("weapon cards are dealt to one class only", function()
		local owner = { arrow = "Ranger", blade = "Warden", spell = "Arcanist" }
		for _, ability in Abilities.all do
			local class = owner[ability.group]
			if class then
				local classes: { string } = ability.classes or {}
				t.isTrue(
					#classes == 1 and classes[1] == class,
					`{ability.id} is a {ability.group} card but is not {class}'s alone`
				)
			end
		end
	end)

	t.test("every class can be dealt a full hand at every rarity mix", function()
		for name in Classes do
			t.isTrue(#pool(name) >= HAND * 3, `{name} has only {#pool(name)} cards`)
		end
	end)

	t.test("Twin Cast and Arcane Echo add orbs, the echo later", function()
		local plain = cast({})
		t.isTrue(#cast(max("TwinCast")) > #plain, "Twin Cast added no orb")
		local echoed = cast(max("ArcaneEcho"))
		t.isTrue(#echoed > #plain, "Arcane Echo added no orb")
		local latest = 0
		for _, spec in echoed do
			latest = math.max(latest, spec.delay)
		end
		t.isTrue(latest > 0, "the echo is not delayed")
	end)

	t.test("Spell Pierce, Chain Lightning and Bigger Orbs change the orb", function()
		local plain = cast({})[1]
		t.isTrue(cast(max("SpellPierce"))[1].pierce > plain.pierce, "no pierce")
		t.isTrue(cast(max("ChainLightning"))[1].ricochet > plain.ricochet, "no arcs")
		t.isTrue(
			cast(max("BiggerOrbs"))[1].splashRadius > plain.splashRadius,
			"the blast is no larger"
		)
	end)

	t.test("the Warden's cards change the swing and the guard", function()
		local plain = AbilityEffects.serverStats({}, "Warden")
		local function stat(id: string)
			return AbilityEffects.serverStats(max(id), "Warden")
		end
		t.isTrue(stat("QuickHands").attackCooldown < plain.attackCooldown, "Quick Hands")
		t.isTrue(stat("IronSkin").damageTaken < plain.damageTaken, "Iron Skin")
		t.isTrue(stat("IronSkin").damageTaken > 0, "Iron Skin makes the Warden immune")
		t.isTrue(stat("Cleave").melee.widthScale > plain.melee.widthScale, "Cleave")
		t.isTrue(stat("LongReach").melee.reachBonus > plain.melee.reachBonus, "Long Reach")
		t.isTrue(stat("Steadfast").melee.guardLinger > plain.melee.guardLinger, "Steadfast")
		t.isTrue(stat("HeavyBlade").melee.slamBonus > plain.melee.slamBonus, "Heavy Blade")
		t.isTrue(stat("Bloodletting").melee.lifesteal > plain.melee.lifesteal, "Bloodletting")
		t.isTrue(stat("Execute").melee.executeBonus > plain.melee.executeBonus, "Execute")
	end)

	--[[ Long Reach must reach the client too, or the Warden predicts its
	     swing from the old range and never starts one at the new edge. ]]
	t.test("Long Reach is in what the client predicts from", function()
		t.isTrue(
			AbilityEffects.clientStats(max("LongReach"), "Warden").reachBonus > 0,
			"the client never hears of Long Reach"
		)
	end)

	--[[ Each class has one Mythic of its own (owner, 2026-10-23): Dual Bows,
	     Meteor, Earthbreaker. ]]
	t.test("every class has exactly one Mythic, its own", function()
		for name in Classes do
			local mythics = {}
			for _, ability in Abilities.all do
				local classes: { string } = ability.classes or {}
				if ability.rarity == "Mythic" and table.find(classes, name) then
					table.insert(mythics, ability.id)
				end
			end
			t.equal(#mythics, 1)
		end
	end)

	t.test("Meteor and Earthbreaker switch their area attacks on", function()
		t.equal(AbilityEffects.serverStats({}, "Arcanist").meteor, 0)
		t.isTrue(AbilityEffects.serverStats(max("Meteor"), "Arcanist").meteor > 0, "Meteor")
		t.equal(AbilityEffects.serverStats({}, "Warden").earthbreaker, 0)
		t.isTrue(
			AbilityEffects.serverStats(max("Earthbreaker"), "Warden").earthbreaker > 0,
			"Earthbreaker"
		)
		local meteor = Balance.Player.meteor
		t.isTrue(meteor.every >= 2, "a meteor on every cast is just a bigger orb")
		t.isTrue(
			meteor.damage > 1 and meteor.delay > 0,
			"a meteor should hit hard, after a warning"
		)
		local quake = Balance.Player.earthbreaker
		t.isTrue(quake.crackDuration > quake.crackEvery, "the cracks never erupt")
	end)

	--[[ The server's slam lands when the Warden's leap animation shows it
	     landing (the Timber Blade kit's Earthbreaker clip, `Impact`). ]]
	t.test("Earthbreaker's slam lands on its animation's impact", function()
		local clip = WeaponAnimations.TimberBlade.Earthbreaker
		t.notNil(clip, "the blade has no Earthbreaker clip")
		t.near(Balance.Player.earthbreaker.leap, clip.markers.Impact, 1e-3)
	end)

	--[[ The staff's Meteor cast (the BranchStaff kit) summons the meteor,
	     then points the staff at its target as it lands: the point must
	     come after the summon and no later than the strike, or the staff
	     slams down at nothing after the explosion. ]]
	t.test("the Meteor cast points as the meteor lands", function()
		local clip = WeaponAnimations.BranchStaff.Meteor
		t.notNil(clip, "the staff has no Meteor clip")
		local summon, point = clip.markers.Summon, clip.markers.Point
		t.isTrue(summon ~= nil and point ~= nil and summon < point, "the cast lacks its markers")
		t.isTrue(point <= Balance.Player.meteor.delay, "the staff points after the meteor lands")
	end)
end
