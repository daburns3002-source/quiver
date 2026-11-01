--!strict
--[[
	The enemy designs, checked against the boxes the server actually sweeps.

	This exists because of a specific playtest complaint — "the hitboxes need
	to be more accurate to the look of the models" — and because the fix for
	it is the kind that rots. Designs are data, somebody will nudge a horn
	outwards, and nothing else in the toolchain can tell that a body has grown
	past the box that answers raycasts.

	Both directions are failures. A body wider than its hitbox produces shots
	that visibly connect and do nothing, which is the single most expensive
	bug this project has had. A body much smaller than its hitbox produces the
	opposite: shots that visibly miss and deal damage anyway.

	Bounds are computed from `EnemyModel.localCFrame`, the same call the
	builder places parts with, so a design that passes here is a design that
	is actually built where this thinks it is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyModel = require(ServerScriptService.Server.Enemies.EnemyModel)
local TestRunner = require(script.Parent.TestRunner)

--[[ Nothing may stick out past the hitbox at all. The tolerance is for
     floating point, not for artistic licence. ]]
local OVERFLOW_TOLERANCE = 1e-3

--[[ How much of each axis the body has to actually occupy. Below this the
     hitbox is catching shots that never looked like they connected. Height is
     the loosest, because a creature that crouches is a legitimate silhouette
     and a creature only half as wide as its box is not. ]]
local MINIMUM_FILL = Vector3.new(0.6, 0.7, 0.6)

--[[ Union of every part's rotated bounding box, in hitbox local space. Corners
     rather than sizes, so a rotated wedge is measured where it really is. ]]
local function designBounds(design: { EnemyDesigns.DesignPart }): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, spec in design do
		--[[ The blob shadow is a mark on the floor, not body: it is meant
		     to spread past the hitbox. ]]
		if spec.name == "Shadow" or EnemyModel.tucked(spec) then
			continue
		end
		local cf = EnemyModel.localCFrame(spec)
		local half = spec.size / 2

		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					min = Vector3.new(
						math.min(min.X, corner.X),
						math.min(min.Y, corner.Y),
						math.min(min.Z, corner.Z)
					)
					max = Vector3.new(
						math.max(max.X, corner.X),
						math.max(max.Y, corner.Y),
						math.max(max.Z, corner.Z)
					)
				end
			end
		end
	end

	return min, max
end

--[[ Every archetype, paired with the design keyed off its display name. ]]
local function archetypes(): {
	{
		name: string,
		config: Balance.EnemyConfig,
		design: { EnemyDesigns.DesignPart }?,
	}
}
	local out = {}

	for _, value in Balance.Enemies do
		--[[ Balance freezes its tables, so iteration hands back `unknown`.
		     Named here once rather than cast at every use below. ]]
		local config = value :: Balance.EnemyConfig
		table.insert(out, {
			name = config.displayName,
			config = config,
			-- as built: its design's parts and any imported model's
			design = EnemyModel.designFor(config),
		})
	end

	table.sort(out, function(a, b)
		return a.name < b.name
	end)

	return out
end

return function(t: TestRunner.Helper)
	--[[ A new archetype without a draft would ship as a bare grey box and
	     nobody would notice until a playtest. ]]
	t.test("every archetype has a design", function()
		for _, entry in archetypes() do
			t.notNil(entry.design, `{entry.name} has no entry in EnemyDesigns`)
		end
	end)

	t.test("no design reaches outside its own hitbox", function()
		for _, entry in archetypes() do
			local design = entry.design
			if not design then
				continue
			end

			local min, max = designBounds(design)
			local half = entry.config.hitboxSize / 2

			for _, axis in { "X", "Y", "Z" } do
				local limit = (half :: any)[axis]
				t.isTrue(
					(min :: any)[axis] >= -limit - OVERFLOW_TOLERANCE,
					`{entry.name} reaches past -{axis} of its hitbox`
				)
				t.isTrue(
					(max :: any)[axis] <= limit + OVERFLOW_TOLERANCE,
					`{entry.name} reaches past +{axis} of its hitbox`
				)
			end
		end
	end)

	t.test("no design rattles around inside its hitbox", function()
		for _, entry in archetypes() do
			local design = entry.design
			if not design then
				continue
			end

			local min, max = designBounds(design)
			local span = max - min
			local size = entry.config.hitboxSize

			for _, axis in { "X", "Y", "Z" } do
				local fill = (span :: any)[axis] / (size :: any)[axis]
				t.isTrue(
					fill >= (MINIMUM_FILL :: any)[axis],
					`{entry.name} fills only {math.floor(fill * 100)}% of its hitbox on {axis}`
				)
			end
		end
	end)

	--[[ The telegraph is the whole counterplay for two archetypes. A design
	     whose parts all opted out of tinting would wind up invisibly. ]]
	t.test("every design has something that can flash", function()
		for _, entry in archetypes() do
			local design = entry.design
			if not design then
				continue
			end

			local tintable = 0
			for _, spec in design do
				if spec.tint ~= false then
					tintable += 1
				end
			end

			t.isTrue(tintable > 0, `{entry.name} has no part that responds to a telegraph`)
		end
	end)

	--[[ A design keyed to a name no archetype uses is dead data that reads as
	     live. It would never be built and nothing else would say so.

	     A benched archetype's design is not dead: it has no room yet, but
	     it is built and `DebugSpawnEnemy` stands it up in Studio, which is
	     the only way to look at it. A typo still fails. ]]
	t.test("no design is keyed to an archetype that does not exist", function()
		local known: { [string]: boolean } = {}
		for _, value in Balance.Enemies do
			local config = value :: Balance.EnemyConfig
			known[config.displayName] = true
		end
		for _, config in Balance.Benched do
			known[config.displayName] = true
		end

		local function check(designs: any)
			for key in designs do
				local name = key :: string
				t.isTrue(known[name], `EnemyDesigns.{name} matches no archetype`)
			end
		end
		check(EnemyDesigns.Imported)
		for key, value in EnemyDesigns do
			--[[ Tables are the designs; the tag strings beside them are
			     not, and the imported models are checked above. ]]
			if typeof(value) == "table" and key ~= "Imported" then
				local name = key :: string
				t.isTrue(known[name], `EnemyDesigns.{name} matches no archetype`)
			end
		end
	end)

	--[[ Shade is a multiplier on the archetype colour. Zero is black and
	     negatives clamp to black, either of which is a typo rather than a
	     choice. ]]
	t.test("every part has a usable shade", function()
		for _, entry in archetypes() do
			local design = entry.design
			if not design then
				continue
			end

			for _, spec in design do
				t.isTrue(
					spec.shade > 0 and spec.shade <= 2,
					`{entry.name}.{spec.name} has a shade of {spec.shade}`
				)
			end
		end
	end)
end
