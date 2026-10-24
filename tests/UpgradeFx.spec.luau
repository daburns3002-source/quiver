--!strict
--[[
	The upgrade cards' effects (`Fx/Upgrades`, docs/effects/): the data the
	game builds and plays them from, held to the owner's two calls.

	- Phones first (owner, 2026-10-24): every effect is a handful of parts
	  (`Balance.UpgradeFx.maxParts`), because each copy's parts are posed
	  every frame. A raw Claude Design export is one part per cube (Heavy
	  Blade was 771); assets/models/effects/optimise_effect.py merges them.
	- Ricochet, Front Arrow, Double Shot and Multishot keep their upgrades
	  but have no effect: their arrows are the effect.

	And the plumbing: every import has its clip data and every clip data its
	import, every part rides a joint the data has, and every cap names an
	effect that exists.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local TestRunner = require(script.Parent.TestRunner)

local K = Balance.UpgradeFx

local function modules(folderName: string): { [string]: any }
	local out: { [string]: any } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild(folderName)
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") and string.sub(module.Name, 1, 2) == "Fx" then
				out[module.Name] = (require :: any)(module)
			end
		end
	end
	return out
end

return function(t: TestRunner.Helper)
	local imported = modules("ImportedModels")
	local clips = modules("ModelClips")

	t.test("every effect's import has its clip data, and every clip data its import", function()
		for key in imported do
			t.notNil(clips[key], `{key} is imported but has no ModelClips data`)
		end
		for key in clips do
			t.notNil(imported[key], `{key} has clip data but no import`)
		end
	end)

	t.test("every effect is a handful of parts, so phones can pose them", function()
		for key, parts in imported do
			t.isTrue(
				#parts <= K.maxParts,
				`{key} is {#parts} parts, over {K.maxParts}: run it through optimise_effect.py`
			)
		end
		for key, data in clips do
			local count = 0
			for _ in (data :: ModelClip.Model).parts do
				count += 1
			end
			t.isTrue(count <= K.maxParts, `{key}'s clip data has {count} parts, over {K.maxParts}`)
		end
	end)

	t.test("every part rides a joint its clip data has", function()
		for key, data in clips do
			local model = data :: ModelClip.Model
			local joints: { [string]: boolean } = { [""] = true }
			for _, joint in model.joints do
				joints[joint.name] = true
			end
			for name, part in model.parts do
				t.isTrue(
					joints[part.joint] == true,
					`{key}.{name} rides {part.joint}, which it lacks`
				)
			end
		end
	end)

	t.test("the four projectile cards have no effect of their own", function()
		for _, id in { "Ricochet", "FrontArrow", "DoubleShot", "Multishot" } do
			t.isTrue(imported[`Fx{id}`] == nil, `Fx{id} is imported`)
			t.isTrue(clips[`Fx{id}`] == nil, `Fx{id} has clip data`)
		end
	end)

	t.test("every cap names an effect that exists", function()
		for key: string in K.caps :: { [string]: number } do
			t.notNil(clips[key], `a cap for {key}, which is not an effect`)
		end
	end)
end
