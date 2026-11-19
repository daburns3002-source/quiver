--!strict
--[[
	How a chance is printed wherever something random can be paid for: the
	hatchery's and the blacksmith's tiles (`UI/HatchStand`) and an egg's
	odds before the Starter Pack is bought (`UI/EggOdds`).

	Roblox's paid random items policy (create.roblox.com/docs/production/
	monetization/paid-random-items, read 2026-11-19): odds as percentages,
	every outcome shown before the purchase, and either summing to exactly
	100% or rounded finely with a line that says so. So a chance is printed
	to four significant figures (59.18%, 28.57%, 1.020%, 0.1000%) and
	`ROUNDED` goes under every list of them (owner, 2026-11-19: "Yes to all
	three").
]]

local OddsText = {}

--[[ The figures a chance is printed to. ]]
OddsText.FIGURES = 4

--[[ The line under every list of printed chances. ]]
OddsText.ROUNDED = "ODDS ARE ROUNDED, SO THEY MAY NOT ADD UP TO EXACTLY 100%"

--[[ `chance` (0 to 1) as a percentage to `OddsText.FIGURES` significant
     figures: "59.18%". Nothing is "0%" unless it is impossible. ]]
function OddsText.percent(chance: number): string
	local p = chance * 100
	if p ~= p or p <= 0 then
		return "0%"
	end
	local whole = math.floor(math.log10(p)) + 1
	local places = math.max(0, OddsText.FIGURES - whole)
	-- rounding up into the next power of ten (9.99996 to 10.000) adds a figure: drop it
	if places > 0 and (tonumber(string.format(`%.{places}f`, p)) :: number) >= 10 ^ whole then
		places -= 1
	end
	return string.format(`%.{places}f`, p) .. "%"
end

return table.freeze(OddsText)
