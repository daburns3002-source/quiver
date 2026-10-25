--!strict
--[[
	A Legendary's and a Mythic's shots glow (`Config/Weapons.shotGlow`,
	drawn by `Fx/ProjectileRenderer`; owner, 2026-10-25), as the weapons
	themselves do (CLAUDE.md rule 12). A Mythic (`rainbow`) that fires a shot
	must give it a glow, a Dual Bows pair must keep its skin's, and a glow
	needs a shot to draw it on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

return function(t: TestRunner.Helper)
	t.test("every Mythic's shot glows, and every glowing shot has a shot", function()
		local glowing = 0
		for key, weapon in (Weapons :: any) :: { [string]: Weapons.Weapon } do
			if weapon.rainbow and weapon.bolt then
				t.isTrue(weapon.shotGlow ~= nil, `{key} is a Mythic whose shot does not glow`)
			end
			if weapon.shotGlow then
				glowing += 1
				t.isTrue(weapon.bolt ~= nil, `{key} has a shot glow and no shot`)
			end
		end
		t.isTrue(glowing >= 4, "the Legendary and Mythic shots have lost their glow")
	end)

	t.test("every Mythic blade's swing glows, and every glowing swing has a streak", function()
		local glowing = 0
		for key, weapon in (Weapons :: any) :: { [string]: Weapons.Weapon } do
			if weapon.rainbow and weapon.swingTrail then
				t.isTrue(
					weapon.trailGlow ~= nil,
					`{key} is a Mythic blade whose swing does not glow`
				)
			end
			if weapon.trailGlow then
				glowing += 1
				t.isTrue(weapon.swingTrail ~= nil, `{key} has a swing glow and no streak`)
			end
		end
		t.isTrue(glowing >= 2, "the Legendary and Mythic blades' swings have lost their glow")
	end)

	t.test("a Dual Bows pair keeps its skin's shot glow", function()
		for key, weapon in (Weapons :: any) :: { [string]: Weapons.Weapon } do
			local single = weapon.dualOf and (Weapons :: any)[weapon.dualOf]
			if single then
				t.equal(weapon.shotGlow, single.shotGlow, `{key}'s shots glow unlike its skin's`)
			end
		end
	end)
end
