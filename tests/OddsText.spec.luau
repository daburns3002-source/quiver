--!strict
-- How a chance is printed where something random can be paid for
-- (`Util/OddsText`; Roblox's paid random items policy): four significant
-- figures, close to the real chance, and the printed odds of every egg and
-- every crate adding up to 100% but for the rounding the line owns up to.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local OddsText = require(ReplicatedStorage.Shared.Util.OddsText)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)

local function read(text: string): number
	return tonumber(string.match(text, "^([%d%.]+)%%$") or "") or -1
end

local function figures(text: string): number
	local digits = string.gsub(string.match(text, "^([%d%.]+)%%$") or "", "%.", "")
	return #(string.gsub(digits, "^0+", ""))
end

return function(t: TestRunner.Helper)
	t.test("a chance is printed to four figures, within half its last place", function()
		for _, chance in { 0.5918367, 0.2857142, 0.1122448, 0.0102040, 0.001, 0.99999, 1, 0.099996 } do
			local text = OddsText.percent(chance)
			local shown = read(text)
			t.isTrue(shown > 0, `{text} reads as a percentage`)
			t.equal(figures(text), OddsText.FIGURES, `{text} has four figures`)
			local place = 10 ^ (math.floor(math.log10(shown)) + 1 - OddsText.FIGURES)
			t.isTrue(math.abs(shown - chance * 100) <= place / 2 + 1e-9, `{text} is near {chance}`)
		end
	end)

	t.test("only an impossible outcome is printed as 0%", function()
		t.equal(OddsText.percent(0), "0%")
		t.isTrue(read(OddsText.percent(1e-7)) > 0, "a tiny chance still shows")
	end)

	t.test("every egg's printed odds add up to 100% but for the rounding", function()
		for _, egg in Eggs.list do
			for _, luck in { 1, 2, 3 } do
				local pool = EggRules.pool(egg.key, luck)
				if #pool == 0 then
					continue
				end
				local sum = 0
				for _, entry in pool do
					sum += read(OddsText.percent(entry.chance))
				end
				t.isTrue(math.abs(sum - 100) < 0.01 * #pool, `{egg.key} at luck {luck}: {sum}`)
			end
		end
	end)

	t.test("every crate's printed odds add up to 100% but for the rounding", function()
		for index in Shop.crates do
			for _, class in { "Ranger", "Arcanist", "Warden", "Assassin" } do
				local pool = ShopRules.cratePool(index, class)
				if #pool == 0 then
					continue
				end
				local sum = 0
				for _, entry in pool do
					sum += read(OddsText.percent(ShopRules.chance(index, entry, class)))
				end
				t.isTrue(math.abs(sum - 100) < 0.01 * #pool, `crate {index} {class}: {sum}`)
			end
		end
	end)

	t.test("the rounding line says the odds are rounded", function()
		t.isTrue(string.find(OddsText.ROUNDED, "ROUNDED", 1, true) ~= nil)
		t.isTrue(string.find(OddsText.ROUNDED, "100%", 1, true) ~= nil)
	end)
end
