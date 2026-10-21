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
}

local medium: Tier = {
	name = "Medium",
	maxRenderedProjectiles = 160,
	maxDamageNumbers = 16,
	enableShadows = false,
	enableScreenShake = true,
	projectileIsRound = true,
	projectileTrails = true,
}

local high: Tier = {
	name = "High",
	maxRenderedProjectiles = 400,
	maxDamageNumbers = 32,
	enableShadows = true,
	enableScreenShake = true,
	projectileIsRound = true,
	projectileTrails = true,
}

local DeviceTiers = {
	Low = low,
	Medium = medium,
	High = high,
}

return table.freeze(DeviceTiers)
