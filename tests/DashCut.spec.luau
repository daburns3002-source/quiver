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

	t.test("the line is a dash long, the way the dash went, and flat", function()
		local a, b = DashCut.line(A, Vector3.new(0, 0, -1), 6)
		t.near((b - a).Magnitude, 6, 1e-6)
		t.near(a.Y, 0, 1e-9)
		t.near(b.Y, 0, 1e-9)
		t.near(b.Z, -6, 1e-6)
		-- a dash a wall stopped at once is a point, and never runs backwards
		local c, d = DashCut.line(A, Vector3.new(1, 0, 0), 0)
		t.near((d - c).Magnitude, 0, 1e-9)
		local e, f = DashCut.line(A, Vector3.new(1, 0, 0), -4)
		t.near((f - e).Magnitude, 0, 1e-9)
	end)

	--[[ The way is the one thing the client says. Whatever it sends, the
	     server gets a flat unit direction or nothing: never a longer dash. ]]
	t.test("what a client sends is made a flat direction, or nothing", function()
		local way = DashCut.heading(Vector3.new(3, 9, -4)) :: Vector3
		t.near(way.Magnitude, 1, 1e-6)
		t.near(way.Y, 0, 1e-9)
		t.near(way.X, 0.6, 1e-6)
		t.near((DashCut.heading(Vector3.new(0, 0, -5000)) :: Vector3).Magnitude, 1, 1e-6)
		t.isNil(DashCut.heading(nil))
		t.isNil(DashCut.heading(7))
		t.isNil(DashCut.heading("north"))
		t.isNil(DashCut.heading(Vector3.new(0, 1, 0)), "straight up is no way to dash")
		t.isNil(DashCut.heading(Vector3.zero))
		t.isNil(DashCut.heading(Vector3.new(0 / 0, 0, 1)), "not a number")
		t.isNil(DashCut.heading(Vector3.new(math.huge, 0, 0)))
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
				--[[ Untouchable for the dash and `guard` after: well under
				     half the wait, or the class could never be hurt. It was
				     a quarter until the owner asked for a longer Assassin
				     guard (2026-11-27, "Longer dash guard"). ]]
				local safe = Balance.Player.dash.duration + dash.guard
				t.isTrue(
					safe < dash.cooldown * 0.4,
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
