--!strict
--[[
	A dash that cuts (`Shared/Combat/DashCut`, `Config/Classes.dash`; the
	Assassin's Shadow Dash): the ground it covers, who stands in it, and that
	it comes back sooner than a plain dash without ever being free.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local DashCut = require(ReplicatedStorage.Shared.Combat.DashCut)
local TestRunner = require(script.Parent.TestRunner)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local A = Vector3.new(0, 3, 0)
local B = Vector3.new(0, 3, -6)

return function(t: TestRunner.Helper)
	t.test("the cut is the line the dash ran, and what stands beside it", function()
		-- on the line, beside it within half the width, and its own width reaching in
		t.isTrue(DashCut.hits(A, B, 5, Vector3.new(0, 0, -3), 0))
		t.isTrue(DashCut.hits(A, B, 5, Vector3.new(2.4, 0, -3), 0))
		t.isFalse(DashCut.hits(A, B, 5, Vector3.new(2.6, 0, -3), 0))
		t.isTrue(DashCut.hits(A, B, 5, Vector3.new(3.9, 0, -3), 1.5))
		-- past either end only as far as the cut is wide, not for ever
		t.isTrue(DashCut.hits(A, B, 5, Vector3.new(0, 0, -8), 0))
		t.isFalse(DashCut.hits(A, B, 5, Vector3.new(0, 0, -9), 0))
		t.isFalse(DashCut.hits(A, B, 5, Vector3.new(0, 0, 3), 0))
		-- height never decides it
		t.isTrue(DashCut.hits(A, B, 5, Vector3.new(0, 40, -3), 0))
	end)

	t.test("a dash that went nowhere still cuts what it stands in", function()
		t.isTrue(DashCut.hits(A, A, 5, Vector3.new(1, 0, 1), 0))
		t.isFalse(DashCut.hits(A, A, 5, Vector3.new(4, 0, 0), 0))
	end)

	t.test("the cut is never longer than a dash, wherever the character ends up", function()
		local a, b = DashCut.path(A, Vector3.new(0, 3, -400), 7.5)
		t.near((b - a).Magnitude, 7.5, 1e-6)
		t.near(a.Y, 0, 1e-9)
		t.near(b.Y, 0, 1e-9)
		-- an honest dash is left as it was
		local c, d = DashCut.path(A, B, 7.5)
		t.near((d - c).Magnitude, 6, 1e-6)
		-- a far-off enemy is not cut by a character that jumped across the room
		t.isFalse(DashCut.hits(a, b, 5, Vector3.new(0, 0, -200), 1.5))
	end)

	t.test("an enemy is pushed out from the nearest point of the line", function()
		local near = DashCut.nearest(A, B, Vector3.new(2, 0, -3))
		t.near(near.X, 0, 1e-6)
		t.near(near.Z, -3, 1e-6)
		t.near(DashCut.nearest(A, B, Vector3.new(2, 0, -30)).Z, -6, 1e-6)
		t.near(DashCut.nearest(A, B, Vector3.new(2, 0, 30)).Z, 0, 1e-6)
	end)

	t.test("a class's own dash comes back sooner, and never at once", function()
		local plain = Balance.Player.dash.cooldown
		t.near(DashCut.cooldown("Ranger"), plain, 1e-9)
		t.near(DashCut.cooldown(nil), plain, 1e-9)
		t.near(DashCut.cooldown("Wizard"), plain, 1e-9)
		for name, class in Classes do
			local dash = class.dash
			if dash then
				t.isTrue(dash.cooldown < plain, `{name}'s dash is no quicker`)
				--[[ Untouchable for the dash and `guard` after: far less
				     than the wait, or the class could never be hurt. ]]
				local safe = Balance.Player.dash.duration + dash.guard
				t.isTrue(
					safe < dash.cooldown * 0.25,
					`{name} is safe {safe} s of every {dash.cooldown}`
				)
				t.isTrue(dash.damage > 0 and dash.width > 0, `{name}'s dash cuts nothing`)
				t.near(DashCut.cooldown(name), dash.cooldown, 1e-9)
			end
			--[[ The client waits what the server holds it to. ]]
			t.near(AbilityEffects.clientStats({}, name).dashCooldown, DashCut.cooldown(name), 1e-9)
		end
	end)

	t.test("a class whose dash cuts has a clip to cut with", function()
		for name, class in Classes do
			if class.dash then
				local weapon = (Weapons :: any)[class.weapon] :: Weapons.Weapon
				local special = weapon.clips.special
				local clip = special and special.dash
				t.notNil(clip, `{name}'s weapon has no dash clip`)
				t.notNil(
					WeaponAnimations[class.weapon][clip :: string],
					`{name}'s dash clip is not in its kit`
				)
			end
		end
	end)
end
