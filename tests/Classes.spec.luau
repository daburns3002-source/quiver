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
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local TestRunner = require(script.Parent.TestRunner)
local WeaponTiming = require(ReplicatedStorage.Shared.Combat.WeaponTiming)
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

	--[[ Every hit shoves its enemy (owner, 2026-10-25). A class may shove
	     less with a blow, never not at all, and its combo's last blow
	     shoves all the way. ]]
	t.test("a blow that shoves less still shoves, and the last blow shoves whole", function()
		for name, class in Classes do
			local knock = class.swing and class.swing.knock
			if class.swing and knock then
				t.equal(#knock, #class.swing.damage, `{name} has a shove for every blow`)
				for index, share in knock do
					t.isTrue(share >= 0.25 and share <= 1, `{name}'s blow {index} shoves {share}`)
				end
				t.near(knock[#knock], 1, 1e-9)
			end
		end
	end)

	--[[ A class that stands and trades blows (its swing guards it) needs
	     the health to; one that does not guard (the Assassin) has more than
	     the Ranger, since it fights up close, and less than one that guards
	     (owner, 2026-11-16: 1.5x). ]]
	t.test(
		"every class has a health scale, and a guarded melee class outlasts the Ranger",
		function()
			local ranger = AbilityEffects.serverStats({}, "Ranger")
			for name, class in Classes do
				t.isTrue(class.healthScale > 0, `{name}'s health scale is not positive`)
				if class.swing then
					local stats = AbilityEffects.serverStats({}, name)
					t.isTrue(
						stats.maxHealth >= ranger.maxHealth,
						`{name} has less health than the Ranger`
					)
					if class.swing.guard then
						t.isTrue(
							stats.maxHealth > ranger.maxHealth,
							`{name} trades blows with no more health`
						)
					end
				end
			end
			local assassin = AbilityEffects.serverStats({}, "Assassin")
			local warden = AbilityEffects.serverStats({}, "Warden")
			t.near(assassin.maxHealth, ranger.maxHealth * 1.5, 1e-6)
			t.isTrue(assassin.maxHealth < warden.maxHealth, "the Assassin outlasts the Warden")
		end
	)

	--[[ The Assassin (owner, 2026-11-15, option A): quicker and lighter
	     than every other class, closer in than the Warden, and its three
	     blows fit inside its own cooldown at the speed they were made. ]]
	t.test("the Assassin strikes fastest, lightest and closest", function()
		local assassin = AbilityEffects.serverStats({}, "Assassin")
		for name, class in Classes do
			if name ~= "Assassin" then
				local other = AbilityEffects.serverStats({}, name)
				t.isTrue(assassin.attackCooldown < other.attackCooldown, `no quicker than {name}`)
				t.isTrue(assassin.damage < other.damage, `hits no lighter than {name}`)
				t.isTrue(
					(Classes.Assassin.reach :: number) < (class.reach or Balance.Player.attackRange),
					`reaches no closer than {name}`
				)
			end
		end
		local blows = Classes.Assassin.swing :: Classes.Swing
		t.isTrue(blows.arc < (Classes.Warden.swing :: Classes.Swing).arc, "its arc is no narrower")
		t.isNil(blows.guard, "the Assassin does not guard")
		for index = 1, #blows.damage do
			t.near(
				WeaponTiming.cycleSpeed(Classes.Assassin.weapon, index, assassin.attackCooldown),
				1,
				1e-9
			)
			t.isTrue(
				WeaponTiming.hitDelay(Classes.Assassin.weapon, index, assassin.attackCooldown)
					< assassin.attackCooldown / 2,
				`blow {index} lands late in its cooldown`
			)
		end
	end)
end
