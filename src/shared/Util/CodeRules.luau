--!strict
--[[
	The CODES box's rules (`Config/Codes`, `Data/Codes`): what typed text is
	a code word, whether a code may be used today by this player, and the
	words said back. Pure, so `tests/CodeRules.spec` drives it with made-up
	lists and days. The real list is the server's (`Data/CodeList`) and is
	only ever handed in.

	Days are whole UTC days since 1970, as the rewards count them
	(`RewardRules.day`).

	A like-goal code (`likes`) does not exist until the game has that many
	likes (the count the owner sets, `Data/LikeGoal`): until then it answers
	as an unknown code, so a future word cannot be found out by trying it.
]]

local Config = require(script.Parent.Parent.Config.Codes)

local CodeRules = {}

export type Prize = { coins: number?, gems: number?, eggs: number?, crates: number? }
--[[ `likes`: the game's likes before it works, for a like-goal code. ]]
export type Code = { prize: Prize, expires: string?, likes: number? }
export type Result = "Ok" | "Unknown" | "Expired" | "Used"

--[[ The prize's parts in the order they are said. ]]
local PARTS: { { key: string, one: string, many: string } } = {
	{ key = "coins", one = "COIN", many = "COINS" },
	{ key = "gems", one = "GEM", many = "GEMS" },
	{ key = "eggs", one = "EGG", many = "EGGS" },
	{ key = "crates", one = "CRATE", many = "CRATES" },
}

--[[ Typed text as a code word: capitals, spaces dropped; nil when it is not
     a string, is empty, is too long, or holds anything but letters and
     digits. ]]
function CodeRules.normalise(text: unknown): string?
	if type(text) ~= "string" or #text > Config.maxLength * 4 then
		return nil
	end
	local word = string.upper((string.gsub(text, "%s", "")))
	if #word == 0 or #word > Config.maxLength or string.find(word, "[^%w]") then
		return nil
	end
	return word
end

--[[ "YYYY-MM-DD" as a UTC day number (days since 1970-01-01), nil if it is
     not a real date. Civil-from-days, so no clock is read. ]]
function CodeRules.day(date: unknown): number?
	if type(date) ~= "string" then
		return nil
	end
	local ys, ms, ds = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not ys then
		return nil
	end
	local y, m, d = tonumber(ys) :: number, tonumber(ms) :: number, tonumber(ds) :: number
	local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
	local lengths = { 31, if leap then 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if m < 1 or m > 12 or d < 1 or d > lengths[m] then
		return nil
	end
	-- days from 1970-01-01 (Howard Hinnant's days_from_civil)
	local yy = if m <= 2 then y - 1 else y
	local era = yy // 400
	local yoe = yy - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

--[[ Whether a list entry is well formed: a prize of whole amounts, at
     least one above 0, nothing else in it, and an expiry that is a date. ]]
function CodeRules.valid(code: unknown): boolean
	if type(code) ~= "table" then
		return false
	end
	local entry = code :: any
	if type(entry.prize) ~= "table" then
		return false
	end
	if entry.expires ~= nil and CodeRules.day(entry.expires) == nil then
		return false
	end
	local likes = entry.likes
	if likes ~= nil and (type(likes) ~= "number" or likes < 1 or likes % 1 ~= 0) then
		return false
	end
	local known: { [string]: boolean } = {}
	for _, part in PARTS do
		known[part.key] = true
	end
	local any = false
	for key, n in entry.prize :: { [any]: any } do
		if not known[key] or type(n) ~= "number" or n < 0 or n % 1 ~= 0 then
			return false
		end
		any = any or n > 0
	end
	return any
end

--[[ Whether `word` (already normalised) may be used by a player who has
     used `used`, today, with the game at `likes` likes: Unknown if no such
     code (or a broken entry, or a like goal not reached yet), Used if this
     player has had it, Expired if its last day is past, else Ok with the
     code. ]]
function CodeRules.check(
	list: { [string]: Code },
	used: { [string]: boolean },
	word: string,
	today: number,
	likes: number
): (Result, Code?)
	local code = list[word]
	if not code or not CodeRules.valid(code) or (code.likes and likes < code.likes) then
		return "Unknown", nil
	end
	if used[word] then
		return "Used", nil
	end
	local last = if code.expires then CodeRules.day(code.expires) else nil
	if last and today > last then
		return "Expired", nil
	end
	return "Ok", code
end

--[[ The like goal as it stands at `likes`: the next goal not reached yet,
     and the word of the highest one reached, leaving out expired codes and
     broken entries. Either may be nil. ]]
function CodeRules.likeGoal(
	list: { [string]: Code },
	likes: number,
	today: number
): (number?, string?)
	local nextGoal: number? = nil
	local newest: string? = nil
	local newestAt = 0
	for word, code in list do
		local goal = code.likes
		local last = if code.expires then CodeRules.day(code.expires) else nil
		if goal and CodeRules.valid(code) and not (last and today > last) then
			if likes >= goal then
				if goal > newestAt then
					newest, newestAt = word, goal
				end
			elseif not nextGoal or goal < nextGoal then
				nextGoal = goal
			end
		end
	end
	return nextGoal, newest
end

--[[ A whole number with commas, "10,000". ]]
function CodeRules.commas(n: number): string
	local digits = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

--[[ The like goal's line (`Config/Codes.likeGoal`), "" when there is no
     goal at all. ]]
function CodeRules.likeLine(nextGoal: number?, newest: string?): string
	local words = Config.likeGoal
	if newest and nextGoal then
		return string.format(words.both, newest, CodeRules.commas(nextGoal))
	elseif newest then
		return string.format(words.reached, newest)
	elseif nextGoal then
		return string.format(words.next, CodeRules.commas(nextGoal))
	end
	return ""
end

--[[ A prize in words, "500 COINS + 25 GEMS + 1 EGG". ]]
function CodeRules.prizeWords(prize: Prize): string
	local words = {}
	for _, part in PARTS do
		local n = (prize :: any)[part.key]
		if type(n) == "number" and n > 0 then
			table.insert(words, `{CodeRules.commas(n)} {if n == 1 then part.one else part.many}`)
		end
	end
	return table.concat(words, " + ")
end

--[[ What the box says for a result (`Config/Codes.answers`), or for
     "Empty" and "Slow", which the server decides before any check. ]]
function CodeRules.answer(result: string, prize: Prize?): string
	local line = (Config.answers :: { [string]: string })[result] or Config.answers.Unknown
	if result == "Ok" then
		return string.format(line, if prize then CodeRules.prizeWords(prize) else "")
	end
	return line
end

return CodeRules
