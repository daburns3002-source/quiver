--!strict
--[[
	The egg hatch's and chest opening's clock (`Util/RevealTimeline`,
	`Config/Reveal`): every rarity has a tier, a better pull builds longer and
	shakes harder, the beats run in order, the opening sound's burst lands on
	the first burst, a Mythic gets its own reveal sound, and a tap only moves
	forward.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Reveal = require(ReplicatedStorage.Shared.Config.Reveal)
local RevealTimeline = require(ReplicatedStorage.Shared.Util.RevealTimeline)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every rarity has a tier, building and shaking more as it climbs", function()
		local build, shake = -1, 0
		for _, rarity in Rarities.list do
			local tier = Reveal.tiers[rarity.name]
			t.notNil(tier, rarity.name)
			t.isTrue(tier.build >= build and tier.shake >= shake, rarity.name)
			build, shake = tier.build, tier.shake
		end
	end)

	-- owner's rule: every Legendary and Mythic glows
	t.test("Legendary and Mythic glow", function()
		t.isTrue(Reveal.tiers.Legendary.glow and Reveal.tiers.Mythic.glow)
	end)

	t.test("the beats run in order, for every rarity and both kinds", function()
		local function check(kind: RevealTimeline.Kind)
			for _, rarity in Rarities.list do
				local line = RevealTimeline.build(kind, { "Common", rarity.name, "Common" })
				t.equal(line.top, rarity.name)
				t.isTrue(line.drop < line.settle and line.settle <= line.cracks[1], rarity.name)
				for n = 2, #line.cracks do
					t.isTrue(line.cracks[n - 1] < line.cracks[n], rarity.name)
				end
				t.isTrue(line.cracks[#line.cracks] < line.burst, rarity.name)
				t.equal(#line.bursts, 3)
				t.isTrue(line.bursts[1] < line.bursts[3] and line.last == line.bursts[3])
				t.isTrue(line.last < line.banner and line.banner < line.leave, rarity.name)
				t.isTrue(line.leave < line.done, rarity.name)
				if line.rareAt then
					t.isTrue(line.rareAt < line.leave, rarity.name)
				end
			end
		end
		check("egg")
		check("crate")
	end)

	t.test("the opening sound's burst lands on the first burst", function()
		local egg = RevealTimeline.build("egg", { "Legendary" })
		t.near(egg.soundAt + Reveal.egg.soundBurst, egg.burst, 1e-6)
		t.equal(egg.sound, "egg_hatch")
		local crate = RevealTimeline.build("crate", { "Rare" })
		t.near(crate.soundAt + Reveal.crate.soundBurst, crate.burst, 1e-6)
		t.equal(crate.sound, "crate_open")
	end)

	t.test("a Mythic builds longest and gets its own reveal sound", function()
		local mythic = RevealTimeline.build("egg", { "Common", "Mythic" })
		local legendary = RevealTimeline.build("egg", { "Legendary" })
		t.isTrue(mythic.burst > legendary.burst)
		t.equal(mythic.rareSound, "mythic_reveal")
		t.equal(legendary.rareSound, "reveal_rare")
		t.isNil(RevealTimeline.build("egg", { "Rare" }).rareSound)
	end)

	t.test("a tap only moves the clock forward, and ends it", function()
		local line = RevealTimeline.build("egg", { "Epic" })
		local at = 0
		for _ = 1, 3 do
			local next = RevealTimeline.skip(line, at)
			t.isTrue(next > at)
			at = next
		end
		t.equal(at, line.done)
	end)
end
