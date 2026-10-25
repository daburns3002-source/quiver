--!strict
--[[
	Device tiering. A phone and a desktop run the same code with different
	numbers — never different code paths.

	Resolved once on the client at join and sent nowhere: nothing
	gameplay-affecting may read from this, only presentation budgets.
]]

export type TierName = "Low" | "Medium" | "High"

export type Tier = {
	name: TierName,
	-- Most projectiles rendered at once. Beyond this, new ones are skipped
	-- visually; the server still simulates every one of them.
	maxRenderedProjectiles: number,
	-- Most damage numbers on screen at once.
	maxDamageNumbers: number,
	enableShadows: boolean,
	enableScreenShake: boolean,
	-- Projectile mesh detail. Low tier uses blocks.
	projectileIsRound: boolean,
	--[[ Whether projectiles stream a trail behind them. A trail is one extra
	     rendered object per live shot, which is the last thing a phone needs
	     once Phase 3 multiplies volley sizes. ]]
	projectileTrails: boolean,
	--[[ Flame particles a second on a burning enemy. Never zero: on the
	     lowest tier a burning enemy still has to look different from one
	     that is not, or Blaze is invisible there. ]]
	burnParticleRate: number,
	--[[ Whether the soft bloom over glowing things is on. Off on the lowest
	     tier, where a full-screen post effect is the first thing to cut. ]]
	enableBloom: boolean,
	--[[ Sparkles a second shed by each enemy orb. Zero turns them off. ]]
	orbSparkleRate: number,
	--[[ Share of the end screens' confetti, sparks and embers drawn. Never
	     zero: a Victory with no confetti at all reads as broken. ]]
	endScreenParticleShare: number,
	--[[ Share of the Mythics' debris, embers and rock spikes drawn
	     (`Fx/MythicFx`). Never zero: a meteor that lands with nothing
	     thrown up reads as a miss. ]]
	mythicFxShare: number,
	--[[ Share of a boss's decorative cubes drawn (King Bloblin's debris,
	     dust, shockwave, goo); never his warnings. ]]
	bossFxShare: number,
	--[[ Share of the scenery's life drawn past the walls (falling leaves,
	     fireflies, butterflies, birds; `Fx/ForestAmbience`). Zero turns it
	     off: it is background, the first thing a phone can spare. ]]
	ambienceShare: number,
	--[[ Most cubes of slime residue alive at once (`Fx/SlimeResidue`).
	     The parts are built once at this count and reused, the oldest
	     first, so a long fight never allocates more. ]]
	maxSlimeResidue: number,
	--[[ Most upgrade-card effects playing at once (`Fx/Upgrades/UpgradeFx`),
	     one-shots only: a persistent tell (Strength's cuffs, Iron Skin's
	     plates) is the player's own and is always drawn. Past it a new
	     one-shot is skipped. ]]
	maxUpgradeFx: number,
}

--[[
	Declared one at a time so each is checked against Tier. Collecting them into
	a `{ [TierName]: Tier }` map instead would type-check the values but make
	them unreadable by literal key under strict mode.
]]
local low: Tier = {
	name = "Low",
	maxRenderedProjectiles = 60,
	maxDamageNumbers = 8,
	enableShadows = false,
	enableScreenShake = true,
	projectileIsRound = false,
	projectileTrails = false,
	burnParticleRate = 4,
	enableBloom = false,
	orbSparkleRate = 0,
	endScreenParticleShare = 0.5,
	mythicFxShare = 0.5,
	bossFxShare = 0.5,
	ambienceShare = 0.4,
	maxSlimeResidue = 24,
	maxUpgradeFx = 10,
}

local medium: Tier = {
	name = "Medium",
	maxRenderedProjectiles = 160,
	maxDamageNumbers = 16,
	enableShadows = false,
	enableScreenShake = true,
	projectileIsRound = true,
	projectileTrails = true,
	burnParticleRate = 10,
	enableBloom = true,
	orbSparkleRate = 8,
	endScreenParticleShare = 0.75,
	mythicFxShare = 0.75,
	bossFxShare = 0.75,
	ambienceShare = 0.7,
	maxSlimeResidue = 64,
	maxUpgradeFx = 20,
}

local high: Tier = {
	name = "High",
	maxRenderedProjectiles = 400,
	maxDamageNumbers = 32,
	enableShadows = true,
	enableScreenShake = true,
	projectileIsRound = true,
	projectileTrails = true,
	burnParticleRate = 20,
	enableBloom = true,
	orbSparkleRate = 16,
	endScreenParticleShare = 1,
	mythicFxShare = 1,
	bossFxShare = 1,
	ambienceShare = 1,
	maxSlimeResidue = 128,
	maxUpgradeFx = 32,
}

local DeviceTiers = {
	Low = low,
	Medium = medium,
	High = high,
}

return table.freeze(DeviceTiers)
