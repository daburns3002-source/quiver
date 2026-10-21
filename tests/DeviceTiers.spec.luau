--!strict
--[[
	Device tier budgets.

	Tiering is a non-negotiable: a phone and a desktop run the same code with
	different numbers. The failure mode is not a crash, it is a tier quietly
	being *more* expensive than the one above it — which nobody notices until a
	cheap phone is drawing more projectiles than a desktop.

	These assert the ordering between tiers, never the values. Retuning a
	budget should not fail a test; inverting two should.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeviceTiers = require(ReplicatedStorage.Shared.Config.DeviceTiers)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local low = DeviceTiers.Low
	local medium = DeviceTiers.Medium
	local high = DeviceTiers.High

	t.test("every tier knows its own name", function()
		t.equal(low.name, "Low")
		t.equal(medium.name, "Medium")
		t.equal(high.name, "High")
	end)

	t.test("projectile budgets never decrease as the tier rises", function()
		t.isTrue(
			low.maxRenderedProjectiles <= medium.maxRenderedProjectiles,
			"Low draws more projectiles than Medium"
		)
		t.isTrue(
			medium.maxRenderedProjectiles <= high.maxRenderedProjectiles,
			"Medium draws more projectiles than High"
		)
	end)

	t.test("damage number budgets never decrease as the tier rises", function()
		t.isTrue(low.maxDamageNumbers <= medium.maxDamageNumbers, "Low exceeds Medium")
		t.isTrue(medium.maxDamageNumbers <= high.maxDamageNumbers, "Medium exceeds High")
	end)

	t.test("every budget is usable", function()
		for _, tier in { low, medium, high } do
			t.isTrue(tier.maxRenderedProjectiles > 0, `{tier.name} cannot draw any projectiles`)
			t.isTrue(tier.maxDamageNumbers > 0, `{tier.name} cannot draw any damage numbers`)
		end
	end)

	--[[
		The client caps what it draws, never what the server simulates. If a
		tier could render more than the server will ever create, the cap is
		dead weight rather than a budget.
	]]
	t.test("no tier promises more projectiles than the server can produce", function()
		local Balance = require(ReplicatedStorage.Shared.Config.Balance)

		for _, tier in { low, medium, high } do
			t.isTrue(
				tier.maxRenderedProjectiles <= Balance.Projectile.maxActive,
				`{tier.name} would draw more than the server simulates`
			)
		end
	end)

	t.test("shadows are only ever enabled at the top tier", function()
		t.isFalse(low.enableShadows, "a low tier should not pay for shadows")
		t.isTrue(high.enableShadows, "the high tier should be allowed them")
	end)
end
