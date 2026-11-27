--!strict
--[[
	Every enemy that shoots has its own drawn look (owner, 2026-11-08: "i want
	each enemy projectile to have its own unique animation"): a look that
	exists, worn by no other shooter, and a sway small enough that the drawn
	shot is still on the line it hits along.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyShots = require(ReplicatedStorage.Shared.Config.EnemyShots)
local TestRunner = require(script.Parent.TestRunner)

--[[ Studs a look may carry the drawn shot off its true line. ]]
local MOST_SWAY = 0.4

return function(t: TestRunner.Helper)
	local shooters: { [string]: Balance.EnemyShot } = {}
	for _, group in { Balance.Enemies :: any, (Balance :: any).Benched } do
		for name, config in group do
			if config.shot then
				shooters[name] = config.shot
			end
		end
	end

	t.test("every shooter has a look of its own", function()
		local wornBy: { [string]: string } = {}
		for name, shot in shooters do
			t.isTrue(EnemyShots.looks[shot.look] ~= nil, `{name}'s look {shot.look} is not defined`)
			t.isTrue(wornBy[shot.look] == nil, `{name} shares {shot.look} with {wornBy[shot.look]}`)
			wornBy[shot.look] = name
		end
	end)

	t.test("a look's sway leaves the shot on its line", function()
		for name, look in EnemyShots.looks do
			local wobble, bob, helix = look.wobble, look.bob, look.helix
			local total = (if wobble then wobble.amount else 0)
				+ (if bob then bob.amount else 0)
				+ (if helix then helix.amount else 0)
			t.isTrue(total <= MOST_SWAY, `{name} sways {total} studs off its line`)
		end
	end)
end
