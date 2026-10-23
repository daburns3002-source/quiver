--!strict
--[[
	Classes (`Config/Classes`) as `AbilityEffects` applies them. Relationships,
	not values: the Arcanist hits harder and fires slower than the Ranger,
	reaches as far, holds its innate skills, and the client predicts it with
	the same numbers the server fires.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	t.test("every class names a weapon and only real innate skills", function()
		for name, class in Classes do
			t.notNil((Weapons :: any)[class.weapon], `{name}'s weapon {class.weapon} is missing`)
			for id, level in class.innate do
				t.notNil(Abilities.byId[id], `{name} starts with unknown skill {id}`)
				t.isTrue(level >= 1, `{name} starts with {id} at level {level}`)
			end
		end
	end)

	t.test("the Arcanist hits harder and fires slower than the Ranger", function()
		local ranger = AbilityEffects.serverStats({}, "Ranger")
		local arcanist = AbilityEffects.serverStats({}, "Arcanist")
		t.isTrue(arcanist.damage > ranger.damage, "the Arcanist does not hit harder")
		t.isTrue(
			arcanist.attackCooldown > ranger.attackCooldown,
			"the Arcanist does not fire slower"
		)
	end)

	--[[ A slower shot lives longer, so a class never loses reach for its
	     look: the archer targets the same distance either way. ]]
	t.test("every class's shot reaches as far as the Ranger's", function()
		local ranger = AbilityEffects.serverStats({}, "Ranger")
		local reach = ranger.projectileSpeed * ranger.projectileLifetime
		for name in Classes do
			local stats = AbilityEffects.serverStats({}, name)
			t.near(stats.projectileSpeed * stats.projectileLifetime, reach, 1e-6)
		end
	end)

	t.test("an innate skill builds its stage with nothing drafted", function()
		local plain = #AbilityEffects.stages({}, "Ranger")
		local arcanist = #AbilityEffects.stages({}, "Arcanist")
		t.isTrue(arcanist > plain, "the Arcanist's innate splash added no stage")
	end)

	t.test("the client predicts each class with the server's numbers", function()
		for name in Classes do
			local server = AbilityEffects.serverStats({ Strength = 1 }, name)
			local client = AbilityEffects.clientStats({ Strength = 1 }, name)
			t.near(client.attackCooldown, server.attackCooldown, 1e-9)
			t.near(client.projectileSpeed, server.projectileSpeed, 1e-9)
			t.near(client.projectileLifetime, server.projectileLifetime, 1e-9)
			t.equal(client.class, name)
		end
	end)

	--[[ The skill bar shows what was drafted; an innate skill must not appear
	     there as if it had been. ]]
	t.test("the client is sent the drafted skills, not the innate ones", function()
		local client = AbilityEffects.clientStats({}, "Arcanist")
		t.isTrue(next(client.abilities) == nil, "innate skills were sent as drafted")
	end)

	--[[ A melee class picks targets within its reach and strikes an arc, or
	     the slam's circle, in front of it; a target it could pick but its
	     blow could not touch would be swung at for ever. ]]
	t.test("a melee class's swing reaches every target it picks", function()
		for name, class in Classes do
			local swing = class.swing
			if swing then
				t.notNil(class.reach, `{name} swings with no reach`)
				local reach = class.reach :: number
				t.isTrue(reach <= swing.reach, `{name} picks targets past its arc`)
				t.isTrue(
					reach <= swing.slamAhead + swing.slamRadius,
					`{name} picks targets past its slam`
				)
			end
		end
	end)

	t.test("a melee class has a damage for every blow of its combo", function()
		for name, class in Classes do
			if class.swing then
				local weapon = (Weapons :: any)[class.weapon]
				t.isTrue(
					#class.swing.damage == #weapon.clips.fire,
					`{name} has {#class.swing.damage} blow damages for {#weapon.clips.fire} blows`
				)
			end
		end
	end)

	t.test("every class has a health scale, and a melee class outlasts the Ranger", function()
		local ranger = AbilityEffects.serverStats({}, "Ranger")
		for name, class in Classes do
			t.isTrue(class.healthScale > 0, `{name}'s health scale is not positive`)
			if class.swing then
				local stats = AbilityEffects.serverStats({}, name)
				t.isTrue(
					stats.maxHealth > ranger.maxHealth,
					`{name} fights up close with no more health`
				)
			end
		end
	end)
end
