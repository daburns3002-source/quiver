--!strict
--[[
	The pets' attack pieces (`Config/PetAttacks`): each attack belongs to a
	real pet, names an effect the pipeline can build (an `FxPet` model, so
	`Server/Fx/UpgradeEffects` builds it once imported) and a kind
	`Fx/PetAttackFx` knows how to play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
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
				if shot.sweep then
					t.isTrue(
						shot.kind == "Reach" or shot.kind == "Owner",
						`{key}: only a Reach or an Owner piece turns ({shot.kind} would not)`
					)
				end
			end
		end
	end)

	--[[ The six reworked Thornwood pets (owner, 2026-10-31) each got
	     something no Mossy Glade pet does, and a trick nothing shows is a
	     trick a player never learns. ]]
	t.test("a pet that bursts thorns off its shell shows them", function()
		for key, spec in PetCombat.pets do
			if spec.reflect then
				t.notNil((PetAttacks :: any)[key], `{key} bursts thorns and shows nothing`)
			end
		end
	end)

	t.test("a ring of thorns is drawn as long as it turns", function()
		for key, spec in PetCombat.pets do
			local aura = spec.aura
			if not aura then
				continue
			end
			local ring = nil
			for _, shot in (PetAttacks :: any)[key] or {} do
				if shot.kind == "Owner" and (shot.life or 0) >= aura.duration then
					ring = shot
				end
			end
			t.notNil(ring, `{key}: no Owner piece lasting the ring's {aura.duration}s`)
		end
	end)

	--[[ A chained hold is laid on at once (`Combat/PetCombat`), where a
	     projectile pet's first blow waits for its piece to arrive
	     (`Shared/Combat/PetShots`). A chain pet that threw one would
	     therefore root the second enemy before it hit the first, which looks
	     like a bug and is one; none does, and this is what keeps it that
	     way. ]]
	t.test("a pet whose hold chains does not throw its attack", function()
		for key, spec in PetCombat.pets do
			if not spec.chain then
				continue
			end
			local first = ((PetAttacks :: any)[key] or {})[1]
			t.notNil(first, `{key} chains a hold and shows nothing`)
			t.isTrue(
				first ~= nil and first.kind ~= "Projectile",
				`{key}: a chained hold would land before the blow it came from`
			)
		end
	end)

	--[[ A ring bites several times a second (`Combat/PetCombat`), and does
	     damage only for that reason: a slow, a hold, a bleed or a heal on
	     hit refreshed on every bite would be worth many times what the pet
	     is priced at. Pinned here so a later retune cannot quietly add
	     one. ]]
	t.test("a pet with a ring of thorns carries nothing the ring would refresh", function()
		for key, spec in PetCombat.pets do
			if not spec.aura then
				continue
			end
			t.isNil(spec.slow, `{key}: a ring would hold the slow up`)
			t.isNil(spec.root, `{key}: a ring would hold the room still`)
			t.isNil(spec.bleed, `{key}: a ring would stack thorns every bite`)
			t.isNil(spec.burn, `{key}: a ring would keep the burn alight`)
			t.isNil(spec.mark, `{key}: a ring would keep the mark fresh`)
			t.isNil(spec.healPerHit, `{key}: a ring would never stop healing`)
		end
	end)
end
