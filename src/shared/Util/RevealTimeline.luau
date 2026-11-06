--!strict
--[[
	One egg hatch's or chest opening's clock (`Config/Reveal`), pure, so
	`UI/Reveal` draws from it and `tests/RevealTimeline.spec` pins it: the
	best rarity in the press picks the build-up, every prize bursts in turn,
	the opening sound starts so its burst lands on the first one, and a rare
	pull holds until its reveal sound has played.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Reveal = require(ReplicatedStorage.Shared.Config.Reveal)

local RevealTimeline = {}

export type Kind = "egg" | "crate"

export type Timeline = {
	--[[ The press's best rarity and its tier. ]]
	top: string,
	tier: Reveal.Tier,
	drop: number,
	settle: number,
	--[[ When each crack appears (a chest's padlocks pop on the second). ]]
	cracks: { number },
	--[[ Each prize's burst, in order; `burst` the first and `last` the last. ]]
	bursts: { number },
	burst: number,
	last: number,
	banner: number,
	leave: number,
	done: number,
	--[[ The opening sound and when it starts. ]]
	sound: string,
	soundAt: number,
	--[[ The rare reveal's sound and when, for an Epic or better. ]]
	rareSound: string?,
	rareAt: number?,
}

--[[ The best of `rarities`, Common if none is known. ]]
function RevealTimeline.top(rarities: { string }): string
	local best, rank = "Common", 0
	for _, name in rarities do
		local rarity = Rarities.byName[name]
		if rarity and rarity.tier > rank then
			best, rank = name, rarity.tier
		end
	end
	return best
end

function RevealTimeline.build(kind: Kind, rarities: { string }): Timeline
	local beats = Reveal.egg
	local top = RevealTimeline.top(rarities)
	local tier = Reveal.tiers[top] or Reveal.tiers.Common
	local burst = beats.burst + tier.build
	local bursts = {}
	for index = 1, math.max(1, #rarities) do
		bursts[index] = burst + (index - 1) * beats.stagger
	end
	local last = bursts[#bursts]
	-- the first crack comes earlier the longer the build, the last two stay
	-- on the sound's ticks
	local cracks = {}
	for index, before in beats.cracks do
		cracks[index] = burst - before - (if index == 1 then tier.build * 0.6 else 0)
	end
	local soundBurst = if kind == "crate" then Reveal.crate.soundBurst else beats.soundBurst
	local jingle = if kind == "crate" then Reveal.crate.jingle else beats.jingle
	local soundAt = burst - soundBurst
	local rare = false
	for _, name in rarities do
		rare = rare or Reveal.rare[name] == true
	end
	local rareAt = if rare then soundAt + jingle else nil
	local banner = last + beats.banner
	local leave = banner + beats.hold + tier.hold
	if rareAt then
		leave = math.max(leave, rareAt + 1.2)
	end
	return {
		top = top,
		tier = tier,
		drop = beats.drop,
		settle = beats.settle,
		cracks = cracks,
		bursts = bursts,
		burst = burst,
		last = last,
		banner = banner,
		leave = leave,
		done = leave + beats.fade,
		sound = if kind == "crate" then "crate_open" else "egg_hatch",
		soundAt = soundAt,
		rareSound = if rare
			then (if top == "Mythic" then "mythic_reveal" else "reveal_rare")
			else nil,
		rareAt = rareAt,
	}
end

--[[ Where a tap at `t` jumps to: the bursts, then the screen leaving, then
     closed. ]]
function RevealTimeline.skip(timeline: Timeline, t: number): number
	if t < timeline.burst then
		return timeline.burst
	elseif t < timeline.leave then
		return timeline.leave
	end
	return timeline.done
end

return RevealTimeline
