--!strict
--[[
	The pets' attack pieces (`Config/PetAttacks`): each attack belongs to a
	real pet, names an effect the pipeline can build (an `FxPet` model, so
	`Server/Fx/UpgradeEffects` builds it once imported) and a kind
	`Fx/PetAttackFx` knows how to play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local TestRunner = require(script.Parent.TestRunner)

local KINDS =
	{ Projectile = true, Reach = true, Ground = true, Overhead = true, Owner = true, Hold = true }

return function(t: TestRunner.Helper)
	t.test("every attack belongs to a pet the preview can show", function()
		local pets = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
		for key in PetAttacks do
			t.notNil(pets and pets:FindFirstChild(key), `{key} has clips (Config/ModelClips)`)
		end
	end)

	t.test("every piece is an FxPet effect of a known kind, fired in time", function()
		for key, shots in PetAttacks do
			for _, shot in shots do
				t.isTrue(
					string.sub(shot.effect, 1, 5) == "FxPet",
					`{key}: {shot.effect} is an FxPet model`
				)
				t.isTrue(KINDS[shot.kind] == true, `{key}: {shot.kind} is a kind PetAttackFx plays`)
				t.isTrue(shot.at >= 0 and shot.at < 3, `{key}: fires within its clip`)
				if shot.impact then
					t.isTrue(
						string.sub(shot.impact.effect, 1, 5) == "FxPet",
						`{key}: its impact is an FxPet model`
					)
				end
			end
		end
	end)
end
