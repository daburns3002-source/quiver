--!strict
--[[
	What a run's coins are worth beyond the passes (`Config/Rewards.streak`
	and `friendCoins`; owner, 2026-11-14: "there should be more rewards for
	players"), pure, so the server pays with it (`RunSession.payEarned`) and
	`tests/RunBonus.spec` pins it.

	**A win streak.** Each level won in a row adds a tenth to the next
	level's kill and clear coins, up to a half more. The streak is the
	player's own, saved (`SaveSchema.winStreak`, version 19), and it is **on
	the line from the moment a level starts**: the server takes it out of
	the save as the run begins and writes it back, one longer, only on the
	win (`Run/RoomController`). So losing, leaving for the lobby and leaving
	the game all end it, and there is no way to keep one by quitting a run
	that is going badly. Only a campaign level counts: the tutorial and
	Endless neither use a streak nor end one.

	**A friend.** A run in a party of two or more pays a fifth more coins to
	everyone in it. The party's size is locked as the run starts
	(`Util/Coop`), so it is not lost when a friend leaves part-way, and the
	fight was made bigger for two all the same.

	Both add to the passes' scale, as the passes add to each other
	(`StoreRules.coinScale`): nothing multiplies.
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)

local RunBonus = {}

--[[ The longest streak kept: far past where the bonus stops growing, so
     the number shown can keep climbing. ]]
RunBonus.LONGEST = 999

local function whole(n: number): number
	return if n ~= n then 0 else math.max(0, math.floor(n))
end

--[[ The share of coins a streak of `wins` adds: 0 with none. ]]
function RunBonus.streak(wins: number): number
	return math.min(Rewards.streak.cap, whole(wins) * Rewards.streak.step)
end

--[[ The share of coins a party of `size` adds: 0 alone. ]]
function RunBonus.friend(size: number): number
	return if whole(size) >= 2 then Rewards.friendCoins else 0
end

--[[ What a run's kill and clear coins are multiplied by: the passes'
     scale with the streak's and the friend's shares added. ]]
function RunBonus.scale(passes: number, wins: number, size: number): number
	return passes + RunBonus.streak(wins) + RunBonus.friend(size)
end

--[[ The streak after a win that began with `wins` in a row. ]]
function RunBonus.won(wins: number): number
	return math.min(RunBonus.LONGEST, whole(wins) + 1)
end

--[[ A share as the screen says it: 0.3 is "+30%". ]]
function RunBonus.percent(share: number): string
	return string.format("+%d%%", math.floor(share * 100 + 0.5))
end

--[[ What to tell a player as a level starts, a line for each bonus they
     have; none with neither. ]]
function RunBonus.lines(wins: number, size: number): { string }
	local out = {}
	local streak = RunBonus.streak(wins)
	if streak > 0 then
		table.insert(
			out,
			string.format("WIN STREAK %d: %s COINS", whole(wins), RunBonus.percent(streak))
		)
	end
	local friend = RunBonus.friend(size)
	if friend > 0 then
		table.insert(out, string.format("FRIEND BONUS: %s COINS", RunBonus.percent(friend)))
	end
	return out
end

return RunBonus
