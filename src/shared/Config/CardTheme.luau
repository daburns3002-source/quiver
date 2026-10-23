--!strict
--[[
	The upgrade card design's tokens: colours, fonts, sizes and timings
	(design_handoff_upgrade_cards, README "Design tokens", "The card" and
	"Motion spec"). Sizes are design pixels; the card is built at these and
	scaled as a whole per device.
]]

local rgb = Color3.fromRGB

local CardTheme = {
	colors = {
		--[[ Every outline, shadow and pill. ]]
		ink = rgb(27, 27, 43),
		panel = rgb(58, 123, 213),
		detailPanel = rgb(42, 95, 181),
		titleYellow = rgb(255, 225, 77),
		gold = rgb(255, 210, 63),
		legendGold = rgb(255, 207, 58),
		paleGold = rgb(255, 241, 179),
		choose = rgb(76, 209, 55),
		reroll = rgb(255, 176, 46),
		disabled = rgb(154, 163, 173),
		danger = rgb(255, 61, 61),
		mythicTitle = rgb(255, 59, 71),
		lightning = rgb(255, 42, 54),
		lightningCore = rgb(255, 214, 214),
		white = rgb(255, 255, 255),
	},

	fonts = {
		--[[ Headings, rarity labels, names, badges, buttons. ]]
		display = Enum.Font.LuckiestGuy,
		--[[ Descriptions, stat pills, other copy. ]]
		body = Enum.Font.FredokaOne,
	},

	card = {
		size = Vector2.new(134, 330),
		corner = 18,
		stroke = 4,
		shadowOffset = 7,
		paddingTop = 18,
		paddingBottom = 20,
		paddingSide = 8,
		medallion = 76,
		medallionStroke = 4,
		rarityText = 15,
		rarityStroke = 4,
		nameText = 18,
		nameStroke = 5,
		statText = 13,
		descText = 11.5,
		descStroke = 3,
		pip = Vector2.new(14, 9),
		pipStroke = 2.5,
		pipGap = 4,
	},

	--[[ The whole card's scale per input layout. ]]
	scale = {
		desktop = 1,
		phone = 0.746,
		controller = 1,
	},

	timing = {
		dealStagger = 0.095,
		dealDuration = 0.56,
		rerollDuration = 0.4,
		holdToOpen = 0.48,
		tooltipTime = 1.3,
		pickApplyAt = 1.56,
		slotPop = 0.65,
		mythicShake = 1.0,
		mythicFlip = 0.6,
		mythicTitleAt = 1.65,
		lightningStart = 1.3,
		lightningRun = 2.95,
		lightningFade = 0.75,
		lightningSpeed = 420,
		lightningBolts = 3,
		lightningLength = 130,
	},
}

return table.freeze(CardTheme)
