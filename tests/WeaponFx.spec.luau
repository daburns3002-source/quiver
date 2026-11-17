--!strict
--[[
	Every weapon's attack is its own (`Config/WeaponFx`; owner, 2026-11-08):
	no two bows or staves fire the same shot, no two blades cut the same
	cleave, and a Legendary or Mythic's always glows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
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

	--[[ A class that swings: the Warden's blades, and the Assassin's
	     daggers (22 since 2026-11-17). Within a class no two cut alike. ]]
	for class: string, least: number in { Warden = 16, Assassin = 22 } :: { [string]: number } do
		t.test(`every {class} weapon cuts its own cleave`, function()
			local colours: { [string]: string } = {}
			local cuts: { [string]: string } = {}
			local blades = ofClass(class)
			t.isTrue(#blades >= least, `only {#blades} of the {class}'s`)
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

		t.test(`every Legendary and Mythic {class} weapon's cleave glows`, function()
			for _, key in ofClass(class) do
				if glows(key) then
					t.notNil(Weapons[key].trailGlow, `{key}'s cleave does not glow`)
					--[[ In hand too. Held to the Assassin's only: the Drowned
					     Village's three Legendaries have a trail glow and no
					     aura in hand (seen 2026-11-17, not this change's). ]]
					if class == "Assassin" then
						t.notNil(Weapons[key].aura, `{key} does not glow in hand`)
					end
				end
			end
		end)
	end

	--[[ A dagger is held in both hands, whichever pair it is, and a
	     Legendary's or Mythic's effect is a card the Assassin draws that no
	     other of its weapons carries. ]]
	t.test("every dagger is a pair, and no two carry the same effect", function()
		local carried: { [string]: string } = {}
		for _, key in ofClass("Assassin") do
			t.notNil(Weapons[key].offhand, `{key} is held in one hand only`)
			local stats = (WeaponStats.weapons :: any)[key]
			if glows(key) then
				t.notNil(stats.innate, `{key} has no effect`)
				for card in stats.innate do
					local ability = Abilities.byId[card]
					t.notNil(ability, `{key} carries {card}, which is no card`)
					local classes = ability and ability.classes
					t.isTrue(
						classes == nil or table.find(classes, "Assassin") ~= nil,
						`{key} carries {card}, which the Assassin cannot draw`
					)
					t.isNil(carried[card], `{key} carries {card}, as {carried[card] or "?"} does`)
					carried[card] = key
				end
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
