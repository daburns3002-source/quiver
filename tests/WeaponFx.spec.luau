--!strict
--[[
	Every weapon's attack is its own (`Config/WeaponFx`; owner, 2026-11-08):
	no two bows or staves fire the same shot, no two blades cut the same
	cleave, and a Legendary or Mythic's always glows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local TestRunner = require(script.Parent.TestRunner)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons) :: any

--[[ The weapons a class holds (`Config/Sandbox` lists every one), a pair of
     bows being drawn as the bow it pairs. ]]
local function ofClass(class: string): { string }
	local out = {}
	for _, entry in Sandbox.weapons do
		if entry.class == class and not Weapons[entry.weapon].dualOf then
			table.insert(out, entry.weapon)
		end
	end
	table.sort(out)
	return out
end

local function colourKey(colour: Color3): string
	return colour:ToHex()
end

local function shape(key: string, look: WeaponFx.Look): string
	local own = Weapons[key].bolt
	local mesh = if look.shape == "Bolt" and own then own.meshId else look.shape
	local moves = {}
	for _, name in { "wobble", "bob", "helix", "sparkle" } do
		if (look :: any)[name] then
			table.insert(moves, name)
		end
	end
	local spins = look.spin.Magnitude > 0
	local arms = look.arms and #look.arms or 0
	return `{mesh}|{arms}|{spins}|{table.concat(moves, ",")}`
end

local function glows(key: string): boolean
	local rarity = (WeaponStats.weapons :: any)[key].rarity
	return rarity == "Legendary" or rarity == "Mythic"
end

return function(t: TestRunner.Helper)
	for _, class in { "Ranger", "Arcanist" } do
		t.test(`every {class} shot is its own`, function()
			local shapes: { [string]: string } = {}
			local colours: { [string]: string } = {}
			local weapons = ofClass(class)
			t.isTrue(#weapons >= 15, `only {#weapons} {class} weapons`)
			for _, key in weapons do
				local look = WeaponFx.shots[key]
				t.notNil(look, `{key} has no shot`)
				local mark = shape(key, look)
				t.isNil(shapes[mark], `{key} flies as {shapes[mark] or "?"} does ({mark})`)
				shapes[mark] = key
				local hue = colourKey(look.colour)
				t.isNil(colours[hue], `{key} is the colour of {colours[hue] or "?"}`)
				colours[hue] = key
			end
		end)

		t.test(`every Legendary and Mythic {class} shot glows`, function()
			for _, key in ofClass(class) do
				if glows(key) then
					t.notNil(Weapons[key].shotGlow, `{key}'s shots do not glow`)
				end
			end
		end)
	end

	t.test("every blade cuts its own cleave", function()
		local colours: { [string]: string } = {}
		local cuts: { [string]: string } = {}
		local blades = ofClass("Warden")
		t.isTrue(#blades >= 16, `only {#blades} blades`)
		for _, key in blades do
			local cleave = WeaponFx.cleaves[key]
			t.notNil(cleave, `{key} has no cleave`)
			local hue = colourKey(cleave.colour[1])
			t.isNil(colours[hue], `{key} is the colour of {colours[hue] or "?"}`)
			colours[hue] = key
			local motes = cleave.motes
			local mark = `{cleave.tail}|{cleave.taper}|{motes and motes.form or "none"}`
			t.isNil(cuts[mark], `{key} cuts as {cuts[mark] or "?"} does`)
			cuts[mark] = key
		end
	end)

	t.test("every Legendary and Mythic blade's cleave glows", function()
		for _, key in ofClass("Warden") do
			if glows(key) then
				t.notNil(Weapons[key].trailGlow, `{key}'s cleave does not glow`)
			end
		end
	end)

	t.test("every look names a weapon there is", function()
		for key in WeaponFx.shots do
			t.notNil(Weapons[key], `{key} is no weapon`)
		end
		for key in WeaponFx.cleaves do
			t.notNil(Weapons[key], `{key} is no weapon`)
		end
	end)
end
